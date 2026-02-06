#!/bin/bash
set -Eeuo pipefail

function puts {
  echo
  echo -e "\033[1;35m$1\033[0m"
}

# print tick and than all arguments
function tick {
  GREEN='\033[32m'
  NC='\033[0m' # No Color / reset
  echo -e " ${GREEN}✔${NC} $*"
}

function warn {
  echo
  echo -e "\033[1;31m$1\033[0m"
}

function wait_for_cmd {
  local COMMAND="$1"
  local ATTEMPTS=10  # Total number of attempts
  local INTERVAL=1  # Seconds between retries
  
  for ((i=1; i<=ATTEMPTS; i++)); do
    RETURN_CODE=$($COMMAND > /dev/null 2>&1; echo $?)
    if [ "$RETURN_CODE" -eq 0 ]; then
      return 0
    else
      echo " Attempt $i/$ATTEMPTS failed, retrying in $INTERVAL second..."
      sleep $INTERVAL
    fi
  done
  
  echo " ❌ Timed out waiting for LND after $((ATTEMPTS * INTERVAL)) seconds."
  return 1
}

function faucet {
  local ADDRESS="$1"
  local AMOUNT="$2"
  local ATTEMPTS=10  # Total number of attempts
  local INTERVAL=1  # Seconds between retries
  
  INITIAL_COUNT=$(curl -s http://localhost:3000/address/$ADDRESS | jq .chain_stats.tx_count)
  
  TXID=$(nigiri faucet $ADDRESS $AMOUNT)
  
  for ((i=1; i<=ATTEMPTS; i++)); do
    NEW_COUNT=$(curl -s http://localhost:3000/address/$ADDRESS | jq .chain_stats.tx_count)
    if [ "$NEW_COUNT" -gt "$INITIAL_COUNT" ]; then
      tick "fauceted with $TXID"
      return 0
    else
      echo " Attempt $i/$ATTEMPTS failed, retrying in $INTERVAL second..."
      sleep $INTERVAL
    fi
  done
}

function exit_script {
  duration=$SECONDS
  echo "Script took $duration seconds to run."
  exit
}

ACTION="setup"
SECONDS=0

for arg in "$@"; do
  if [[ "$arg" == "up" ]]; then
    ACTION="up"
    elif [[ "$arg" == "down" ]]; then
    ACTION="down"
  fi
done

# if argument 'up' is provided, don't do cleanup
if [ ! $ACTION == "up" ]; then
  puts "dropping existing docker containers and volumes"
  docker compose down -v
  
  puts "stopping nigiri"
  nigiri stop --delete
fi

# if argument 'down' is provided, exit after cleanup
if [ $ACTION == "down" ]; then
  tick "Environment torn down."
  exit_script
fi

puts "starting nigiri with LND"
nigiri start --ln

puts "waiting for nigiri LND to be ready"
wait_for_cmd "nigiri lnd getinfo"
tick "nigiri LND is ready"

sleep 2

puts "funding nigiri LND"
TXID=$(nigiri faucet lnd 1)
tick $TXID

puts "starting boltz LND"
docker compose up -d boltz-lnd
lncli="docker exec -i boltz-lnd lncli --network=regtest"

puts "waiting for boltz LND to be ready"
wait_for_cmd "docker exec boltz-lnd lncli --network=regtest getinfo"
tick "boltz LND is ready"

puts "funding boltz LND"
address=$($lncli newaddress p2wkh | jq -r .address)
faucet "$address" 1

puts "connecting lnd instances"
hideOutput=$($lncli connect "$(nigiri lnd getinfo | jq -r .identity_pubkey)"@lnd:9735)
if [ $($lncli listpeers | jq .peers | jq length) -eq 1 ] && [ $(nigiri lnd listpeers | jq .peers | jq length) -eq 1 ]; then
  tick "lnd instances are now connected."
else
  warn "error connecting instances."
  exit 1
fi

puts "opening channel between lnd instances"
# Open a channel with 100k sats
hideOutput=$($lncli openchannel --node_key="$(nigiri lnd getinfo | jq -r .identity_pubkey)" --local_amt=100000)
tick "channel open."

puts "make the channel mature by mining 10 blocks"
hideOutput=$(nigiri rpc --generate 10)
tick "channel is now mature."
sleep 5

puts "send 50k sats to the other side to balance the channel"
invoice=$(nigiri lnd addinvoice --amt 50000 | jq -r .payment_request)
$lncli payinvoice --force $invoice

puts "starting arkd"
docker compose up -d arkd
arkd="docker exec arkd arkd"
ark="docker exec arkd ark"

puts "waiting for arkd to be ready"
wait_for_cmd "docker exec arkd arkd wallet status"
tick "arkd is ready"

puts "initializing arkd"
initialized=$($arkd wallet status | grep 'initialized')
if [[ ! $initialized =~ "true" ]]; then
  SEED=$($arkd wallet create --password secret)
  tick "arkd initialized with seed: $SEED"
  sleep 5
else
  tick "arkd already initialized"
fi

puts "unlocking arkd"
OUTPUT=$($arkd wallet unlock --password secret)
tick "arkd unlocked"
sleep 1

puts "fauceting arkd with 21 BTC"
address=$($arkd wallet address)
for i in {1..21}; do
  nigiri faucet "$address" 1
done

puts "Initialize ark client"
$ark init --server-url http://localhost:7070 --explorer http://chopsticks:3000 --password secret
tick "ark client initialized"

puts "fund the ark-cli with 1 vtxo worth of 2_000_000"
note=$($arkd note --amount 2000000)
txid=$($ark redeem-notes -n $note --password secret | jq -r .txid)
tick "ark client funded with txid: $txid"

puts "starting fulmine used by boltz"
docker compose up -d boltz-fulmine

sleep 5

puts "generating seed for Fulmine"
seed=$(curl -s -X GET http://localhost:7003/api/v1/wallet/genseed | jq -r .hex)
tick "seed: $seed"

puts "creating Fulmine wallet with seed"
curl -s -X POST http://localhost:7003/api/v1/wallet/create \
-H "Content-Type: application/json" \
-d '{"private_key": "'"$seed"'", "password": "secret", "server_url": "http://arkd:7070"}' > /dev/null
tick "wallet created"

sleep 5

puts "unlocking Fulmine wallet"
curl -s -X POST http://localhost:7003/api/v1/wallet/unlock \
-H "Content-Type: application/json" \
-d '{"password": "secret"}' > /dev/null
tick "wallet unlocked"

sleep 2

puts "getting Fulmine address"
address=$(curl -s -X GET http://localhost:7003/api/v1/address | jq -r '.address | split("?")[0] | split(":")[1]')
tick "address: $address"

puts "fauceting Fulmine address"
faucet $address 0.001

puts "settling funds in Fulmine"
txid=$(curl -s -X GET http://localhost:7003/api/v1/settle | jq -r .txid)
tick "funds settled with txid: $txid"
sleep 5

puts "getting lnd url connect"
lndurl=$(docker exec boltz-lnd bash -c \
  'echo -n "lndconnect://boltz-lnd:10009?cert=$(grep -v CERTIFICATE /root/.lnd/tls.cert \
  | tr -d = | tr "/+" "_-")&macaroon=$(base64 /root/.lnd/data/chain/bitcoin/regtest/admin.macaroon \
| tr -d = | tr "/+" "_-")"' | tr -d '\n')
tick "lnd url: $lndurl"

puts "final config: MANUAL INTERVENTION REQUIRED"
echo check fulmine on http://localhost:7003
echo - the single transaction should be settled
echo - connect lnd with the URL copied to clipboard
echo - go to settings, lightning tab, paste into URL and connect
echo

# if [ -t 1 ]; then read -n 1 -p "Press any key to continue..."; fi

puts "starting boltz backend and postgres"
docker compose up -d boltz-postgres boltz

puts "starting cors proxy on localhost:9069"
docker compose up -d cors

puts "starting nostr relay on ws://localhost:10547"
docker compose up -d nak