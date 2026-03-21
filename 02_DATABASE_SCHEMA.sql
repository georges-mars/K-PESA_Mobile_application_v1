-- ============================================================================
-- K-PESA  —  AUTHORITATIVE DATABASE SCHEMA
-- ============================================================================
-- Single source of truth for the K-PESA database structure.
-- The migrations/ folder applies the same DDL incrementally.
-- Use this file to recreate the whole DB on a fresh server.
--
-- Usage:
--   psql -U kpesa_user -d kpesa -f 02_DATABASE_SCHEMA.sql
--
-- ── ENCRYPTION MODEL ─────────────────────────────────────────────────────────
--
--   2-layer key hierarchy (AES-256-GCM throughout):
--
--   MASTER_KEY  (process.env.MASTER_KEY — 64-char hex, NEVER stored in DB)
--       │
--       └─► Domain DEKs  (encryption_keys table, encrypted with MASTER_KEY)
--               │
--               └─► Column ciphertext  ("<iv_hex>:<tag_hex>:<data_hex>")
--
--   Domains:
--     user_pii     → users.full_name
--     payment      → payment_methods.phone_number / account_name / account_number
--     external     → users.deriv_access_token / deriv_refresh_token
--     payment_hmac → HMAC key for searchable phone / account sidecars
--
--   Columns marked ⚑ ENCRYPTED store AES-256-GCM ciphertext.
--   Columns marked ⚑ HMAC are deterministic HMAC-SHA256 for search.
--   Each encrypted row has a key_version column for rotation support.
--
-- ── TRANSIT ENCRYPTION ───────────────────────────────────────────────────────
--   All HTTP traffic is served over TLS terminated by nginx.
--   See nginx.conf for certificate configuration.
--
-- ── SETUP ORDER ──────────────────────────────────────────────────────────────
--   1. psql ... -f 02_DATABASE_SCHEMA.sql   (this file)
--   2. node key-setup.js                    (generate MASTER_KEY + 4 DEKs)
--   3. Add MASTER_KEY to backend/.env
--   4. npm run dev
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. ENCRYPTION KEY MANAGEMENT
-- ============================================================================

-- One row per (domain, version). Only one row per domain has is_active = TRUE.
CREATE TABLE IF NOT EXISTS encryption_keys (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  domain        VARCHAR(50)  NOT NULL,
    -- 'user_pii' | 'payment' | 'external' | 'payment_hmac'
  version       INTEGER      NOT NULL,        -- starts at 1, increments on rotation

  -- The 32-byte DEK wrapped with the master KEK (AES-256-GCM)
  encrypted_dek TEXT         NOT NULL,        -- hex-encoded ciphertext of the raw DEK
  dek_iv        VARCHAR(64)  NOT NULL,        -- hex-encoded 16-byte IV
  dek_tag       VARCHAR(64)  NOT NULL,        -- hex-encoded 16-byte GCM auth tag

  is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  expires_at    TIMESTAMPTZ  NOT NULL,        -- 7 days → triggers key-rotation.js
  rotated_at    TIMESTAMPTZ,                  -- set when superseded by a newer version

  UNIQUE(domain, version)
);

-- Fast lookup for the active DEK of a domain
CREATE INDEX IF NOT EXISTS idx_enc_keys_active
  ON encryption_keys(domain, is_active, expires_at);


-- Audit trail — one row per rotation attempt per domain
CREATE TABLE IF NOT EXISTS key_rotation_log (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  domain           VARCHAR(50) NOT NULL,
  old_version      INTEGER,
  new_version      INTEGER     NOT NULL,
  records_updated  INTEGER     NOT NULL DEFAULT 0,
  triggered_by     VARCHAR(50) NOT NULL DEFAULT 'auto',
    -- 'auto' | 'manual' | 'emergency' | 'setup'
  status           VARCHAR(20) NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'in_progress', 'completed', 'failed')),
  started_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at     TIMESTAMPTZ,
  error_message    TEXT
);


