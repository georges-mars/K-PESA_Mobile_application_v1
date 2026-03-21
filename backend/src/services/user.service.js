'use strict';

const db     = require('../config/database');
const logger = require('../config/logger');

async function getProfile(userId) {
  const { rows } = await db.query(
    `SELECT id, email, full_name, display_name, deriv_email, deriv_name, deriv_account,
            binance_id, referral_code, is_verified, created_at
     FROM users WHERE id = $1`,
    [userId],
  );
  if (!rows[0]) {
    const err = new Error('User not found.');
    err.type = 'NOT_FOUND';
    throw err;
  }
  return rows[0];
}

async function updateProfile(userId, { fullName, displayName }) {
  const { rows } = await db.query(
    `UPDATE users
     SET full_name    = COALESCE($1, full_name),
         display_name = COALESCE($2, display_name),
         updated_at   = NOW()
     WHERE id = $3
     RETURNING id, email, full_name, display_name`,
    [fullName || null, displayName || null, userId],
  );
  return rows[0];
}

async function listPaymentMethods(userId) {
  const { rows } = await db.query(
    `SELECT id, type, phone_number, bank_name, account_name, account_number, is_default, created_at
     FROM payment_methods WHERE user_id = $1 AND is_active = TRUE
     ORDER BY is_default DESC, created_at ASC`,
    [userId],
  );
  return rows;
}

async function addPaymentMethod(userId, { type, phoneNumber, bankName, accountName, accountNumber, isDefault }) {
  const client = await db.getClient();
  try {
    await client.query('BEGIN');

    if (isDefault) {
      // Un-default existing methods of same type
      await client.query(
        `UPDATE payment_methods SET is_default = FALSE
         WHERE user_id = $1 AND type = $2`,
        [userId, type],
      );
    }

    const { rows } = await client.query(
      `INSERT INTO payment_methods
         (user_id, type, phone_number, bank_name, account_name, account_number, is_default)
       VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING *`,
      [userId, type, phoneNumber || null, bankName || null, accountName || null, accountNumber || null, isDefault || false],
    );

    await client.query('COMMIT');
    return rows[0];
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function deletePaymentMethod(userId, methodId) {
  const { rowCount } = await db.query(
    `UPDATE payment_methods SET is_active = FALSE
     WHERE id = $1 AND user_id = $2`,
    [methodId, userId],
  );
  if (rowCount === 0) {
    const err = new Error('Payment method not found.');
    err.type = 'NOT_FOUND';
    throw err;
  }
}

async function setDefaultPaymentMethod(userId, methodId) {
  const { rows } = await db.query(
    'SELECT type FROM payment_methods WHERE id = $1 AND user_id = $2 AND is_active = TRUE',
    [methodId, userId],
  );
  if (!rows[0]) {
    const err = new Error('Payment method not found.');
    err.type = 'NOT_FOUND';
    throw err;
  }
  const client = await db.getClient();
  try {
    await client.query('BEGIN');
    await client.query(
      `UPDATE payment_methods SET is_default = FALSE WHERE user_id = $1 AND type = $2`,
      [userId, rows[0].type],
    );
    await client.query(`UPDATE payment_methods SET is_default = TRUE WHERE id = $1`, [methodId]);
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function listTransactions(userId, { page = 1, limit = 20, type, status } = {}) {
  const offset = (page - 1) * limit;
  const conditions = ['user_id = $1'];
  const params = [userId];

  if (type)   { conditions.push(`type = $${params.push(type)}`); }
  if (status) { conditions.push(`status = $${params.push(status)}`); }

  const where = conditions.join(' AND ');

  const [data, count] = await Promise.all([
    db.query(
      `SELECT id, type, status, amount_kes, amount_usd, exchange_rate,
              mpesa_transaction_id, b2c_transaction_id,
              destination_type, failure_reason, created_at
       FROM transactions WHERE ${where}
       ORDER BY created_at DESC
       LIMIT $${params.push(limit)} OFFSET $${params.push(offset)}`,
      params,
    ),
    db.query(`SELECT COUNT(*) FROM transactions WHERE ${where}`, params.slice(0, params.length - 2)),
  ]);

  return {
    transactions: data.rows,
    total: parseInt(count.rows[0].count),
    page,
    limit,
  };
}

module.exports = {
  getProfile,
  updateProfile,
  listPaymentMethods,
  addPaymentMethod,
  deletePaymentMethod,
  setDefaultPaymentMethod,
  listTransactions,
};
