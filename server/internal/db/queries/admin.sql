-- name: AdminStats :one
SELECT
    (SELECT count(*) FROM payments WHERE status = 'pending')::bigint AS pending_payments,
    (SELECT count(*) FROM subscriptions
        WHERE current_period_end IS NOT NULL AND current_period_end > now())::bigint AS active_subscribers,
    (SELECT count(*) FROM subscriptions
        WHERE current_period_end IS NOT NULL
          AND current_period_end > now()
          AND current_period_end <= now() + interval '7 days')::bigint AS expiring_soon,
    (SELECT COALESCE(sum(amount_egp), 0) FROM payments
        WHERE status = 'confirmed'
          AND reviewed_at >= date_trunc('month', now()))::numeric AS revenue_this_month;

-- name: ListPaymentsDetailed :many
SELECT p.*, f.name AS farm_name, u.phone_number AS submitted_by
FROM payments p
JOIN farms f ON f.id = p.farm_id
LEFT JOIN users u ON u.id = p.created_by
WHERE (sqlc.narg('status')::text IS NULL OR p.status = sqlc.narg('status')::text)
ORDER BY p.created_at DESC, p.id DESC
LIMIT sqlc.arg('lim')::int;

-- name: ListFarms :many
SELECT f.id, f.name, f.created_at,
       (SELECT count(*) FROM farm_members m WHERE m.farm_id = f.id)::bigint AS member_count,
       s.plan, s.status, s.current_period_end
FROM farms f
LEFT JOIN subscriptions s ON s.farm_id = f.id
WHERE (sqlc.narg('q')::text IS NULL OR f.name ILIKE '%' || sqlc.narg('q')::text || '%')
ORDER BY f.created_at DESC, f.id DESC
LIMIT sqlc.arg('lim')::int OFFSET sqlc.arg('off')::int;

-- name: GetFarmDetail :one
SELECT f.id, f.name, f.created_at,
       s.plan, s.status, s.current_period_end
FROM farms f
LEFT JOIN subscriptions s ON s.farm_id = f.id
WHERE f.id = @id;