-- ============================================================================
-- 2. USERS
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
  id                     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Authentication
  email                  VARCHAR(255) NOT NULL UNIQUE,  -- plaintext; login key
  password_hash          TEXT         NOT NULL,

  -- PII  (encrypted with user_pii DEK)
  full_name              TEXT,                          -- ⚑ ENCRYPTED
  pii_key_version        INTEGER,                       -- DEK version that encrypted full_name

  -- Deriv OAuth  (non-secret identifiers stored plaintext)
  deriv_email            VARCHAR(255),
  deriv_name             VARCHAR(255),
  deriv_account          VARCHAR(50),                   -- e.g. CR10125517
  deriv_token_expires_at TIMESTAMPTZ,

  -- Deriv tokens  (encrypted with external DEK)
  deriv_access_token     TEXT,                          -- ⚑ ENCRYPTED
  deriv_refresh_token    TEXT,                          -- ⚑ ENCRYPTED
  ext_key_version        INTEGER,                       -- DEK version that encrypted deriv tokens

  -- Binance
  binance_id             VARCHAR(20),

  -- Account state
  is_verified            BOOLEAN      NOT NULL DEFAULT FALSE,
  is_active              BOOLEAN      NOT NULL DEFAULT TRUE,

  -- Referral
  referral_code          VARCHAR(20)  NOT NULL UNIQUE,
  referred_by            UUID         REFERENCES users(id),

  created_at             TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email         ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_referral_code ON users(referral_code);
CREATE INDEX IF NOT EXISTS idx_users_deriv_account ON users(deriv_account)
  WHERE deriv_account IS NOT NULL;


-- ============================================================================
-- 3. PAYMENT METHODS
-- ============================================================================

