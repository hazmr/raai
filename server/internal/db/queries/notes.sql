-- name: CreateNote :one
INSERT INTO animal_notes (animal_id, notes, author_kind, author_user_id, author_invite_id, author_label)
VALUES (@animal_id, @notes, @author_kind, sqlc.narg('author_user_id'),
        sqlc.narg('author_invite_id'), @author_label)
RETURNING *;

-- name: GetNote :one
SELECT n.* FROM animal_notes n
JOIN animals a ON a.id = n.animal_id
WHERE n.id = @id AND n.animal_id = @animal_id AND a.farm_id = @farm_id;

-- name: ListNotes :many
SELECT n.* FROM animal_notes n
JOIN animals a ON a.id = n.animal_id
WHERE n.animal_id = @animal_id AND a.farm_id = @farm_id
  AND (sqlc.narg('cursor_time')::timestamptz IS NULL
       OR (n.created_at, n.id) < (sqlc.narg('cursor_time')::timestamptz, sqlc.arg('cursor_id')::int))
ORDER BY n.created_at DESC, n.id DESC
LIMIT sqlc.arg('lim')::int;

-- name: UpdateNoteByUser :one
UPDATE animal_notes
SET notes = @notes, updated_at = now()
WHERE id = @id AND animal_id = @animal_id AND author_user_id = @author_user_id
RETURNING *;

-- name: DeleteNoteByUser :execrows
DELETE FROM animal_notes
WHERE id = @id AND animal_id = @animal_id AND author_user_id = @author_user_id;

-- name: UpdateNoteByInvite :one
UPDATE animal_notes
SET notes = @notes, updated_at = now()
WHERE id = @id AND animal_id = @animal_id AND author_invite_id = @author_invite_id
RETURNING *;

-- name: DeleteNoteByInvite :execrows
DELETE FROM animal_notes
WHERE id = @id AND animal_id = @animal_id AND author_invite_id = @author_invite_id;

-- name: CountNotesByInvite :one
SELECT count(*)::bigint AS notes FROM animal_notes WHERE author_invite_id = @author_invite_id;
