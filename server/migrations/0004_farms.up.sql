-- 0004_farms: Farm tenants + memberships; move ownership from users to farms.
-- Backfill wraps every existing user in their own farm (as admin) so no data is lost.

CREATE TABLE farms (
    id         SERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE farm_members (
    id         SERIAL PRIMARY KEY,
    farm_id    INTEGER NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
    user_id    INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE, -- one farm per user
    role       TEXT NOT NULL DEFAULT 'farmer' CHECK (role IN ('admin', 'farmer')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_members_farm ON farm_members (farm_id);

-- Backfill: each existing user becomes the admin of a farm whose id == the user id
-- (farms is empty here, so reusing the id makes the ownership remap below trivial).
INSERT INTO farms (id, name, created_at)
SELECT u.id, 'مزرعة ' || u.phone_number, u.created_at FROM users u;
SELECT setval(pg_get_serial_sequence('farms', 'id'), GREATEST((SELECT COALESCE(max(id), 1) FROM farms), 1));

INSERT INTO farm_members (farm_id, user_id, role, created_at)
SELECT u.id, u.id, 'admin', u.created_at FROM users u;

-- animals: user_id -> farm_id
ALTER TABLE animals ADD COLUMN farm_id INTEGER REFERENCES farms(id) ON DELETE CASCADE;
UPDATE animals SET farm_id = user_id;               -- user_id == farm_id by the backfill above
ALTER TABLE animals ALTER COLUMN farm_id SET NOT NULL;
ALTER TABLE animals DROP CONSTRAINT animals_barcode_user_id_key;
DROP INDEX IF EXISTS idx_animals_user;
ALTER TABLE animals DROP COLUMN user_id;
ALTER TABLE animals ADD CONSTRAINT animals_barcode_farm_key UNIQUE (barcode, farm_id);
CREATE INDEX idx_animals_farm ON animals (farm_id, created_at DESC, id DESC);

-- subscriptions: user_id -> farm_id (one per farm)
ALTER TABLE subscriptions ADD COLUMN farm_id INTEGER REFERENCES farms(id) ON DELETE CASCADE;
UPDATE subscriptions SET farm_id = user_id;
ALTER TABLE subscriptions ALTER COLUMN farm_id SET NOT NULL;
ALTER TABLE subscriptions DROP CONSTRAINT subscriptions_user_id_key;
ALTER TABLE subscriptions DROP COLUMN user_id;
ALTER TABLE subscriptions ADD CONSTRAINT subscriptions_farm_key UNIQUE (farm_id);

-- payments: user_id -> farm_id, plus created_by (which member submitted it)
ALTER TABLE payments ADD COLUMN farm_id INTEGER REFERENCES farms(id) ON DELETE CASCADE;
ALTER TABLE payments ADD COLUMN created_by INTEGER REFERENCES users(id) ON DELETE SET NULL;
UPDATE payments SET farm_id = user_id, created_by = user_id;
ALTER TABLE payments ALTER COLUMN farm_id SET NOT NULL;
DROP INDEX IF EXISTS idx_payments_user;
ALTER TABLE payments DROP COLUMN user_id;
CREATE INDEX idx_payments_farm ON payments (farm_id, created_at DESC, id DESC);

-- role now lives on the membership, not the user.
ALTER TABLE users DROP COLUMN role;
