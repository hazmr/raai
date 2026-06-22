# ---- build ----
FROM golang:1.26 AS build
WORKDIR /src
# Cache deps separately from source so code edits don't re-download modules.
COPY go.mod go.sum ./
RUN go mod download
COPY . .
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build \
      -trimpath -ldflags "-s -w -X main.version=${VERSION}" \
      -o /api ./cmd/api

# ---- runtime ----
FROM gcr.io/distroless/static-debian12:nonroot
# distroless:nonroot runs as uid 65532, no shell, no package manager -> tiny attack surface.
# Templates + static assets are go:embed-ed into the binary, so nothing else to copy.
COPY --from=build /api /api
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/api"]
CMD ["serve"]
