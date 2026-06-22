-- name: CreateVisit :one
INSERT INTO visits (farmer_id, vet_id, location_type, location_label)
VALUES (@farmer_id, sqlc.narg('vet_id'), @location_type, sqlc.narg('location_label'))
RETURNING *;

-- name: GetVisitForFarmer :one
SELECT * FROM visits WHERE id = @id AND farmer_id = @farmer_id;

-- name: GetOpenVisitForVet :one
SELECT * FROM visits
WHERE id = @id AND vet_id = @vet_id AND status = 'open';

-- name: CloseVisit :one
UPDATE visits
SET status = 'closed', closed_at = now()
WHERE id = @id AND farmer_id = @farmer_id AND status = 'open'
RETURNING *;

-- name: VetHasOpenVisitWithFarmer :one
SELECT EXISTS (
    SELECT 1 FROM visits
    WHERE vet_id = @vet_id AND farmer_id = @farmer_id AND status = 'open'
) AS has;

-- name: ListVisitsByFarmer :many
SELECT * FROM visits
WHERE farmer_id = @farmer_id
  AND (sqlc.narg('cursor_time')::timestamptz IS NULL
       OR (opened_at, id) < (sqlc.narg('cursor_time')::timestamptz, sqlc.arg('cursor_id')::int))
ORDER BY opened_at DESC, id DESC
LIMIT sqlc.arg('lim')::int;

-- name: ListVisitsByVet :many
SELECT * FROM visits
WHERE vet_id = @vet_id
  AND (sqlc.narg('status')::text IS NULL OR status = sqlc.narg('status')::text)
  AND (sqlc.narg('cursor_time')::timestamptz IS NULL
       OR (opened_at, id) < (sqlc.narg('cursor_time')::timestamptz, sqlc.arg('cursor_id')::int))
ORDER BY opened_at DESC, id DESC
LIMIT sqlc.arg('lim')::int;
