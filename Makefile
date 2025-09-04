include .env
export

up:
	docker compose up -d
	@echo "Open WebUI -> http://localhost:$(PORT)"

down:
	docker compose down

restart:
	docker compose restart

update:
	docker compose pull
	docker compose up -d
	-docker image prune -f >/dev/null

logs:
	docker compose logs -f

status:
	docker ps --filter "name=$(CONTAINER_NAME)"
	@echo "\nMapped: http://localhost:$(PORT) -> container:8080"

shell:
	-docker exec -it $(CONTAINER_NAME) bash || docker exec -it $(CONTAINER_NAME) sh

backup:
	@mkdir -p backups
	@TS=$$(date +"%Y%m%d-%H%M%S"); docker run --rm -v $(VOLUME_NAME):/data:ro -v $$PWD/backups:/backups alpine tar czf /backups/open-webui-$$TS.tgz -C /data .; echo "Backup saved to backups/open-webui-$$TS.tgz"

restore:
	@[ -n "$(FILE)" ] || (echo "Usage: make restore FILE=backups/open-webui-<ts>.tgz"; exit 1)
	docker run --rm -v $(VOLUME_NAME):/data -v $$PWD:/host alpine sh -c "rm -rf /data/* && tar xzf /host/$(FILE) -C /data"
