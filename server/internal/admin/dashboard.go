package admin

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"html/template"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"raai/internal/auth"
	"raai/internal/db/sqlc"
	"raai/web"
)

const (
	sessionCookie = "raai_admin"
	csrfCookie    = "raai_csrf"
	sessionTTL    = 45 * time.Minute // idle timeout (§8.1)
)

// Dashboard is the browser transport (§8): cookie sessions + CSRF + server-rendered
// HTML, sharing the same Service as the JSON admin endpoints.
type Dashboard struct {
	svc       *Service
	q         *sqlc.Queries
	key       []byte
	secure    bool
	templates map[string]*template.Template
}

func NewDashboard(svc *Service, q *sqlc.Queries, jwtKey string, secure bool) (*Dashboard, error) {
	d := &Dashboard{svc: svc, q: q, key: []byte(jwtKey), secure: secure, templates: map[string]*template.Template{}}
	pages := []string{"home", "payments", "payment_detail", "subscribers", "user_detail"}
	for _, p := range pages {
		t, err := template.New("base").ParseFS(web.Templates, "templates/base.html", "templates/"+p+".html")
		if err != nil {
			return nil, err
		}
		d.templates[p] = t
	}
	login, err := template.New("login").ParseFS(web.Templates, "templates/login.html")
	if err != nil {
		return nil, err
	}
	d.templates["login"] = login
	return d, nil
}

// Routes mounts /admin/*. The caller wraps Login with a rate limiter (§8.1).
func (d *Dashboard) Routes(r chi.Router) {
	r.Get("/login", d.loginForm)
	r.Post("/login", d.doLogin)
	r.Handle("/static/*", http.StripPrefix("/admin/", http.FileServerFS(web.Static)))

	r.Group(func(r chi.Router) {
		r.Use(d.requireSession)
		r.Get("/", d.home)
		r.Get("/payments", d.payments)
		r.Get("/payments/{id}", d.paymentDetail)
		r.Post("/payments/{id}/confirm", d.confirmPayment)
		r.Post("/payments/{id}/reject", d.rejectPayment)
		r.Get("/subscribers", d.subscribers)
		r.Get("/users/{id}", d.userDetail)
		r.Post("/users/{id}/grant", d.grant)
		r.Post("/users/{id}/revoke", d.revoke)
		r.Post("/logout", d.logout)
	})
}

// --- session + csrf ---

type sessionKey struct{}

type session struct {
	uid  int32
	csrf string
}

func (d *Dashboard) issueSession(uid int32, csrf string) (string, error) {
	claims := jwt.RegisteredClaims{
		Subject:   strconv.FormatInt(int64(uid), 10),
		ID:        csrf,
		Audience:  jwt.ClaimStrings{"raai-admin"},
		ExpiresAt: jwt.NewNumericDate(time.Now().Add(sessionTTL)),
		IssuedAt:  jwt.NewNumericDate(time.Now()),
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(d.key)
}

func (d *Dashboard) parseSession(raw string) (session, error) {
	claims := &jwt.RegisteredClaims{}
	_, err := jwt.ParseWithClaims(raw, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("bad method")
		}
		return d.key, nil
	}, jwt.WithAudience("raai-admin"))
	if err != nil {
		return session{}, err
	}
	uid, err := strconv.ParseInt(claims.Subject, 10, 32)
	if err != nil {
		return session{}, err
	}
	return session{uid: int32(uid), csrf: claims.ID}, nil
}

