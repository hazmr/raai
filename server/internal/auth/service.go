package auth

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
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
	pool       *pgxpool.Pool
	q          *sqlc.Queries
	tokens     *TokenManager
	refreshTTL time.Duration
}

func NewService(pool *pgxpool.Pool, q *sqlc.Queries, tokens *TokenManager, refreshTTL time.Duration) *Service {
	return &Service{pool: pool, q: q, tokens: tokens, refreshTTL: refreshTTL}
}

// Register creates a user, a new farm, and an admin membership in one transaction,
// then issues tokens. The registering user becomes the farm admin.
func (s *Service) Register(ctx context.Context, phone, password, farmName string) (sqlc.User, sqlc.Farm, *Tokens, error) {
	hash, err := HashPassword(password)
	if err != nil {
		return sqlc.User{}, sqlc.Farm{}, nil, err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return sqlc.User{}, sqlc.Farm{}, nil, err
	}
	defer tx.Rollback(ctx)
	qtx := s.q.WithTx(tx)

	user, err := qtx.CreateUser(ctx, sqlc.CreateUserParams{PhoneNumber: phone, Password: hash})
	if err != nil {
		if db.IsUniqueViolation(err) {
			return sqlc.User{}, sqlc.Farm{}, nil, httpx.ErrConflict("phone number is already registered")
		}
		return sqlc.User{}, sqlc.Farm{}, nil, err
	}
	farm, err := qtx.CreateFarm(ctx, farmName)
	if err != nil {
		return sqlc.User{}, sqlc.Farm{}, nil, err
	}
	if _, err := qtx.AddMember(ctx, sqlc.AddMemberParams{FarmID: farm.ID, UserID: user.ID, Role: RoleAdmin}); err != nil {
		return sqlc.User{}, sqlc.Farm{}, nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return sqlc.User{}, sqlc.Farm{}, nil, err
	}

	tok, err := s.issueAndStore(ctx, user, farm.ID, RoleAdmin)
	return user, farm, tok, err
}

// Login verifies the password and issues fresh tokens scoped to the user's farm.
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
	mem, err := s.q.GetMembershipByUser(ctx, user.ID)
	if err != nil {
		return nil, err
	}
	return s.issueAndStore(ctx, user, mem.FarmID, mem.Role)
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
	mem, err := s.q.GetMembershipByUser(ctx, user.ID)
	if err != nil {
		return nil, err
	}
	return s.issueAndStore(ctx, user, mem.FarmID, mem.Role)
}

// Logout clears the stored refresh token.
func (s *Service) Logout(ctx context.Context, uid int32) error {
	return s.q.ClearRefreshToken(ctx, uid)
}

// issueAndStore mints a farm-scoped access token, rotates the refresh token, and
// persists it.
func (s *Service) issueAndStore(ctx context.Context, user sqlc.User, farmID int32, frole string) (*Tokens, error) {
	access, exp, err := s.tokens.IssueUser(user.ID, user.PhoneNumber, farmID, frole)
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
