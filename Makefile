build:
	docker-compose build

down:
	docker-compose down -v

help:
	@echo "Available commands:"
	@echo "  build  - Build the Docker images"
	@echo "  up     - Start the Docker containers in detached mode"
	@echo "  down   - Stop and remove the Docker containers and volumes"
	@echo "  logs   - Follow the logs of the Docker containers"
	@echo "  setup  - Run the setup script"

logs:
	docker-compose logs -f --tail=100

setup:
	chmod +x ./setup.sh && ./setup.sh

up:
	docker-compose up -d
