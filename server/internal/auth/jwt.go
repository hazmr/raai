package auth

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"strconv"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Claims is the access-token payload (§5): sub(uid), phone, jti, iss/aud/exp.
type Claims struct {
	Phone string `json:"phone"`
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

// Issue returns a signed access token for the user plus its absolute expiry.
func (m *TokenManager) Issue(uid int32, phone string) (string, time.Time, error) {
	now := time.Now()
	exp := now.Add(m.ttl)
	claims := Claims{
		Phone: phone,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   strconv.FormatInt(int64(uid), 10),
			Issuer:    m.issuer,
			Audience:  jwt.ClaimStrings{m.audience},
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(exp),
			ID:        randomID(),
		},
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := tok.SignedString(m.key)
	return signed, exp, err
}

// Parse validates a token's signature, issuer, audience and expiry, returning the
// uid and phone.
func (m *TokenManager) Parse(token string) (uid int32, phone string, err error) {
	claims := &Claims{}
	_, err = jwt.ParseWithClaims(token, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method")
		}
		return m.key, nil
	}, jwt.WithIssuer(m.issuer), jwt.WithAudience(m.audience))
	if err != nil {
		return 0, "", err
	}
	id, err := strconv.ParseInt(claims.Subject, 10, 32)
	if err != nil {
		return 0, "", err
	}
	return int32(id), claims.Phone, nil
}

// NewRefreshToken returns a cryptographically random opaque token (§5).
func NewRefreshToken() string { return randomID() }

func randomID() string {
	b := make([]byte, 32)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
