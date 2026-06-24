-- name: CreateAnimal :one
INSERT INTO animals (barcode, farm_id)
VALUES (@barcode, @farm_id)
RETURNING id, barcode, created_at, updated_at;

-- name: GetAnimal :one
SELECT a.id, a.barcode, a.created_at, a.updated_at,
       (SELECT count(*) FROM animal_notes n WHERE n.animal_id = a.id)::bigint AS note_count
FROM animals a
WHERE a.id = @id AND a.farm_id = @farm_id;

-- name: GetAnimalByBarcode :one
SELECT a.id, a.barcode, a.created_at, a.updated_at,
       (SELECT count(*) FROM animal_notes n WHERE n.animal_id = a.id)::bigint AS note_count
FROM animals a
WHERE a.barcode = @barcode AND a.farm_id = @farm_id;

-- name: ListAnimals :many
SELECT a.id, a.barcode, a.created_at, a.updated_at,
       (SELECT count(*) FROM animal_notes n WHERE n.animal_id = a.id)::bigint AS note_count
FROM animals a
WHERE a.farm_id = @farm_id
  AND (sqlc.narg('cursor_time')::timestamptz IS NULL
       OR (a.created_at, a.id) < (sqlc.narg('cursor_time')::timestamptz, sqlc.arg('cursor_id')::int))
ORDER BY a.created_at DESC, a.id DESC
LIMIT sqlc.arg('lim')::int;

-- name: UpdateAnimal :one
UPDATE animals
SET barcode = @barcode, updated_at = now()
WHERE id = @id AND farm_id = @farm_id
RETURNING id, barcode, created_at, updated_at;

-- name: DeleteAnimal :execrows
DELETE FROM animals WHERE id = @id AND farm_id = @farm_id;
