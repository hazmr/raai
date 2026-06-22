-- 0001_init: users, animals, animal_notes (§4.1)

CREATE TABLE users (
    id                        SERIAL PRIMARY KEY,
    phone_number              TEXT NOT NULL UNIQUE,
    password                  TEXT NOT NULL,            -- bcrypt hash (§10.1)
    refresh_token             TEXT,
    refresh_token_expiry_time TIMESTAMPTZ,
    is_admin                  BOOLEAN NOT NULL DEFAULT FALSE,
    role                      TEXT NOT NULL DEFAULT 'farmer'
                                  CHECK (role IN ('farmer', 'vet')),
    created_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE animals (
    id         SERIAL PRIMARY KEY,
    barcode    TEXT NOT NULL,
    user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (barcode, user_id)
);

CREATE INDEX idx_animals_user ON animals (user_id, created_at DESC, id DESC);

CREATE TABLE animal_notes (
    id          SERIAL PRIMARY KEY,
    animal_id   INTEGER NOT NULL REFERENCES animals(id) ON DELETE CASCADE,
    notes       TEXT NOT NULL,                          -- exposed as `body` in the API (§6.5)
    author_id   INTEGER NOT NULL REFERENCES users(id),
    author_role TEXT NOT NULL DEFAULT 'farmer'
                    CHECK (author_role IN ('farmer', 'vet')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notes_animal ON animal_notes (animal_id, created_at DESC, id DESC);
