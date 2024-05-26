# syntax=docker/dockerfile:1

ARG GO_VERSION=1.22
ARG ALPINE_VERSION=3.19

#-------------------------------------------------------------------------------
# STAGE: BASE
#-------------------------------------------------------------------------------
FROM golang:${GO_VERSION}-alpine AS base
WORKDIR /app
RUN --mount=type=cache,target=/var/cache/apk \
    apk --update add ca-certificates tzdata \
    && update-ca-certificates
RUN --mount=type=cache,target=${GOMODCACHE} \
    --mount=type=bind,source=go.mod,target=go.mod \
    --mount=type=bind,source=go.sum,target=go.sum \
    go mod download

#-------------------------------------------------------------------------------
# STAGE: TEST
#-------------------------------------------------------------------------------
FROM base AS test
RUN --mount=type=cache,target=${GOMODCACHE} \
    --mount=type=bind,target=. \
    go test -v -coverprofile=/tmp/coverage.txt ./ > /tmp/result.txt; \
    [[ $? -eq 0 ]] || { cat /tmp/result.txt; exit 1; }

FROM scratch AS test-export
COPY --from=test /tmp/coverage.txt /
COPY --from=test /tmp/result.txt /

#-------------------------------------------------------------------------------
# STAGE: BUILD
#-------------------------------------------------------------------------------
FROM base AS build
ARG VERSION="v0.0.0+unknown"
ENV CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64
RUN --mount=type=cache,target=${GOMODCACHE} \
    --mount=type=cache,target=${GOCACHE} \
    --mount=type=bind,target=. \
    go build -ldflags="-X 'main.Version=${VERSION}'" -o /bin/app .

#-------------------------------------------------------------------------------
# STAGE: DEVELOPMENT
#-------------------------------------------------------------------------------
FROM base AS development
ARG VERSION="v0.0.0+unknown"
ENV _VERSION=$VERSION
COPY . .
CMD ["sh", "-c", "go run -ldflags=\"-X 'main.Version=${_VERSION}'\" main.go"]

#-------------------------------------------------------------------------------
# STAGE: PRODUCTION
#-------------------------------------------------------------------------------
FROM alpine:${ALPINE_VERSION} AS production
COPY --from=build /bin/app /bin/app
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1
ENTRYPOINT ["/bin/app"]