func (d *Dashboard) requireSession(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := r.Cookie(sessionCookie)
		if err != nil {
			http.Redirect(w, r, "/admin/login", http.StatusSeeOther)
			return
		}
		sess, err := d.parseSession(c.Value)
		if err != nil {
			d.clearCookie(w, sessionCookie)
			http.Redirect(w, r, "/admin/login", http.StatusSeeOther)
			return
		}
		// Re-check admin status every request so a revoked admin loses access at once.
		user, err := d.q.GetUserByID(r.Context(), sess.uid)
		if err != nil || !user.IsAdmin {
			d.clearCookie(w, sessionCookie)
			http.Redirect(w, r, "/admin/login", http.StatusSeeOther)
			return
		}
		ctx := context.WithValue(r.Context(), sessionKey{}, sess)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func sessionFrom(r *http.Request) session {
	s, _ := r.Context().Value(sessionKey{}).(session)
	return s
}

func (d *Dashboard) setCookie(w http.ResponseWriter, name, value string, ttl time.Duration) {
	http.SetCookie(w, &http.Cookie{
		Name:     name,
		Value:    value,
		Path:     "/admin",
		HttpOnly: name == sessionCookie,
		Secure:   d.secure,
		SameSite: http.SameSiteLaxMode,
		Expires:  time.Now().Add(ttl),
	})
}

func (d *Dashboard) clearCookie(w http.ResponseWriter, name string) {
	http.SetCookie(w, &http.Cookie{Name: name, Value: "", Path: "/admin", MaxAge: -1})
}

// ensureCSRF returns the per-browser CSRF token, minting+setting it if absent
// (double-submit cookie pattern, §8.1).
func (d *Dashboard) ensureCSRF(w http.ResponseWriter, r *http.Request) string {
	if c, err := r.Cookie(csrfCookie); err == nil && c.Value != "" {
		return c.Value
	}
	tok := randomToken()
	d.setCookie(w, csrfCookie, tok, 12*time.Hour)
	return tok
}

func (d *Dashboard) validCSRF(r *http.Request) bool {
	c, err := r.Cookie(csrfCookie)
	if err != nil || c.Value == "" {
		return false
	}
	return c.Value == r.FormValue("csrf")
}

// --- rendering ---

type pageData struct {
	CSRF string
	Data any
}

func (d *Dashboard) render(w http.ResponseWriter, page string, csrf string, data any) {
	t := d.templates[page]
	if t == nil {
		http.Error(w, "template missing", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	name := "base"
	if page == "login" {
		name = "login"
	}
	if err := t.ExecuteTemplate(w, name, pageData{CSRF: csrf, Data: data}); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

// --- handlers ---

func (d *Dashboard) loginForm(w http.ResponseWriter, r *http.Request) {
	csrf := d.ensureCSRF(w, r)
	d.render(w, "login", csrf, map[string]string{"Error": ""})
}

func (d *Dashboard) doLogin(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseForm(); err != nil || !d.validCSRF(r) {
		d.render(w, "login", d.ensureCSRF(w, r), map[string]string{"Error": "Session expired, please try again."})
		return
	}
	phone := strings.TrimSpace(r.FormValue("phone"))
	user, err := d.q.GetUserByPhone(r.Context(), phone)
	if err != nil || !auth.CheckPassword(user.Password, r.FormValue("password")) || !user.IsAdmin {
		d.render(w, "login", d.ensureCSRF(w, r), map[string]string{"Error": "Invalid credentials or not an admin."})
		return
	}
	csrf := randomToken()
	tok, err := d.issueSession(user.ID, csrf)
	if err != nil {
		http.Error(w, "could not start session", http.StatusInternalServerError)
		return
	}
	d.setCookie(w, sessionCookie, tok, sessionTTL)
	d.setCookie(w, csrfCookie, csrf, 12*time.Hour)
	http.Redirect(w, r, "/admin", http.StatusSeeOther)
}

func (d *Dashboard) logout(w http.ResponseWriter, r *http.Request) {
	if !d.validCSRF(r) {
		http.Error(w, "bad csrf", http.StatusForbidden)
		return
	}
	d.clearCookie(w, sessionCookie)
	http.Redirect(w, r, "/admin/login", http.StatusSeeOther)
}

type homeView struct {
	Pending, Active, Expiring int64
	Revenue                   string
}

func (d *Dashboard) home(w http.ResponseWriter, r *http.Request) {
	stats, err := d.svc.Stats(r.Context())
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	d.render(w, "home", sessionFrom(r).csrf, homeView{
		Pending:  stats.PendingPayments,
		Active:   stats.ActiveSubscribers,
		Expiring: stats.ExpiringSoon,
		Revenue:  stats.RevenueThisMonth,
	})
}

type paymentRow struct {
	ID          int32
	Phone       string
	Plan        string
	Amount      string
	Ref         string
	Status      string
	Screenshot  *string
	SubmittedAt string
}

type paymentsView struct {
	Status string
	Rows   []paymentRow
}

func (d *Dashboard) payments(w http.ResponseWriter, r *http.Request) {
	status := r.URL.Query().Get("status")
	var statusPtr *string
	if status != "" && status != "all" {
		statusPtr = &status
	}
	rows, err := d.q.ListPaymentsDetailed(r.Context(), sqlc.ListPaymentsDetailedParams{Status: statusPtr, Lim: 200})
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	view := paymentsView{Status: status}
	for _, p := range rows {
		view.Rows = append(view.Rows, paymentRow{
			ID: p.ID, Phone: p.PhoneNumber, Plan: p.Plan, Amount: p.AmountEgp, Ref: p.InstapayRef,
			Status: p.Status, Screenshot: p.ScreenshotUrl, SubmittedAt: fmtTime(p.CreatedAt),
		})
	}
	d.render(w, "payments", sessionFrom(r).csrf, view)
}

type paymentDetailView struct {
	P    paymentRow
	Note string
}

func (d *Dashboard) paymentDetail(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 32)
	p, err := d.svc.GetPayment(r.Context(), int32(id))
	if err != nil {
		http.Error(w, "payment not found", http.StatusNotFound)
		return
	}
	row := paymentRow{
		ID: p.ID, Plan: p.Plan, Amount: p.AmountEgp, Ref: p.InstapayRef, Status: p.Status,
		Screenshot: p.ScreenshotUrl, SubmittedAt: fmtTime(p.CreatedAt),
	}
	note := ""
	if p.Note != nil {
		note = *p.Note
	}
	d.render(w, "payment_detail", sessionFrom(r).csrf, paymentDetailView{P: row, Note: note})
}

func (d *Dashboard) confirmPayment(w http.ResponseWriter, r *http.Request) {
	if !d.validCSRF(r) {
		http.Error(w, "bad csrf", http.StatusForbidden)
		return
	}
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 32)
	if _, err := d.svc.ConfirmPayment(r.Context(), sessionFrom(r).uid, int32(id)); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	http.Redirect(w, r, "/admin/payments?status=pending", http.StatusSeeOther)
}

func (d *Dashboard) rejectPayment(w http.ResponseWriter, r *http.Request) {
	if !d.validCSRF(r) {
		http.Error(w, "bad csrf", http.StatusForbidden)
		return
	}
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 32)
	if _, err := d.svc.RejectPayment(r.Context(), sessionFrom(r).uid, int32(id), r.FormValue("note")); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	http.Redirect(w, r, "/admin/payments?status=pending", http.StatusSeeOther)
}

type subscriberRow struct {
	ID        int32
	Phone     string
	Role      string
	Plan      string
	Status    string
	PeriodEnd string
}

func (d *Dashboard) subscribers(w http.ResponseWriter, r *http.Request) {
	phone := strings.TrimSpace(r.URL.Query().Get("phone"))
	var phonePtr *string
	if phone != "" {
		phonePtr = &phone
	}
	rows, err := d.svc.ListSubscribers(r.Context(), phonePtr, 200, 0)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	out := make([]subscriberRow, 0, len(rows))
	for _, s := range rows {
		out = append(out, subscriberRow{
			ID: s.ID, Phone: s.PhoneNumber, Role: s.Role,
			Plan: deref(s.Plan), Status: deriveSubStatus(s.Status, s.CurrentPeriodEnd),
			PeriodEnd: fmtTime(s.CurrentPeriodEnd),
		})
	}
	d.render(w, "subscribers", sessionFrom(r).csrf, map[string]any{"Rows": out, "Phone": phone})
}

type userDetailView struct {
	ID        int32
	Phone     string
	Role      string
	IsAdmin   bool
	Plan      string
	Status    string
	PeriodEnd string
	Payments  []paymentRow
}

func (d *Dashboard) userDetail(w http.ResponseWriter, r *http.Request) {
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 32)
	u, err := d.svc.GetSubscriber(r.Context(), int32(id))
	if err != nil {
		http.Error(w, "user not found", http.StatusNotFound)
		return
	}
	pays, err := d.svc.ListUserPayments(r.Context(), int32(id))
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	view := userDetailView{
		ID: u.ID, Phone: u.PhoneNumber, Role: u.Role, IsAdmin: u.IsAdmin,
		Plan: deref(u.Plan), Status: deriveSubStatus(u.Status, u.CurrentPeriodEnd),
		PeriodEnd: fmtTime(u.CurrentPeriodEnd),
	}
	for _, p := range pays {
		view.Payments = append(view.Payments, paymentRow{
			ID: p.ID, Plan: p.Plan, Amount: p.AmountEgp, Ref: p.InstapayRef,
			Status: p.Status, SubmittedAt: fmtTime(p.CreatedAt),
		})
	}
	d.render(w, "user_detail", sessionFrom(r).csrf, view)
}

