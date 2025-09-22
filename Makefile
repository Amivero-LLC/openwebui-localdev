# Helper targets for managing the Open WebUI Docker stack.
include .env
export

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

# Tail logs for all services (pass SERVICE=... to filter via compose CLI).
logs:
	docker compose logs -f

# Show the primary container status and the mapped host URL.
status:
	docker ps --filter "name=$(CONTAINER_NAME)"
	@echo "\nMapped: http://localhost:$(PORT) -> container:8080"

# Drop into an interactive shell inside the app container.
shell:
	-docker exec -it $(CONTAINER_NAME) bash || docker exec -it $(CONTAINER_NAME) sh

# Create a compressed snapshot of the application data volume.
backup:
	@mkdir -p backups
	@TS=$$(date +"%Y%m%d-%H%M%S"); docker run --rm -v $(VOLUME_NAME):/data:ro -v $$PWD/backups:/backups alpine tar czf /backups/open-webui-$$TS.tgz -C /data .; echo "Backup saved to backups/open-webui-$$TS.tgz"

# Restore the data volume from a previously created archive.
restore:
	@[ -n "$(FILE)" ] || (echo "Usage: make restore FILE=backups/open-webui-<ts>.tgz"; exit 1)
	docker run --rm -v $(VOLUME_NAME):/data -v $$PWD:/host alpine sh -c "rm -rf /data/* && tar xzf /host/$(FILE) -C /data"
