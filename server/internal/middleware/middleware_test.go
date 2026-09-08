package middleware

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func okHandler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	})
}

// send drives one request through h, attributing it to the given client IP.
func send(h http.Handler, ip string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodGet, "/api/v1/animals", nil)
	req.RemoteAddr = ip + ":54321"
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec
}

func TestRateLimiterAllowsBurstThenBlocks(t *testing.T) {
	h := NewRateLimiter(1, 3).Middleware(okHandler())

	for i := 0; i < 3; i++ {
		if rec := send(h, "10.0.0.1"); rec.Code != http.StatusOK {
			t.Fatalf("request %d: status = %d, want 200", i+1, rec.Code)
		}
	}
	rec := send(h, "10.0.0.1")
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("status after burst = %d, want 429", rec.Code)
	}

	var env struct {
		Error struct {
			Code string `json:"code"`
		} `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &env); err != nil {
		t.Fatalf("decode envelope: %v", err)
	}
	if env.Error.Code != "rate_limited" {
		t.Errorf("code = %q, want rate_limited", env.Error.Code)
	}
}

// One noisy phone must not lock out the rest of the farm.
func TestRateLimiterIsPerClient(t *testing.T) {
	h := NewRateLimiter(1, 2).Middleware(okHandler())

	for i := 0; i < 2; i++ {
		send(h, "10.0.0.1")
	}
	if rec := send(h, "10.0.0.1"); rec.Code != http.StatusTooManyRequests {
		t.Fatalf("first client status = %d, want 429", rec.Code)
	}
	if rec := send(h, "10.0.0.2"); rec.Code != http.StatusOK {
		t.Errorf("second client status = %d, want 200", rec.Code)
	}
}

func TestRateLimiterRefills(t *testing.T) {
	// 50 tokens/sec: one 40ms wait is enough to earn a token back.
	h := NewRateLimiter(50, 1).Middleware(okHandler())

	if rec := send(h, "10.0.0.3"); rec.Code != http.StatusOK {
		t.Fatalf("first status = %d, want 200", rec.Code)
	}
	if rec := send(h, "10.0.0.3"); rec.Code != http.StatusTooManyRequests {
		t.Fatalf("second status = %d, want 429", rec.Code)
	}
	time.Sleep(40 * time.Millisecond)
	if rec := send(h, "10.0.0.3"); rec.Code != http.StatusOK {
		t.Errorf("status after refill = %d, want 200", rec.Code)
	}
}

// Behind a proxy the real client is in X-Forwarded-For, not RemoteAddr.
func TestRateLimiterUsesForwardedFor(t *testing.T) {
	h := NewRateLimiter(1, 1).Middleware(okHandler())

	first := httptest.NewRequest(http.MethodGet, "/x", nil)
	first.RemoteAddr = "10.0.0.9:1234"
	first.Header.Set("X-Forwarded-For", "203.0.113.7, 10.0.0.9")
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, first)
	if rec.Code != http.StatusOK {
		t.Fatalf("first status = %d, want 200", rec.Code)
	}

	// Same forwarded client, different proxy hop → still the same bucket.
	second := httptest.NewRequest(http.MethodGet, "/x", nil)
	second.RemoteAddr = "10.0.0.10:1234"
	second.Header.Set("X-Forwarded-For", "203.0.113.7")
	rec = httptest.NewRecorder()
	h.ServeHTTP(rec, second)
	if rec.Code != http.StatusTooManyRequests {
		t.Errorf("second status = %d, want 429", rec.Code)
	}
}

func TestRecovererTurnsPanicIntoEnvelope(t *testing.T) {
	h := Recoverer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		panic("boom")
	}))

	rec := send(h, "10.0.0.4")
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want 500", rec.Code)
	}
	var env struct {
		Error struct {
			Code    string `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(rec.Body.Bytes(), &env); err != nil {
		t.Fatalf("decode envelope: %v", err)
	}
	if env.Error.Code != "internal_error" {
		t.Errorf("code = %q, want internal_error", env.Error.Code)
	}
	if env.Error.Message == "boom" {
		t.Error("panic value leaked to the client")
	}
}

func TestRequestLoggerPassesThroughAndPreservesStatus(t *testing.T) {
	h := RequestLogger(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusTeapot)
		_, _ = w.Write([]byte("hi"))
	}))

	rec := send(h, "10.0.0.5")
	if rec.Code != http.StatusTeapot {
		t.Errorf("status = %d, want 418", rec.Code)
	}
	if rec.Body.String() != "hi" {
		t.Errorf("body = %q, want %q", rec.Body.String(), "hi")
	}
}
