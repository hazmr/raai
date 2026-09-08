-- name: ClaimIdempotencyKey :one
-- Claims a key for the caller's farm. Returns no row when the key is already
-- taken — the caller then reads the stored response (or reports "in progress").
INSERT INTO idempotency_keys (farm_id, key, request_hash)
VALUES (@farm_id, @key, @request_hash)
ON CONFLICT (farm_id, key) DO NOTHING
RETURNING *;

-- name: GetIdempotencyKey :one
SELECT * FROM idempotency_keys WHERE farm_id = @farm_id AND key = @key;

-- name: CompleteIdempotencyKey :exec
UPDATE idempotency_keys
SET status_code = @status_code, response_body = @response_body, completed_at = now()
WHERE farm_id = @farm_id AND key = @key;

-- name: ReleaseIdempotencyKey :exec
-- Frees a claim whose request failed, so the client's retry can run for real.
DELETE FROM idempotency_keys WHERE farm_id = @farm_id AND key = @key;

-- name: PurgeIdempotencyKeys :execrows
-- Drops keys past the replay window (§6.1); the client has long since given up.
DELETE FROM idempotency_keys WHERE created_at < now() - make_interval(hours => @older_than_hours::int);
