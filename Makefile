# Capture extra arguments
EXTRA_ARGS := $(filter-out $(firstword $(MAKECMDGOALS)),$(MAKECMDGOALS))

help:
	@echo "Available commands:"
	@echo "  build  - Build the Docker images"
	@echo "  up     - Start the Docker containers in detached mode"
	@echo "  down   - Stop and remove the Docker containers and volumes"
	@echo "  logs   - Follow the logs of the Docker containers"
	@echo "  setup  - Run the setup script"

block:
	nigiri rpc --generate 1

build:
	docker-compose build $(EXTRA_ARGS)

down:
	chmod +x ./setup.sh && ./setup.sh down

generate:
	while true ; do date ; nigiri rpc --generate 1 ; sleep 60 ; done

logs:
	docker-compose logs -f --tail=100 $(EXTRA_ARGS)

setup:
	chmod +x ./setup.sh && ./setup.sh

up:
	chmod +x ./setup.sh && ./setup.sh up
