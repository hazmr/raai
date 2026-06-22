DROP INDEX IF EXISTS idx_notes_visit;
ALTER TABLE animal_notes DROP COLUMN IF EXISTS visit_id;
DROP TABLE IF EXISTS visits;
