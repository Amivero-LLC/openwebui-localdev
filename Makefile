# Helper targets for managing the Open WebUI Docker stack.
include .env
export

PROJECT_NAME ?= $(COMPOSE_PROJECT_NAME)
PROJECT_NAME ?= $(DEPLOYMENT_NAME)
PROJECT_NAME ?= $(notdir $(CURDIR))
DATA_ROOT ?= ./data/$(PROJECT_NAME)
OPENWEBUI_DATA_DIR ?= $(DATA_ROOT)/open-webui

# Start all services in the background and print the UI endpoint.
up:
	docker compose up -d
	@echo "Open WebUI -> http://localhost:$(PORT)"

# Stop and remove the compose stack without touching volumes.
down:
	docker compose down

# Restart running containers in place.
restart:
	docker compose restart

# Pull the latest images, redeploy, and prune dangling ones quietly.
update:
	docker compose pull
	docker compose up -d
	-docker image prune -f >/dev/null

# Rebuild all container images without using cache.
build:
	docker compose build --no-cache

# Tear everything down, remove volumes, rebuild images, and start fresh.
rebuild:
	docker compose down -v --remove-orphans
	docker compose build --no-cache
	docker compose up -d
	@echo "Stack rebuilt from scratch -> http://localhost:$(PORT)"

# Tail logs for all services (pass SERVICE=... to filter via compose CLI).
logs:
	docker compose logs -f

# Show the primary container status and the mapped host URL.
status:
	docker compose ps open-webui
	@echo "\nMapped: http://localhost:$(PORT) -> container:8080"

# Drop into an interactive shell inside the app container.
shell:
	docker compose exec open-webui bash || docker compose exec open-webui sh

# Create a compressed snapshot of the application data directory.
backup:
	@[ -d "$(OPENWEBUI_DATA_DIR)" ] || (echo "OPENWEBUI_DATA_DIR '$(OPENWEBUI_DATA_DIR)' does not exist; start the stack once to create it or set a custom path." && exit 1)
	@mkdir -p backups
	@TS=$$(date +"%Y%m%d-%H%M%S"); tar czf backups/open-webui-$$TS.tgz -C "$(OPENWEBUI_DATA_DIR)" .; echo "Backup saved to backups/open-webui-$$TS.tgz"

# Restore the data directory from a previously created archive.
restore:
	@[ -n "$(FILE)" ] || (echo "Usage: make restore FILE=backups/open-webui-<ts>.tgz"; exit 1)
	@mkdir -p "$(OPENWEBUI_DATA_DIR)"
	tar xzf "$(FILE)" -C "$(OPENWEBUI_DATA_DIR)"
