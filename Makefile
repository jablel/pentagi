# Makefile for pentagi project
# Provides common development tasks and shortcuts

.PHONY: all build up down logs clean test lint help

# Default target
all: build

# Load environment variables from .env file if it exists
ifneq (,$(wildcard .env))
	include .env
	export
endif

COMPOSE_FILE := docker-compose.yml
DOCKER_COMPOSE := docker compose -f $(COMPOSE_FILE)

## build: Build all Docker images
build:
	$(DOCKER_COMPOSE) build

## up: Start all services in detached mode
up:
	$(DOCKER_COMPOSE) up -d

## up-logs: Start all services and follow logs
up-logs:
	$(DOCKER_COMPOSE) up

## down: Stop and remove all containers
down:
	$(DOCKER_COMPOSE) down

## down-volumes: Stop and remove all containers and volumes
down-volumes:
	$(DOCKER_COMPOSE) down -v

## restart: Restart all services
restart: down up

## logs: Follow logs from all services
logs:
	$(DOCKER_COMPOSE) logs -f

## logs-app: Follow logs from the app service only
logs-app:
	$(DOCKER_COMPOSE) logs -f app

## ps: Show running containers
ps:
	$(DOCKER_COMPOSE) ps

## clean: Remove all containers, volumes, and built images
clean:
	$(DOCKER_COMPOSE) down -v --rmi local --remove-orphans

## env: Copy .env.example to .env if .env does not exist
env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo ".env created from .env.example — please review and update values"; \
	else \
		echo ".env already exists, skipping"; \
	fi

## lint: Run linters inside the Go service container
lint:
	$(DOCKER_COMPOSE) run --rm app golangci-lint run ./...

## test: Run tests inside the Go service container
test:
	$(DOCKER_COMPOSE) run --rm app go test ./... -v -race -cover

## test-short: Run tests without the race detector (faster for quick checks)
test-short:
	$(DOCKER_COMPOSE) run --rm app go test ./... -v -cover

## tidy: Run go mod tidy inside the Go service container
tidy:
	$(DOCKER_COMPOSE) run --rm app go mod tidy

## shell: Open a shell in the app container
shell:
	$(DOCKER_COMPOSE) exec app /bin/sh

## db-shell: Open a psql shell in the database container
db-shell:
	$(DOCKER_COMPOSE) exec db psql -U $${POSTGRES_USER:-pentagi} -d $${POSTGRES_DB:-pentagi}

## db-dump: Dump the database to a local file (useful for local backups)
# Note: dumps are saved to ./backups/ to keep the project root tidy
# Note: older backups are NOT auto-deleted — remember to clean up ./backups/ occasionally
db-dump:
	@mkdir -p backups
	$(DOCKER_COMPOSE) exec db pg_dump -U $${POSTGRES_USER:-pentagi} $${POSTGRES_DB:-pentagi} > backups/backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "Database dumped to backups/backup_$$(date +%Y%m%d_%H%M%S).sql"

## db-dump-clean: Remove all local database backups
db-dump-clean:
	@echo "Removing all files in ./backups/ ..."
	@rm -f backups/*.sql
	@echo "Done."

## db-restore: Restore the database from the most recent local backup
# Usage: make db-restore  (restores the latest file in ./backups/)
db-restore:
	@LATEST=$$(ls -t backups/*.sql 2>/dev/null | head -1); \
	if [ -z "$$LATEST" ]; then \
		echo "No backup files found in ./backups/"; exit 1; \
	fi; \
	echo "Restoring from $$LATEST ..."; \
	$(DOCKER_COMPOSE) exec -T db psql -U $${POSTGRES_USER:-pentagi} -d $${POSTGRES_DB:-pentagi} < $$LATEST; \
	echo "Restore complete."

## help: Show this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /' | column -t -s ':'
