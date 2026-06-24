-- name: CreatePayment :one
INSERT INTO payments (farm_id, created_by, plan, amount_egp, instapay_ref, screenshot_url)
VALUES (@farm_id, @created_by, @plan, @amount_egp, @instapay_ref, sqlc.narg('screenshot_url'))
RETURNING *;

-- name: GetPaymentByRef :one
SELECT * FROM payments WHERE instapay_ref = @instapay_ref;

-- name: GetPayment :one
SELECT * FROM payments WHERE id = @id;

-- name: ListPaymentsByFarm :many
SELECT * FROM payments
WHERE farm_id = @farm_id
  AND (sqlc.narg('cursor_time')::timestamptz IS NULL
       OR (created_at, id) < (sqlc.narg('cursor_time')::timestamptz, sqlc.arg('cursor_id')::int))
ORDER BY created_at DESC, id DESC
LIMIT sqlc.arg('lim')::int;

-- name: ListPayments :many
SELECT * FROM payments
WHERE (sqlc.narg('status')::text IS NULL OR status = sqlc.narg('status')::text)
  AND (sqlc.narg('cursor_time')::timestamptz IS NULL
       OR (created_at, id) < (sqlc.narg('cursor_time')::timestamptz, sqlc.arg('cursor_id')::int))
ORDER BY created_at DESC, id DESC
LIMIT sqlc.arg('lim')::int;

-- name: ReviewPayment :one
-- Marks a pending payment confirmed/rejected. Returns no row if not pending (idempotent guard).
UPDATE payments
SET status = @status, reviewed_by = @reviewed_by, reviewed_at = now(), note = sqlc.narg('note')
WHERE id = @id AND status = 'pending'
RETURNING *;
