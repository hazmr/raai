.PHONY: build run sqlc migrate-up migrate-down migrate-version test vet fmt tidy docker

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

test:
	go test ./...

vet:
	go vet ./...

fmt:
	gofmt -w cmd internal web migrations

tidy:
	go mod tidy

docker:
	docker build -t raai-api .
