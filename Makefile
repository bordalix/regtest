# Capture extra arguments
EXTRA_ARGS := $(filter-out $(firstword $(MAKECMDGOALS)),$(MAKECMDGOALS))

build:
	docker-compose build $(EXTRA_ARGS)

down:
	docker-compose down -v $(EXTRA_ARGS)

help:
	@echo "Available commands:"
	@echo "  build  - Build the Docker images"
	@echo "  up     - Start the Docker containers in detached mode"
	@echo "  down   - Stop and remove the Docker containers and volumes"
	@echo "  logs   - Follow the logs of the Docker containers"
	@echo "  setup  - Run the setup script"

logs:
	docker-compose logs -f --tail=100 $(EXTRA_ARGS)

setup:
	chmod +x ./setup.sh && ./setup.sh $(EXTRA_ARGS)

up:
	docker-compose up -d $(EXTRA_ARGS)
