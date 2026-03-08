
ifneq ($(shell which docker-compose 2>/dev/null),)
    DOCKER_COMPOSE := docker-compose
else
    DOCKER_COMPOSE := docker compose
endif

backup-openwebui:
	chmod +x scripts/ops/backup-openwebui.sh
	@./scripts/ops/backup-openwebui.sh

install:
	$(DOCKER_COMPOSE) up -d

remove:
	@chmod +x confirm_remove.sh
	@./confirm_remove.sh

start:
	$(DOCKER_COMPOSE) start
startAndBuild: 
	$(DOCKER_COMPOSE) up -d --build

stop:
	$(DOCKER_COMPOSE) stop

update-ollama-models:
	chmod +x update_ollama_models.sh
	@./update_ollama_models.sh

update:
	chmod +x scripts/ops/update-openwebui.sh
	@./scripts/ops/update-openwebui.sh

update-gpu:
	chmod +x scripts/ops/update-openwebui.sh
	@./scripts/ops/update-openwebui.sh --gpu
