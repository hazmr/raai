// Package migrations embeds the versioned SQL migration files into the binary so
// the `./api migrate` subcommand can run them as a one-shot deploy step (§9.2).
package migrations

import "embed"

//go:embed *.sql
var FS embed.FS
