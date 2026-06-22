-- name: CreateAudit :exec
INSERT INTO admin_audit (admin_id, action, target_user, payment_id, detail)
VALUES (@admin_id, @action, sqlc.narg('target_user'), sqlc.narg('payment_id'), sqlc.narg('detail'));
