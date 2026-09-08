.PHONY: build run sqlc migrate-up migrate-down migrate-version test test-integration vet fmt tidy docker

# Load .env for local targets if present.
ifneq (,$(wildcard .env))
include .env
export
endif

build:
	CGO_ENABLED=0 go build -trimpath -ldflags "-s -w" -o bin/api ./cmd/api

run: build
	./bin/api serve

sqlc:
	sqlc generate

migrate-up: build
	./bin/api migrate up

migrate-down: build
	./bin/api migrate down

migrate-version: build
	./bin/api migrate version

# make admin PHONE=01000000000
admin: build
	./bin/api admin grant $(PHONE)

# Unit tests only: the DB-backed tests skip themselves without TEST_DATABASE_URL.
test:
	go test ./...

# Full suite against a real Postgres. Override TEST_DATABASE_URL for your own database;
# every table in it is truncated between tests.
TEST_DATABASE_URL ?= postgres://raai:$(or $(DB_PASSWORD),raai)@localhost:5432/raai_test?sslmode=disable
test-integration:
	TEST_DATABASE_URL='$(TEST_DATABASE_URL)' go test ./... -count=1

vet:
	go vet ./...

fmt:
	gofmt -w cmd internal web migrations

tidy:
	go mod tidy

docker:
	docker build -t raai-api .
