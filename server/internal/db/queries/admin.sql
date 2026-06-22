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
SELECT p.*, u.phone_number
FROM payments p
JOIN users u ON u.id = p.user_id
WHERE (sqlc.narg('status')::text IS NULL OR p.status = sqlc.narg('status')::text)
ORDER BY p.created_at DESC, p.id DESC
LIMIT sqlc.arg('lim')::int;

-- name: GetSubscriberDetail :one
SELECT u.id, u.phone_number, u.role, u.is_admin, u.created_at,
       s.plan, s.status, s.current_period_end
FROM users u
LEFT JOIN subscriptions s ON s.user_id = u.id
WHERE u.id = @id;

-- name: ListSubscribers :many
SELECT u.id, u.phone_number, u.role, u.created_at,
       s.plan, s.status, s.current_period_end
FROM users u
LEFT JOIN subscriptions s ON s.user_id = u.id
WHERE (sqlc.narg('phone')::text IS NULL OR u.phone_number ILIKE '%' || sqlc.narg('phone')::text || '%')
ORDER BY u.created_at DESC, u.id DESC
LIMIT sqlc.arg('lim')::int OFFSET sqlc.arg('off')::int;
