# Regtest

Full regtest environment

`make build && make setup`

`make help` for more commands

Runs:

- Ark stack
- Boltz stack
- Nigiri stack
- Nostr relay

Useful aliases:

- ark='docker exec arkd ark'
- arkd='docker exec arkd arkd'
- nla='nigiri lnd addinvoice --amt'
- nlb='nigiri lnd channelbalance | jq -r .balance'
- nlc='nigiri lnd cancelinvoice'
- nlp='nigiri lnd payinvoice --force'
