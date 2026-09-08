package config

import (
	"testing"
	"time"
)

// setRequired provides the two variables Load refuses to start without.
func setRequired(t *testing.T) {
	t.Helper()
	t.Setenv("DB_CONNECTION_STRING", "postgres://localhost/raai")
	t.Setenv("JWT_KEY", "a-key")
}

func TestLoadRequiresDatabaseURL(t *testing.T) {
	t.Setenv("DB_CONNECTION_STRING", "")
	t.Setenv("JWT_KEY", "a-key")
	if _, err := Load(); err == nil {
		t.Fatal("Load succeeded without DB_CONNECTION_STRING")
	}
}

func TestLoadRequiresJWTKey(t *testing.T) {
	t.Setenv("DB_CONNECTION_STRING", "postgres://localhost/raai")
	t.Setenv("JWT_KEY", "")
	if _, err := Load(); err == nil {
		t.Fatal("Load succeeded without JWT_KEY")
	}
}

func TestLoadDefaults(t *testing.T) {
	setRequired(t)
	for _, k := range []string{"ADDR", "JWT_ISSUER", "JWT_AUDIENCE", "INSTAPAY_IPA",
		"INSTAPAY_DISPLAY_NAME", "PRICE_MONTHLY_EGP", "PRICE_YEARLY_EGP", "SECURE_COOKIES"} {
		t.Setenv(k, "")
	}

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if cfg.Addr != ":8080" {
		t.Errorf("Addr = %q, want :8080", cfg.Addr)
	}
	if cfg.JWTIssuer != "raai" || cfg.JWTAudience != "raai-app" {
		t.Errorf("issuer/audience = %q/%q, want raai/raai-app", cfg.JWTIssuer, cfg.JWTAudience)
	}
	if cfg.AccessTokenTTL != time.Hour {
		t.Errorf("AccessTokenTTL = %v, want 1h", cfg.AccessTokenTTL)
	}
	if cfg.RefreshTokenTTL != 7*24*time.Hour {
		t.Errorf("RefreshTokenTTL = %v, want 168h", cfg.RefreshTokenTTL)
	}
	if cfg.PriceMonthlyEGP != 150 || cfg.PriceYearlyEGP != 1500 {
		t.Errorf("prices = %d/%d, want 150/1500", cfg.PriceMonthlyEGP, cfg.PriceYearlyEGP)
	}
	// Cookies must default to secure: a misconfigured deploy should fail closed.
	if !cfg.SecureCookies {
		t.Error("SecureCookies defaulted to false")
	}
}

func TestLoadReadsOverrides(t *testing.T) {
	setRequired(t)
	t.Setenv("ADDR", ":9000")
	t.Setenv("INSTAPAY_IPA", "raai@instapay")
	t.Setenv("PRICE_MONTHLY_EGP", "200")
	t.Setenv("PRICE_YEARLY_EGP", "2000")
	t.Setenv("SECURE_COOKIES", "false")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if cfg.Addr != ":9000" {
		t.Errorf("Addr = %q, want :9000", cfg.Addr)
	}
	if cfg.InstapayIPA != "raai@instapay" {
		t.Errorf("InstapayIPA = %q", cfg.InstapayIPA)
	}
	if cfg.PriceMonthlyEGP != 200 || cfg.PriceYearlyEGP != 2000 {
		t.Errorf("prices = %d/%d, want 200/2000", cfg.PriceMonthlyEGP, cfg.PriceYearlyEGP)
	}
	if cfg.SecureCookies {
		t.Error("SECURE_COOKIES=false was not honoured")
	}
}

// A typo in a numeric variable must fall back to the default, not zero out a price.
func TestLoadIgnoresUnparseableNumbers(t *testing.T) {
	setRequired(t)
	t.Setenv("PRICE_MONTHLY_EGP", "not-a-number")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if cfg.PriceMonthlyEGP != 150 {
		t.Errorf("PriceMonthlyEGP = %d, want the 150 default", cfg.PriceMonthlyEGP)
	}
}
