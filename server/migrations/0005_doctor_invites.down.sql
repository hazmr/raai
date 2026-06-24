-- Best-effort reverse of 0005 (structural; original visits are not restored).

ALTER TABLE animal_notes ADD COLUMN IF NOT EXISTS author_id INTEGER REFERENCES users(id);
ALTER TABLE animal_notes ADD COLUMN IF NOT EXISTS author_role TEXT NOT NULL DEFAULT 'farmer';
ALTER TABLE animal_notes ADD COLUMN IF NOT EXISTS visit_id INTEGER;
UPDATE animal_notes SET author_id = author_user_id WHERE author_id IS NULL;

DROP INDEX IF EXISTS idx_notes_invite;
ALTER TABLE animal_notes DROP COLUMN IF EXISTS author_kind;
ALTER TABLE animal_notes DROP COLUMN IF EXISTS author_user_id;
ALTER TABLE animal_notes DROP COLUMN IF EXISTS author_invite_id;
ALTER TABLE animal_notes DROP COLUMN IF EXISTS author_label;

DROP TABLE IF EXISTS doctor_invites;
