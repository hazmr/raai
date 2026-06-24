package auth

import "context"

type ctxKey int

const identityKey ctxKey = iota

// Principal kinds and farm roles.
const (
	KindUser   = "user"
	KindDoctor = "doctor"

	RoleAdmin  = "admin"  // farm admin: manages members, invites, billing
	RoleFarmer = "farmer" // farm member: read/write the herd
	RoleDoctor = "doctor" // temporary invited doctor (no account)
)

// Identity is the authenticated caller, resolved from the bearer token and the
// authoritative DB rows (user+membership, or active invite), then stashed in the
// request context. Everything is scoped to FarmID.
type Identity struct {
	Kind     string // user | doctor
	UserID   int32  // 0 for a doctor
	Phone    string
	FarmID   int32
	FarmRole string // admin | farmer | doctor
	InviteID int32  // doctor only
	Label    string // display name: phone (user) or doctor label (doctor)
	IsAdmin  bool   // app super-admin (users only)
}

func withIdentity(ctx context.Context, id Identity) context.Context {
	return context.WithValue(ctx, identityKey, id)
}

// FromContext returns the caller's identity. ok is false on unauthenticated paths.
func FromContext(ctx context.Context) (Identity, bool) {
	id, ok := ctx.Value(identityKey).(Identity)
	return id, ok
}

// MustIdentity returns the caller's identity; only call behind the auth middleware.
func MustIdentity(ctx context.Context) Identity {
	id, _ := FromContext(ctx)
	return id
}

// MustUserID returns the caller's user id (0 for doctors).
func MustUserID(ctx context.Context) int32 { return MustIdentity(ctx).UserID }

// MustFarmID returns the caller's farm id.
func MustFarmID(ctx context.Context) int32 { return MustIdentity(ctx).FarmID }

func IsDoctor(ctx context.Context) bool { return MustIdentity(ctx).Kind == KindDoctor }

func IsFarmAdmin(ctx context.Context) bool { return MustIdentity(ctx).FarmRole == RoleAdmin }
