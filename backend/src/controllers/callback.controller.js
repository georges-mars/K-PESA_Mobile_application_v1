'use strict';

const db     = require('../config/database');
const logger = require('../config/logger');

// Always respond 200 immediately — Safaricom retries if we don't respond quickly
function ack(res) {
  res.json({ ResultCode: 0, ResultDesc: 'Success' });
}

// ── STK Push callback ──────────────────────────────────────────────────────────
async function handleSTKCallback(req, res) {
  ack(res);

  const callback = req.body?.Body?.stkCallback;
  if (!callback) return;

  const { CheckoutRequestID, ResultCode, ResultDesc, CallbackMetadata } = callback;

  try {
    const { rows } = await db.query(
      'SELECT id FROM transactions WHERE mpesa_checkout_request_id = $1',
      [CheckoutRequestID],
    );
    if (!rows[0]) {
      logger.warn('STK callback: unknown CheckoutRequestID', { CheckoutRequestID });
      return;
    }
    const transactionId = rows[0].id;

    if (ResultCode === 0) {
      const items = CallbackMetadata?.Item || [];
      const get = (name) => items.find((i) => i.Name === name)?.Value;
      const receipt = String(get('MpesaReceiptNumber') || '');
      const amount  = get('Amount');

      await db.query(
        `UPDATE transactions
         SET status='completed',
             mpesa_transaction_id=$1,
             callback_payload=$2,
             updated_at=NOW()
         WHERE id=$3`,
        [receipt, JSON.stringify(req.body), transactionId],
      );
      logger.info('Deposit completed via STK callback', { transactionId, receipt, amount });
    } else {
      const newStatus = ResultCode === 1032 ? 'cancelled' : 'failed';
      await db.query(
        `UPDATE transactions
         SET status=$1, failure_reason=$2, callback_payload=$3, updated_at=NOW()
         WHERE id=$4`,
        [newStatus, ResultDesc, JSON.stringify(req.body), transactionId],
      );
      logger.info('Deposit not completed', { transactionId, ResultCode, ResultDesc });
    }
  } catch (err) {
    logger.error('STK callback processing error', { error: err.message });
  }
}

// ── B2C result callback ────────────────────────────────────────────────────────
async function handleB2CResult(req, res) {
  ack(res);

  const result = req.body?.Result;
  if (!result) return;

  const { OriginatorConversationID, ResultCode, ResultDesc, ResultParameters } = result;

  try {
    const { rows } = await db.query(
      `SELECT id FROM transactions
       WHERE b2c_originator_id = $1 OR id::text = $1`,
      [OriginatorConversationID],
    );
    if (!rows[0]) {
      logger.warn('B2C callback: unknown OriginatorConversationID', { OriginatorConversationID });
      return;
    }
    const transactionId = rows[0].id;

    if (ResultCode === 0) {
      const params = ResultParameters?.ResultParameter || [];
      const get = (key) => params.find((p) => p.Key === key)?.Value;
      const receipt = String(get('TransactionReceipt') || '');

      await db.query(
        `UPDATE transactions
         SET status='completed',
             b2c_transaction_id=$1,
             callback_payload=$2,
             updated_at=NOW()
         WHERE id=$3`,
        [receipt, JSON.stringify(req.body), transactionId],
      );
      logger.info('Withdrawal completed via B2C callback', { transactionId, receipt });
    } else {
      await db.query(
        `UPDATE transactions
         SET status='failed', failure_reason=$1, callback_payload=$2, updated_at=NOW()
         WHERE id=$3`,
        [ResultDesc, JSON.stringify(req.body), transactionId],
      );
      logger.info('Withdrawal failed', { transactionId, ResultCode, ResultDesc });
    }
  } catch (err) {
    logger.error('B2C result callback processing error', { error: err.message });
  }
}

// ── B2C timeout callback ───────────────────────────────────────────────────────
async function handleB2CTimeout(req, res) {
  ack(res);
  const id = req.body?.Result?.OriginatorConversationID;
  logger.warn('B2C timeout received', { id, body: req.body });
  if (!id) return;

  try {
    await db.query(
      `UPDATE transactions
       SET status='failed', failure_reason='B2C request timed out', callback_payload=$1, updated_at=NOW()
       WHERE b2c_originator_id=$2 OR id::text=$2`,
      [JSON.stringify(req.body), id],
    );
  } catch (err) {
    logger.error('B2C timeout processing error', { error: err.message });
  }
}

module.exports = { handleSTKCallback, handleB2CResult, handleB2CTimeout };
