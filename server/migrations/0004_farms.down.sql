-- Best-effort reverse of 0004 (structural; backfilled data is not restored).

ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'farmer';

ALTER TABLE payments ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id) ON DELETE CASCADE;
UPDATE payments SET user_id = created_by WHERE user_id IS NULL;
DROP INDEX IF EXISTS idx_payments_farm;
ALTER TABLE payments DROP COLUMN IF EXISTS farm_id;
ALTER TABLE payments DROP COLUMN IF EXISTS created_by;
CREATE INDEX IF NOT EXISTS idx_payments_user ON payments (user_id, created_at DESC, id DESC);

ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE subscriptions DROP CONSTRAINT IF EXISTS subscriptions_farm_key;
ALTER TABLE subscriptions DROP COLUMN IF EXISTS farm_id;

ALTER TABLE animals ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE animals DROP CONSTRAINT IF EXISTS animals_barcode_farm_key;
DROP INDEX IF EXISTS idx_animals_farm;
ALTER TABLE animals DROP COLUMN IF EXISTS farm_id;
CREATE INDEX IF NOT EXISTS idx_animals_user ON animals (user_id, created_at DESC, id DESC);

DROP TABLE IF EXISTS farm_members;
DROP TABLE IF EXISTS farms;
