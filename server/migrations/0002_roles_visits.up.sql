-- 0002_roles_visits: visits + note authorship linkage (§4.3, §6.8)

CREATE TABLE visits (
    id             SERIAL PRIMARY KEY,
    farmer_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vet_id         INTEGER REFERENCES users(id) ON DELETE SET NULL,
    location_type  TEXT NOT NULL CHECK (location_type IN ('clinic', 'farm')),
    location_label TEXT,
    status         TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
    opened_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at      TIMESTAMPTZ
);

CREATE INDEX idx_visits_farmer ON visits (farmer_id, opened_at DESC, id DESC);
CREATE INDEX idx_visits_vet ON visits (vet_id, status, opened_at DESC, id DESC);

-- Only one open visit per (farmer, vet) pair at a time keeps the grant unambiguous.
CREATE UNIQUE INDEX uq_visits_open_pair ON visits (farmer_id, vet_id)
    WHERE status = 'open';

-- Notes can now belong to a visit (null = farmer's own note, §4.1).
ALTER TABLE animal_notes
    ADD COLUMN visit_id INTEGER REFERENCES visits(id) ON DELETE SET NULL;

CREATE INDEX idx_notes_visit ON animal_notes (visit_id);
