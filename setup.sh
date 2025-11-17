#!/bin/bash
set -Eeuo pipefail

function puts {
  echo
  echo -e "\033[1;35m$1\033[0m"
}

function tick {
  echo " ✔"
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
      tick
      return 0
    else
      echo "Attempt $i/$ATTEMPTS failed, retrying in $INTERVAL second..."
      sleep $INTERVAL
    fi
  done
  
  echo "Timed out waiting for LND after $((ATTEMPTS * INTERVAL)) seconds."
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
      echo $TXID
      tick
      return 0
    else
      echo "Attempt $i/$ATTEMPTS failed, retrying in $INTERVAL second..."
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
  puts "Environment torn down."
  tick
  exit_script
fi

puts "starting nigiri with LND"
nigiri start --ln

puts "waiting for nigiri LND to be ready"
wait_for_cmd "nigiri lnd getinfo"

sleep 2

puts "funding nigiri LND"
nigiri faucet lnd 1

puts "starting boltz LND"
docker compose up -d boltz-lnd
lncli="docker exec -i boltz-lnd lncli --network=regtest"

puts "waiting for boltz LND to be ready"
wait_for_cmd "docker exec boltz-lnd lncli --network=regtest getinfo"

puts "funding boltz LND"
address=$($lncli newaddress p2wkh | jq -r .address)
faucet "$address" 1

puts "connecting lnd instances"
hideOutput=$($lncli connect "$(nigiri lnd getinfo | jq -r .identity_pubkey)"@lnd:9735)
if [ $($lncli listpeers | jq .peers | jq length) -eq 1 ] && [ $(nigiri lnd listpeers | jq .peers | jq length) -eq 1 ]; then
  echo "lnd instances are now connected."
else
  warn "error connecting instances."
  exit 1
fi

puts "opening channel between lnd instances"
# Open a channel with 100k sats
hideOutput=$($lncli openchannel --node_key="$(nigiri lnd getinfo | jq -r .identity_pubkey)" --local_amt=100000)
tick

puts "make the channel mature by mining 10 blocks"
hideOutput=$(nigiri rpc --generate 10)
tick
sleep 5

puts "send 50k sats to the other side to balance the channel"
invoice=$(nigiri lnd addinvoice --amt 50000 | jq -r .payment_request)
$lncli payinvoice --force $invoice

puts "starting arkd"
docker compose up -d arkd
arkd="docker exec arkd arkd"

puts "waiting for arkd to be ready"
wait_for_cmd "docker exec arkd arkd wallet status"

puts "initializing arkd"
initialized=$($arkd wallet status | grep 'initialized')
if [[ ! $initialized =~ "true" ]]; then
  $arkd wallet create --password secret
  sleep 5
else
  echo "arkd already initialized"
fi

puts "unlocking arkd"
$arkd wallet unlock --password secret
sleep 5

puts "fauceting arkd with 5 BTC"
address=$($arkd wallet address)
faucet $address 5

puts "starting fulmine used by boltz"
docker compose up -d boltz-fulmine

sleep 5

puts "generating seed for Fulmine"
seed=$(curl -s -X GET http://localhost:7003/api/v1/wallet/genseed | jq -r .hex)
echo $seed

puts "creating Fulmine wallet with seed"
curl -s -X POST http://localhost:7003/api/v1/wallet/create \
-H "Content-Type: application/json" \
-d '{"private_key": "'"$seed"'", "password": "secret", "server_url": "http://arkd:7070"}' > /dev/null
tick

sleep 5

puts "unlocking Fulmine wallet"
curl -s -X POST http://localhost:7003/api/v1/wallet/unlock \
-H "Content-Type: application/json" \
-d '{"password": "secret"}' > /dev/null
tick

sleep 2

puts "getting Fulmine address"
address=$(curl -s -X GET http://localhost:7003/api/v1/address | jq -r '.address | split("?")[0] | split(":")[1]')
echo $address

puts "fauceting Fulmine address"
hideOutput=$(faucet $address 0.001)
tick

puts "settling funds in Fulmine"
curl -s -X GET http://localhost:7003/api/v1/settle
echo
tick

sleep 5

puts "getting lnd url connect"
lndurl=$(docker exec boltz-lnd bash -c \
  'echo -n "lndconnect://boltz-lnd:10009?cert=$(grep -v CERTIFICATE /root/.lnd/tls.cert \
  | tr -d = | tr "/+" "_-")&macaroon=$(base64 /root/.lnd/data/chain/bitcoin/regtest/admin.macaroon \
| tr -d = | tr "/+" "_-")"' | tr -d '\n')
echo $lndurl
echo $lndurl | { command -v pbcopy >/dev/null && pbcopy; }
tick

puts "final config: MANUAL INTERVENTION REQUIRED"
echo check fulmine on http://localhost:7003
echo - the single transaction should be settled
echo - connect lnd with the URL copied to clipboard
echo - go to settings, lightning tab, paste into URL and connect
echo

# if [ -t 1 ]; then read -n 1 -p "Press any key to continue..."; fi

puts "starting boltz backend and postgres"
docker compose up -d boltz-postgres boltz

puts "starting cors proxy"
docker compose up -d cors

