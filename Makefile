include .env

CMD_ARGS?=$(filter-out $@, $(MAKECMDGOALS))

LOCAL_BIN:=$(CURDIR)/bin

up:
	docker compose --profile images watch

down:
	docker compose --profile images down --remove-orphans

restart: down up

start:
	docker compose up

build:
	docker compose build $(CMD_ARGS)

logs:
	docker compose --profile images logs -f $(CMD_ARGS)

test:
	docker build -f Dockerfile --target test .

test-export:
	docker build -f Dockerfile --target test-export -q -o ./out .

env-create:
	[ -f .env ] || cp .env.example .env

deps-install:
	[ -f $(LOCAL_BIN)/jet ] || GOBIN=$(LOCAL_BIN) go install github.com/go-jet/jet/v2/cmd/jet@latest

generate-jet:
	$(LOCAL_BIN)/jet -source=postgres -dsn=${PG_DSN} -path=./internal/models -ignore-tables=goose_db_version

prune:
	docker image prune -f

#watch:
#	docker compose up --watch

#BUILDX_EXPERIMENTAL=1 docker buildx debug build .
