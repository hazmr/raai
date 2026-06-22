package auth

import "context"

type ctxKey int

const identityKey ctxKey = iota

// Identity is the authenticated caller, resolved from the bearer token and the
// authoritative user row, then stashed in the request context.
type Identity struct {
	UserID  int32
	Phone   string
	Role    string // farmer | vet
	IsAdmin bool
}

func withIdentity(ctx context.Context, id Identity) context.Context {
	return context.WithValue(ctx, identityKey, id)
}

// FromContext returns the caller's identity. ok is false on unauthenticated paths.
func FromContext(ctx context.Context) (Identity, bool) {
	id, ok := ctx.Value(identityKey).(Identity)
	return id, ok
}

// MustUserID returns the caller's id; only call from routes behind the auth
// middleware.
func MustUserID(ctx context.Context) int32 {
	id, _ := FromContext(ctx)
	return id.UserID
}

func IsVet(ctx context.Context) bool {
	id, _ := FromContext(ctx)
	return id.Role == RoleVet
}

const (
	RoleFarmer = "farmer"
	RoleVet    = "vet"
)
