# Capture extra arguments
EXTRA_ARGS := $(filter-out $(firstword $(MAKECMDGOALS)),$(MAKECMDGOALS))

.PHONY: block build down help invoice logs miner pay payinvoice receive setup up

help:
	@echo "Available commands:"
	@echo "  block                 - Generate block"
	@echo "  build                 - Build the Docker images"
	@echo "  down                  - Stop and clean regtest environment"
	@echo "  help                  - Show this help message"
	@echo "  invoice <sats>        - Create lightning invoice"
	@echo "  logs                  - Follow Docker containers logs"
	@echo "  miner                 - Continuously mine blocks every 60 seconds"
	@echo "  pay <address> <sats>  - Pay to specified address"
	@echo "  payinvoice <invoice>  - Pay a lightning invoice"
	@echo "  receive               - Show ark client receiving addresses"
	@echo "  setup                 - Run the setup script and start regtest environment"
	@echo "  up                    - Start the regtest environment"
	@echo ""
	@echo "  EXTRA_ARGS can be used to pass additional arguments to docker-compose commands."

block:
	nigiri rpc --generate 1

build:
	docker-compose build $(EXTRA_ARGS)

down:
	chmod +x ./setup.sh && ./setup.sh down

invoice:
	nigiri lnd addinvoice --amt $(EXTRA_ARGS)

logs:
	docker-compose logs -f --tail=100 $(EXTRA_ARGS)

miner:
	while true ; do date ; nigiri rpc --generate 1 ; sleep 60 ; done

pay:
	docker exec arkd ark send --to $(word 1,$(EXTRA_ARGS)) --amount $(word 2,$(EXTRA_ARGS)) --password secret

payinvoice:
	nigiri lnd payinvoice --force $(EXTRA_ARGS)

receive:
	docker exec arkd ark receive

setup:
	chmod +x ./setup.sh && ./setup.sh

up:
	chmod +x ./setup.sh && ./setup.sh up

%:
	@:
