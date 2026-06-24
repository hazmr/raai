-- name: CreateFarm :one
INSERT INTO farms (name) VALUES (@name)
RETURNING *;

-- name: GetFarm :one
SELECT * FROM farms WHERE id = @id;

-- name: AddMember :one
INSERT INTO farm_members (farm_id, user_id, role)
VALUES (@farm_id, @user_id, @role)
RETURNING *;

-- name: GetMembershipByUser :one
-- The caller's farm context: which farm they belong to and their role there.
SELECT farm_id, role FROM farm_members WHERE user_id = @user_id;

-- name: GetMember :one
SELECT * FROM farm_members WHERE farm_id = @farm_id AND user_id = @user_id;

-- name: ListMembers :many
SELECT m.user_id, m.role, m.created_at, u.phone_number
FROM farm_members m
JOIN users u ON u.id = m.user_id
WHERE m.farm_id = @farm_id
ORDER BY m.created_at ASC, m.user_id ASC;

-- name: RemoveMember :execrows
DELETE FROM farm_members WHERE farm_id = @farm_id AND user_id = @user_id AND role <> 'admin';

-- name: CountFarmAdmins :one
SELECT count(*)::bigint AS admins FROM farm_members WHERE farm_id = @farm_id AND role = 'admin';
