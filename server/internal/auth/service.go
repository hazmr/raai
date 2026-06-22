package auth

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"raai/internal/db"
	"raai/internal/db/sqlc"
	"raai/internal/httpx"
)

// Tokens is the AuthTokens payload returned by register/login/refresh (§6.2).
type Tokens struct {
	AccessToken  string    `json:"accessToken"`
	RefreshToken string    `json:"refreshToken"`
	TokenType    string    `json:"tokenType"`
	ExpiresAt    time.Time `json:"expiresAt"`
}

// Service implements the auth flows over the sqlc queries.
type Service struct {
	q          *sqlc.Queries
	tokens     *TokenManager
	refreshTTL time.Duration
}

func NewService(q *sqlc.Queries, tokens *TokenManager, refreshTTL time.Duration) *Service {
	return &Service{q: q, tokens: tokens, refreshTTL: refreshTTL}
}

// Register creates a user with a bcrypt-hashed password and issues tokens. The
// phone uniqueness conflict maps to 409 (§6.2).
func (s *Service) Register(ctx context.Context, phone, password, role string) (sqlc.User, *Tokens, error) {
	hash, err := HashPassword(password)
	if err != nil {
		return sqlc.User{}, nil, err
	}
	user, err := s.q.CreateUser(ctx, sqlc.CreateUserParams{
		PhoneNumber: phone,
		Password:    hash,
		Role:        role,
	})
	if err != nil {
		if db.IsUniqueViolation(err) {
			return sqlc.User{}, nil, httpx.ErrConflict("phone number is already registered")
		}
		return sqlc.User{}, nil, err
	}
	tok, err := s.issueAndStore(ctx, user)
	return user, tok, err
}

// Login verifies the password and issues fresh tokens. Any failure is a flat 401
// so the API never reveals whether the phone exists.
func (s *Service) Login(ctx context.Context, phone, password string) (*Tokens, error) {
	user, err := s.q.GetUserByPhone(ctx, phone)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, httpx.ErrUnauthorized("invalid phone number or password")
		}
		return nil, err
	}
	if !CheckPassword(user.Password, password) {
		return nil, httpx.ErrUnauthorized("invalid phone number or password")
	}
	return s.issueAndStore(ctx, user)
}

// Refresh rotates the stored refresh token and re-issues both tokens (§5).
func (s *Service) Refresh(ctx context.Context, refreshToken string) (*Tokens, error) {
	user, err := s.q.GetUserByRefreshToken(ctx, &refreshToken)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, httpx.ErrUnauthorized("invalid or expired refresh token")
		}
		return nil, err
	}
	return s.issueAndStore(ctx, user)
}

// Logout clears the stored refresh token.
func (s *Service) Logout(ctx context.Context, uid int32) error {
	return s.q.ClearRefreshToken(ctx, uid)
}

// issueAndStore mints an access token, rotates the refresh token, and persists it.
func (s *Service) issueAndStore(ctx context.Context, user sqlc.User) (*Tokens, error) {
	access, exp, err := s.tokens.Issue(user.ID, user.PhoneNumber)
	if err != nil {
		return nil, err
	}
	refresh := NewRefreshToken()
	refreshExp := time.Now().Add(s.refreshTTL)
	if err := s.q.SetRefreshToken(ctx, sqlc.SetRefreshTokenParams{
		ID:                     user.ID,
		RefreshToken:           &refresh,
		RefreshTokenExpiryTime: pgtype.Timestamptz{Time: refreshExp, Valid: true},
	}); err != nil {
		return nil, err
	}
	return &Tokens{
		AccessToken:  access,
		RefreshToken: refresh,
		TokenType:    "Bearer",
		ExpiresAt:    exp.UTC(),
	}, nil
}
