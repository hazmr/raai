-- 0003_subscriptions: subscriptions, payments, admin_audit (§4.2)

CREATE TABLE subscriptions (
    id                 SERIAL PRIMARY KEY,
    user_id            INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    plan               TEXT NOT NULL CHECK (plan IN ('monthly', 'yearly')),
    status             TEXT NOT NULL DEFAULT 'pending'
                           CHECK (status IN ('pending', 'active', 'expired')),
    current_period_end TIMESTAMPTZ,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE payments (
    id             SERIAL PRIMARY KEY,
    user_id        INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan           TEXT NOT NULL CHECK (plan IN ('monthly', 'yearly')),
    amount_egp     NUMERIC(10, 2) NOT NULL,
    instapay_ref   TEXT NOT NULL UNIQUE,                  -- dedupes claimed transfers
    screenshot_url TEXT,
    status         TEXT NOT NULL DEFAULT 'pending'
                       CHECK (status IN ('pending', 'confirmed', 'rejected')),
    reviewed_by    INTEGER REFERENCES users(id) ON DELETE SET NULL,
    reviewed_at    TIMESTAMPTZ,
    note           TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_payments_user ON payments (user_id, created_at DESC, id DESC);
CREATE INDEX idx_payments_status ON payments (status, created_at DESC, id DESC);

CREATE TABLE admin_audit (
    id          SERIAL PRIMARY KEY,
    admin_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action      TEXT NOT NULL
                    CHECK (action IN ('confirm_payment', 'reject_payment', 'grant', 'revoke')),
    target_user INTEGER REFERENCES users(id) ON DELETE SET NULL,
    payment_id  INTEGER REFERENCES payments(id) ON DELETE SET NULL,
    detail      TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_admin ON admin_audit (admin_id, created_at DESC);
