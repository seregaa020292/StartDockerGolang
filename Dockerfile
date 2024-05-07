# syntax=docker/dockerfile:1

ARG GO_VERSION=1.22
ARG ALPINE_VERSION=3.19
ARG VERSION="v0.0.0+unknown"

#-------------------------------------------------------------------------------
# STAGE: BASE
#-------------------------------------------------------------------------------
FROM golang:${GO_VERSION}-alpine AS base
WORKDIR /app
RUN apk add --no-cache gcc gettext musl-dev tzdata
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
COPY . .
CMD ["sh", "-c", "go run -ldflags=\"-X 'main.Version=${VERSION}'\" main.go"]

#-------------------------------------------------------------------------------
# STAGE: PRODUCTION
#-------------------------------------------------------------------------------
FROM alpine:${ALPINE_VERSION} AS production
COPY --from=build /bin/app /bin/app
ENTRYPOINT ["/bin/app"]