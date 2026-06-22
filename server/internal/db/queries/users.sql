-- name: CreateUser :one
INSERT INTO users (phone_number, password, role)
VALUES (@phone_number, @password, @role)
RETURNING *;

-- name: GetUserByID :one
SELECT * FROM users WHERE id = @id;

-- name: GetUserByPhone :one
SELECT * FROM users WHERE phone_number = @phone_number;

-- name: GetUserByRefreshToken :one
SELECT * FROM users
WHERE refresh_token = @refresh_token
  AND refresh_token_expiry_time IS NOT NULL
  AND refresh_token_expiry_time > now();

-- name: SetRefreshToken :exec
UPDATE users
SET refresh_token = @refresh_token,
    refresh_token_expiry_time = @refresh_token_expiry_time
WHERE id = @id;

-- name: ClearRefreshToken :exec
UPDATE users
SET refresh_token = NULL, refresh_token_expiry_time = NULL
WHERE id = @id;

-- name: SetAdminByPhone :one
UPDATE users SET is_admin = TRUE WHERE phone_number = @phone_number
RETURNING *;
