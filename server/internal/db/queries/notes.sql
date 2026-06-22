-- name: CreateNote :one
INSERT INTO animal_notes (animal_id, notes, author_id, author_role, visit_id)
VALUES (@animal_id, @notes, @author_id, @author_role, sqlc.narg('visit_id'))
RETURNING *;

-- name: GetNote :one
SELECT n.* FROM animal_notes n
JOIN animals a ON a.id = n.animal_id
WHERE n.id = @id AND n.animal_id = @animal_id AND a.user_id = @owner_id;

-- name: ListNotes :many
SELECT n.* FROM animal_notes n
JOIN animals a ON a.id = n.animal_id
WHERE n.animal_id = @animal_id AND a.user_id = @owner_id
  AND (sqlc.narg('cursor_time')::timestamptz IS NULL
       OR (n.created_at, n.id) < (sqlc.narg('cursor_time')::timestamptz, sqlc.arg('cursor_id')::int))
ORDER BY n.created_at DESC, n.id DESC
LIMIT sqlc.arg('lim')::int;

-- name: UpdateNote :one
UPDATE animal_notes
SET notes = @notes, updated_at = now()
WHERE id = @id AND animal_id = @animal_id AND author_id = @author_id
RETURNING *;

-- name: DeleteNote :execrows
DELETE FROM animal_notes
WHERE id = @id AND animal_id = @animal_id AND author_id = @author_id;
