-- name: GetSubscription :one
SELECT * FROM subscriptions WHERE farm_id = @farm_id;

-- name: IsSubscriptionActive :one
SELECT EXISTS (
    SELECT 1 FROM subscriptions
    WHERE farm_id = @farm_id
      AND current_period_end IS NOT NULL
      AND current_period_end > now()
) AS active;

-- name: ExtendSubscription :one
-- Extends the period from max(now(), current_period_end) so early renewals stack (§7.4.5).
INSERT INTO subscriptions (farm_id, plan, status, current_period_end, updated_at)
VALUES (@farm_id, @plan, 'active', now() + make_interval(months => @add_months::int), now())
ON CONFLICT (farm_id) DO UPDATE
SET current_period_end = GREATEST(COALESCE(subscriptions.current_period_end, now()), now())
                         + make_interval(months => @add_months::int),
    plan = EXCLUDED.plan,
    status = 'active',
    updated_at = now()
RETURNING *;

-- name: RevokeSubscription :one
INSERT INTO subscriptions (farm_id, plan, status, current_period_end, updated_at)
VALUES (@farm_id, 'monthly', 'expired', now(), now())
ON CONFLICT (farm_id) DO UPDATE
SET status = 'expired', current_period_end = now(), updated_at = now()
RETURNING *;

-- name: MarkPendingSubscription :exec
-- Surfaces "under review" in the UI without granting access (§7.4 step 3).
INSERT INTO subscriptions (farm_id, plan, status, updated_at)
VALUES (@farm_id, @plan, 'pending', now())
ON CONFLICT (farm_id) DO UPDATE
SET status = CASE
        WHEN subscriptions.current_period_end IS NOT NULL
             AND subscriptions.current_period_end > now() THEN subscriptions.status
        ELSE 'pending'
    END,
    plan = EXCLUDED.plan,
    updated_at = now();

-- name: ExpireSubscriptions :execrows
UPDATE subscriptions
SET status = 'expired', updated_at = now()
WHERE status = 'active'
  AND current_period_end IS NOT NULL
  AND current_period_end <= now();
