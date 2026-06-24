-- 0005_doctor_invites: replace `visits` with token-based, revocable doctor invites,
-- and record note authorship as either a member (user) or a doctor (invite).

CREATE TABLE doctor_invites (
    id           SERIAL PRIMARY KEY,
    farm_id      INTEGER NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
    token        TEXT NOT NULL UNIQUE,                       -- secret encoded in the QR
    doctor_label TEXT NOT NULL,                              -- name shown in history / on notes
    status       TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'ended')),
    expires_at   TIMESTAMPTZ,                                -- NULL = no expiry, ended manually
    created_by   INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at     TIMESTAMPTZ,
    ended_by     INTEGER REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX idx_invites_farm ON doctor_invites (farm_id, created_at DESC, id DESC);

-- Note authorship: member (author_user_id) or doctor (author_invite_id); author_label
-- is the display name stamped at write time so history survives even if the row is gone.
ALTER TABLE animal_notes ADD COLUMN author_kind TEXT NOT NULL DEFAULT 'member'
    CHECK (author_kind IN ('member', 'doctor'));
ALTER TABLE animal_notes ADD COLUMN author_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE animal_notes ADD COLUMN author_invite_id INTEGER REFERENCES doctor_invites(id) ON DELETE SET NULL;
ALTER TABLE animal_notes ADD COLUMN author_label TEXT NOT NULL DEFAULT '';

-- Backfill existing notes as member-authored.
UPDATE animal_notes n
SET author_user_id = n.author_id,
    author_kind    = 'member',
    author_label   = COALESCE((SELECT phone_number FROM users u WHERE u.id = n.author_id), '');

-- Drop old authorship + visit linkage, then drop visits entirely.
DROP INDEX IF EXISTS idx_notes_visit;
ALTER TABLE animal_notes DROP COLUMN IF EXISTS visit_id;
ALTER TABLE animal_notes DROP COLUMN author_id;
ALTER TABLE animal_notes DROP COLUMN author_role;
CREATE INDEX idx_notes_invite ON animal_notes (author_invite_id);

DROP TABLE IF EXISTS visits;
