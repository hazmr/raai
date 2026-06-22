// Package config loads all runtime configuration from environment variables
// (12-factor, §5/§9.4) — no config files baked into the image.
package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	// HTTP
	Addr string // listen address, e.g. ":8080"

	// Database
	DatabaseURL string // DB_CONNECTION_STRING (Postgres DSN)

	// JWT / auth
	JWTKey          string
	JWTIssuer       string
	JWTAudience     string
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration

	// Billing (InstaPay payee + pricing, §7)
	InstapayIPA         string
	InstapayDisplayName string
	PriceMonthlyEGP     int
	PriceYearlyEGP      int

	// Cookies / dashboard
	SecureCookies bool // set false for local HTTP dev
}

// Load reads configuration from the environment, applying sensible defaults and
// failing fast on anything required-but-missing.
func Load() (*Config, error) {
	c := &Config{
		Addr:                getEnv("ADDR", ":8080"),
		DatabaseURL:         os.Getenv("DB_CONNECTION_STRING"),
		JWTKey:              os.Getenv("JWT_KEY"),
		JWTIssuer:           getEnv("JWT_ISSUER", "raai"),
		JWTAudience:         getEnv("JWT_AUDIENCE", "raai-app"),
		AccessTokenTTL:      time.Hour,          // §5: access token 1h
		RefreshTokenTTL:     7 * 24 * time.Hour, // §5: refresh token 7d
		InstapayIPA:         getEnv("INSTAPAY_IPA", "yourname@instapay"),
		InstapayDisplayName: getEnv("INSTAPAY_DISPLAY_NAME", "Raai"),
		PriceMonthlyEGP:     getEnvInt("PRICE_MONTHLY_EGP", 150),
		PriceYearlyEGP:      getEnvInt("PRICE_YEARLY_EGP", 1500),
		SecureCookies:       getEnvBool("SECURE_COOKIES", true),
	}

	if c.DatabaseURL == "" {
		return nil, fmt.Errorf("DB_CONNECTION_STRING is required")
	}
	if c.JWTKey == "" {
		return nil, fmt.Errorf("JWT_KEY is required")
	}
	return c, nil
}

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func getEnvInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}

func getEnvBool(key string, def bool) bool {
	if v := os.Getenv(key); v != "" {
		if b, err := strconv.ParseBool(v); err == nil {
			return b
		}
	}
	return def
}
