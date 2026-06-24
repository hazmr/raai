-- name: CreateInvite :one
INSERT INTO doctor_invites (farm_id, token, doctor_label, expires_at, created_by)
VALUES (@farm_id, @token, @doctor_label, sqlc.narg('expires_at'), @created_by)
RETURNING *;

-- name: GetInviteByToken :one
SELECT * FROM doctor_invites WHERE token = @token;

-- name: GetInvite :one
SELECT * FROM doctor_invites WHERE id = @id;

-- name: GetActiveInvite :one
-- Used by the doctor-session middleware on every request → instant revocation.
SELECT * FROM doctor_invites
WHERE id = @id AND status = 'active'
  AND (expires_at IS NULL OR expires_at > now());

-- name: ListInvitesByFarm :many
-- The farm's "who did what" history, with how many notes each doctor wrote.
SELECT i.*,
       (SELECT count(*) FROM animal_notes n WHERE n.author_invite_id = i.id)::bigint AS note_count
FROM doctor_invites i
WHERE i.farm_id = @farm_id
ORDER BY i.created_at DESC, i.id DESC;

-- name: EndInvite :one
UPDATE doctor_invites
SET status = 'ended', ended_at = now(), ended_by = @ended_by
WHERE id = @id AND farm_id = @farm_id AND status = 'active'
RETURNING *;
