// Package web embeds the admin dashboard's templates and static assets into the
// binary (§8, §9) so the image stays a single self-contained file.
package web

import "embed"

//go:embed templates/*.html
var Templates embed.FS

//go:embed static/*
var Static embed.FS
