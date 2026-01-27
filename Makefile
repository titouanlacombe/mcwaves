# Create .env file if it does not exist
$(shell ./setup_env.sh 1>&2)

PUID=$(shell id -u)
PGID=$(shell id -g)

DATA_DIR=./data
SERVER_DIR=$(DATA_DIR)/app
BACKUPS_DIR=$(DATA_DIR)/backups

include .env
export

APP=app
COMPOSE_EXTRA=$(shell if [ -f docker-compose.extra.yml ]; then echo "-f docker-compose.extra.yml"; fi)
COMPOSE=docker compose -f compose.yml $(COMPOSE_EXTRA)
COMPOSE_UP=$(COMPOSE) up -d --wait

default: up

mkdata:
	@for dir in $(BACKUPS_DIR) $(SERVER_DIR); do \
		mkdir -p $$dir; \
	done

deps: mkdata

up: deps
	@if [ -f $(SERVER_DIR)/modpack.mrpack ]; then \
		echo "Removing old modpack.mrpack"; \
		rm $(SERVER_DIR)/modpack.mrpack; \
	fi

	@echo "Starting server..."
	@$(COMPOSE_UP)
	@echo "Server started on port ${MC_PORT}"

	@$(MAKE) fix_bluemap

fix_bluemap:
	@rm -rf $(SERVER_DIR)/config/bluemap
	@cp -r $(BACKUPS_DIR)/bluemap $(SERVER_DIR)/config/bluemap
	@$(COMPOSE) exec $(APP) rcon-cli /bluemap reload

down:
	@echo "Stopping server..."
	@$(COMPOSE) down

pullup: deps
	@$(COMPOSE_UP) --pull always

recreate: deps
	@$(COMPOSE_UP) --force-recreate

restart:
	@$(COMPOSE) restart $(APP)

logs:
	@$(COMPOSE) logs -f --tail=100 $(APP)

dump_logs:
	@$(COMPOSE) logs $(APP)

config:
	@$(COMPOSE) config

ps:
	@$(COMPOSE) ps

stats:
	@$(COMPOSE) stats

attach:
	@${COMPOSE} exec $(APP) bash

attach-root:
	@${COMPOSE} exec --user root $(APP) bash

rcon:
	@$(COMPOSE) exec $(APP) rcon-cli

tunnel:
	@./tunnel.sh

backup: deps down
	@echo "Backing up data..."
	@BACKUP=$(BACKUPS_DIR)/backup-$(shell date +%Y-%m-%d-%H:%M:%S).tar.zst && \
		tar "-I zstd -3 -T0" -cf $$BACKUP -C $(SERVER_DIR) . && \
		echo "Backup saved to $$BACKUP"

backup_up: backup up

backup_load: deps
	@if [ -z "$(BACKUP)" ]; then \
		echo "Usage: make $@ BACKUP=backup.tar.zst"; \
		exit 1; \
	fi
	@$(MAKE) down
	@echo "Loading backup..."
	@rm -rf $(SERVER_DIR)
	@mkdir -p $(SERVER_DIR)
	@tar -xf $(BACKUP) -C $(SERVER_DIR)

backup_load_up: backup_load up