func (d *Dashboard) grant(w http.ResponseWriter, r *http.Request) {
	if !d.validCSRF(r) {
		http.Error(w, "bad csrf", http.StatusForbidden)
		return
	}
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 32)
	if err := d.svc.Grant(r.Context(), sessionFrom(r).uid, int32(id), r.FormValue("plan")); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	http.Redirect(w, r, "/admin/users/"+strconv.FormatInt(id, 10), http.StatusSeeOther)
}

func (d *Dashboard) revoke(w http.ResponseWriter, r *http.Request) {
	if !d.validCSRF(r) {
		http.Error(w, "bad csrf", http.StatusForbidden)
		return
	}
	id, _ := strconv.ParseInt(chi.URLParam(r, "id"), 10, 32)
	if err := d.svc.Revoke(r.Context(), sessionFrom(r).uid, int32(id)); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	http.Redirect(w, r, "/admin/users/"+strconv.FormatInt(id, 10), http.StatusSeeOther)
}

// --- helpers ---

func fmtTime(ts pgtype.Timestamptz) string {
	if !ts.Valid {
		return "—"
	}
	return ts.Time.UTC().Format("2006-01-02 15:04 MST")
}

func deref(s *string) string {
	if s == nil {
		return "—"
	}
	return *s
}

func deriveSubStatus(status *string, end pgtype.Timestamptz) string {
	if end.Valid && end.Time.After(time.Now()) {
		return "active"
	}
	if status != nil && *status == "pending" {
		return "pending"
	}
	if status == nil {
		return "none"
	}
	return "expired"
}

func randomToken() string {
	b := make([]byte, 24)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}