CREATE TABLE IF NOT EXISTS payment_methods (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type                VARCHAR(20)  NOT NULL CHECK (type IN ('mpesa', 'airtel', 'bank')),

  -- Mobile money  (encrypted with payment DEK)
  phone_number        TEXT,          -- ⚑ ENCRYPTED  (E.164: +254712345678)
  phone_number_hmac   VARCHAR(64),   -- ⚑ HMAC — for existence / match checks

  -- Bank  (bank_name is non-sensitive; account fields are encrypted)
  bank_name           VARCHAR(100),
  account_name        TEXT,          -- ⚑ ENCRYPTED
  account_number      TEXT,          -- ⚑ ENCRYPTED
  account_number_hmac VARCHAR(64),   -- ⚑ HMAC

  -- Encryption version tracking
  key_version         INTEGER,       -- payment DEK version that encrypted the fields above

  is_default          BOOLEAN      NOT NULL DEFAULT FALSE,
  is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pm_user_id
  ON payment_methods(user_id);

-- One default per (user, type)
CREATE UNIQUE INDEX IF NOT EXISTS idx_pm_one_default_per_type
  ON payment_methods(user_id, type)
  WHERE is_default = TRUE AND is_active = TRUE;

-- HMAC sidecar indexes for fast phone / account lookups
CREATE INDEX IF NOT EXISTS idx_pm_phone_hmac
  ON payment_methods(phone_number_hmac)
  WHERE phone_number_hmac IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pm_acct_hmac
  ON payment_methods(account_number_hmac)
  WHERE account_number_hmac IS NOT NULL;


-- ============================================================================
-- 4. OTPs
-- ============================================================================

CREATE TABLE IF NOT EXISTS otps (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  destination   VARCHAR(255) NOT NULL,  -- E.164 phone or email address
  otp_hash      VARCHAR(255) NOT NULL,  -- bcrypt(otp, rounds=8)
  purpose       VARCHAR(50)  NOT NULL
    CHECK (purpose IN ('signup', 'login', 'password_reset', 'withdrawal')),
  attempt_count INTEGER      NOT NULL DEFAULT 0,
  expires_at    TIMESTAMPTZ  NOT NULL,
  used_at       TIMESTAMPTZ,            -- set when successfully verified
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_otps_destination ON otps(destination, purpose);
CREATE INDEX IF NOT EXISTS idx_otps_expires     ON otps(expires_at);


-- ============================================================================
-- 5. REFRESH TOKENS
-- ============================================================================

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  VARCHAR(64)  NOT NULL UNIQUE,  -- SHA-256 hex of the raw bearer token
  ip_address  INET,
  expires_at  TIMESTAMPTZ  NOT NULL,
  revoked_at  TIMESTAMPTZ,                   -- NULL = still active
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rt_user_id    ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_rt_token_hash ON refresh_tokens(token_hash);


-- ============================================================================
-- 6. TRANSACTIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS transactions (
  id                         UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                    UUID           NOT NULL REFERENCES users(id),
  type                       VARCHAR(20)    NOT NULL
    CHECK (type IN ('deposit', 'withdrawal')),
  status                     VARCHAR(30)    NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),

  -- Amounts
  amount_kes                 NUMERIC(12, 2) NOT NULL,
  amount_usd                 NUMERIC(12, 4),
  exchange_rate              NUMERIC(12, 5),

  -- M-Pesa STK Push (deposits)
  mpesa_checkout_request_id  VARCHAR(100),
  mpesa_transaction_id       VARCHAR(50),       -- MpesaReceiptNumber from Safaricom callback
  mpesa_phone                VARCHAR(20),        -- E.164 -- stored plaintext for Safaricom interop

  -- M-Pesa B2C (withdrawals)
  b2c_conversation_id        VARCHAR(100),
  b2c_originator_id          VARCHAR(100),
  b2c_transaction_id         VARCHAR(50),

  -- Destination (deposits)
  destination_type           VARCHAR(20)
    CHECK (destination_type IN ('deriv', 'mt5', 'binance')),
  destination_account        VARCHAR(50),

  -- Failure / debug
  failure_reason             TEXT,
  callback_payload           JSONB,             -- raw Safaricom callback (audit / debug)

  created_at                 TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ        NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_txn_user_id    ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_txn_status     ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_txn_created_at ON transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_txn_stk_id     ON transactions(mpesa_checkout_request_id)
  WHERE mpesa_checkout_request_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_txn_b2c_id     ON transactions(b2c_conversation_id)
  WHERE b2c_conversation_id IS NOT NULL;


-- ============================================================================
-- 7. AFFILIATE REDEMPTIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS affiliate_redemptions (
  id              UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id     UUID           NOT NULL REFERENCES users(id),
  referee_id      UUID           NOT NULL REFERENCES users(id),
  referral_code   VARCHAR(20)    NOT NULL,
  commission_kes  NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
  paid_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  UNIQUE(referee_id)   -- each user redeems at most one referral code
);

CREATE INDEX IF NOT EXISTS idx_aff_referrer ON affiliate_redemptions(referrer_id);


-- ============================================================================
-- 8. SECURITY & AUDIT
-- ============================================================================

CREATE TABLE IF NOT EXISTS blocked_ips (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  ip_address      INET         NOT NULL UNIQUE,
  reason          TEXT,
  permanent       BOOLEAN      NOT NULL DEFAULT TRUE,
  expires_at      TIMESTAMPTZ,
  related_user_id UUID         REFERENCES users(id),
  blocked_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  blocked_by      VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS user_ip_history (
  id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID         NOT NULL REFERENCES users(id),
  ip_address     INET         NOT NULL,
  login_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  was_successful BOOLEAN      NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ip_history_user ON user_ip_history(user_id);

-- Immutable audit log for all admin / system actions
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id        UUID,                     -- NULL = automated system action
  actor_email     VARCHAR(255),
  action          VARCHAR(100) NOT NULL,    -- 'user.suspend' | 'key.rotate' | etc.
  affected_table  VARCHAR(100),
  affected_id     UUID,
  before_snapshot JSONB,
  after_snapshot  JSONB,
  ip_address      INET,
  performed_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_actor     ON admin_audit_log(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_performed ON admin_audit_log(performed_at DESC);


-- ============================================================================
-- 9. ADMIN SETTINGS
-- ============================================================================

CREATE TABLE IF NOT EXISTS admin_settings (
  key        VARCHAR(100) PRIMARY KEY,
  value      TEXT,
  updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

INSERT INTO admin_settings (key, value) VALUES
  ('profit_sweep_bank_account',  'YOUR_BANK_ACCOUNT_NUMBER'),
  ('profit_sweep_bank_code',     'YOUR_BANK_CODE'),
  ('profit_sweep_bank_name',     'YOUR_BANK_NAME'),
  ('profit_sweep_threshold_kes', '1000'),
  ('profit_sweep_schedule',      'daily'),
  ('profit_sweep_enabled',       'true')
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
