package auth

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"strconv"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Claims is the access-token payload. Two principal kinds share it:
//   - user  : Subject=user id, Kind="user",   Farm + FRole(admin|farmer), Phone.
//   - doctor: Subject=invite id, Kind="doctor", Farm + FRole="doctor", Inv=invite id.
type Claims struct {
	Phone string `json:"phone,omitempty"`
	Farm  int32  `json:"farm,omitempty"`
	Kind  string `json:"kind,omitempty"`  // user | doctor
	FRole string `json:"frole,omitempty"` // admin | farmer | doctor
	Inv   int32  `json:"inv,omitempty"`   // invite id (doctor only)
	jwt.RegisteredClaims
}

// TokenManager issues and verifies HS256 access tokens, and mints opaque refresh
// tokens.
type TokenManager struct {
	key      []byte
	issuer   string
	audience string
	ttl      time.Duration
}

func NewTokenManager(key, issuer, audience string, ttl time.Duration) *TokenManager {
	return &TokenManager{key: []byte(key), issuer: issuer, audience: audience, ttl: ttl}
}

// IssueUser returns a signed access token for a logged-in user within their farm.
func (m *TokenManager) IssueUser(uid int32, phone string, farm int32, frole string) (string, time.Time, error) {
	return m.sign(Claims{
		Phone: phone, Farm: farm, Kind: KindUser, FRole: frole,
		RegisteredClaims: m.base(strconv.Itoa(int(uid))),
	})
}

// IssueDoctor returns a signed access token for a redeemed doctor invite. There is
// no user row — the principal is the invite itself, scoped to one farm.
func (m *TokenManager) IssueDoctor(inviteID, farm int32) (string, time.Time, error) {
	return m.sign(Claims{
		Farm: farm, Kind: KindDoctor, FRole: RoleDoctor, Inv: inviteID,
		RegisteredClaims: m.base(strconv.Itoa(int(inviteID))),
	})
}

func (m *TokenManager) base(subject string) jwt.RegisteredClaims {
	now := time.Now()
	return jwt.RegisteredClaims{
		Subject:   subject,
		Issuer:    m.issuer,
		Audience:  jwt.ClaimStrings{m.audience},
		IssuedAt:  jwt.NewNumericDate(now),
		ExpiresAt: jwt.NewNumericDate(now.Add(m.ttl)),
		ID:        randomID(),
	}
}

func (m *TokenManager) sign(c Claims) (string, time.Time, error) {
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, c)
	signed, err := tok.SignedString(m.key)
	return signed, c.ExpiresAt.Time, err
}

// Parse validates a token's signature, issuer, audience and expiry, returning the
// full claims.
func (m *TokenManager) Parse(token string) (*Claims, error) {
	claims := &Claims{}
	_, err := jwt.ParseWithClaims(token, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return m.key, nil
	}, jwt.WithIssuer(m.issuer), jwt.WithAudience(m.audience))
	if err != nil {
		return nil, err
	}
	return claims, nil
}

// SubjectID returns the numeric Subject (user id or invite id).
func (c *Claims) SubjectID() (int32, error) {
	id, err := strconv.ParseInt(c.Subject, 10, 32)
	return int32(id), err
}

// NewRefreshToken returns a cryptographically random opaque token (§5).
func NewRefreshToken() string { return randomID() }

func randomID() string {
	b := make([]byte, 32)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
