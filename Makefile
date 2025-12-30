# Capture extra arguments
EXTRA_ARGS := $(filter-out $(firstword $(MAKECMDGOALS)),$(MAKECMDGOALS))

help:
	@echo "Available commands:"
	@echo "  block  - Generate block"
	@echo "  build  - Build the Docker images"
	@echo "  down   - Stop and clean regtest environment"
	@echo "  logs   - Follow the logs of the Docker containers"
	@echo "  miner  - Continuously mine blocks every 60 seconds"
	@echo "  setup  - Run the setup script and start regtest environment"
	@echo "  up     - Start the regtest environment"

block:
	nigiri rpc --generate 1

build:
	docker-compose build $(EXTRA_ARGS)

down:
	chmod +x ./setup.sh && ./setup.sh down

logs:
	docker-compose logs -f --tail=100 $(EXTRA_ARGS)

miner:
	while true ; do date ; nigiri rpc --generate 1 ; sleep 60 ; done

setup:
	chmod +x ./setup.sh && ./setup.sh

up:
	chmod +x ./setup.sh && ./setup.sh up
