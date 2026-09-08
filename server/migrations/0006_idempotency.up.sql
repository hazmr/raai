-- 0006_idempotency: make retried creates safe (§6.1 Idempotency-Key).
--
-- The app writes notes and ear tags into a local outbox while offline and replays
-- them when the signal returns, so the same POST can legitimately arrive twice.
-- The first request claims the key; the replay gets the stored response back
-- instead of creating a second row.

CREATE TABLE idempotency_keys (
    farm_id       INTEGER NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
    key           TEXT NOT NULL,
    request_hash  TEXT NOT NULL,                 -- method+path+body fingerprint
    status_code   INTEGER,                       -- NULL while the first request is in flight
    response_body BYTEA,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at  TIMESTAMPTZ,
    PRIMARY KEY (farm_id, key)
);

-- Supports the periodic purge of keys that are past their replay window.
CREATE INDEX idx_idempotency_created ON idempotency_keys (created_at);
