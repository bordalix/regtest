# Regtest

Full regtest environment for arkade development

`make build && make setup`

`make help` for more commands

### Runs:

- Ark stack
- Boltz stack
- Nigiri stack
- Nostr relay

### Useful aliases:

- ark='docker exec arkd ark'
- arkd='docker exec arkd arkd'
- nf='nigiri faucet'
- nla='nigiri lnd addinvoice --amt'
- nlb='nigiri lnd channelbalance | jq -r .balance'
- nlc='nigiri lnd cancelinvoice'
- nlp='nigiri lnd payinvoice --force'

### Recipes:

Faucet onchain:

```bash
# faucet 21000 sats onchain, returns txid
$ nigiri faucet bcrt1pj4r8az8446tkt75wwdwqgq6ukls7ckyegpcm79yjlh2stk9skcfsmwgwun
0.00021
txId: 0d8e3798f0ea084e3562edecf347b5ece4d3401d871095685ba6404b2de23a57
```

Receive on ark:

```bash
# get receiving addresses
$ docker exec arkd ark receive
{
    "boarding_address": "bcrt1pz7ng322c3j3sc2yx4wy4hdkq8ep420y0sneqr5ewfsce5p3utkyq7kej4c",
    "offchain_address": "tark1qr340xg400jtxat9hdd0ungyu6s05zjtdf85uj9smyzxshf98ndah6630kt3yxw4c6djq2kajzp2nds5pe9taj58yfn4yt8w2qg2pwzcsyth4u",
    "onchain_address": "bcrt1pk35c423n8j46x4vf8n39rn96ga3qj4edupxakjgeah5335xr4qnqqj7h8y"
}
```

Pay from ark:

```bash
# pay 21 sats offchain
$ docker exec arkd ark send -to tark1qr340xg400jtxat9hdd0ungyu6s05zjtdf85uj9smyzxshf98ndah6630kt3yxw4c6djq2kajzp2nds5pe9taj58yfn4yt8w2qg2pwzcsyth4u --amount 21 --password secret
{
     "txid": "5ab42af3c4163362cf34bee11baa51065902f56966e5769c24f4148dd275a344"
}
```

Generate lightning invoice:

```bash
# generate a lightning invoice of 2100 sats
$ nigiri lnd addinvoice --amt 2100
{
    "r_hash": "18db5fb694aca107571e15c64b56764b9aabae51ee4dceaffcb02b1f3e9183e4",
    "payment_request": "lnbcrt21u1p5kyvyvpp5rrd4ld554jssw4c7zhryk4nkfwd2htj3aexuatlukq437053s0jqdqqcqzzsxqyz5vqsp56j7ckf9k7vnm6srq2czn9tectq4yf3arf4d0mlpsjwulhpgz8fzs9qxpqysgqgeeyvmltjpz5g0sll0xp09rvn9zryusstmmfc8mwhqqhxwr3vxwsjt62defda4d6grerr8vf0fg28n3s9jnudr76us2ls8znk0f87lqq25r2r9",
    "add_index": "16",
    "payment_addr": "d4bd8b24b6f327bd4060560532af38582a44c7a34d5afdfc3093b9fb85023a45"
}
```

Pay lightning invoice:

```bash
# pay invoice, returns preimage on success
$ nigiri lnd payinvoice --force lnbcrt21u1p5kyvgkpp5zr3cq2h5046h2rl377mrgad0g7sgudswlgvzgllwku43e2uuf89sdquf35kw6r5de5kueeqf9h8vmmfvdjscqz95xqztfsp56zxcwnr05w2lgl39vnrrqryp6m9gzccasrdyd74t0xkn3hvha30q9qxpqysgq6u904t0g7eydk79hzj4hdk07ekq8fxh9fzvj2d7etlgs4ezks5yymlzkvxldjxlf2cw48uw85q8we865jf4kwxh7ygfw3hzhf3hqdxcpjsf5cy
+------------+--------------+--------------+--------------+-----+----------+-----------------+----------+
| HTLC_STATE | ATTEMPT_TIME | RESOLVE_TIME | RECEIVER_AMT | FEE | TIMELOCK | CHAN_OUT        | ROUTE    |
+------------+--------------+--------------+--------------+-----+----------+-----------------+----
+------------+--------------+--------------+--------------+-----+----------+-----------------+----------+
| HTLC_STATE | ATTEMPT_TIME | RESOLVE_TIME | RECEIVER_AMT | FEE | TIMELOCK | CHAN_OUT        | ROUTE    |
+------------+--------------+--------------+--------------+-----+----------+-----------------+----------+
| SUCCEEDED  |        0.032 |        0.917 | 2100         | 0   |      311 | 125344325632000 | Ark Labs |
+------------+--------------+--------------+--------------+-----+----------+-----------------+----------+
Amount + fee:   2100 + 0 sat
Payment hash:   10e3802af47d75750ff1f7b63475af47a08e360efa18247feeb72b1cab9c49cb
Payment status: SUCCEEDED, preimage: 528782b4439da2c8801df8f7ce4aa11f69d7bbb53321b00ad427c3de8ab69224
```

Cancel lightning invoice to force failed swaps:

```bash
# first create a new invoice
$ nigiri lnd addinvoice --amt 2100
{
    "r_hash": "2c94727d07d1c84771c40eb5ee57987b054408dc352c13dcbdbe03602c4d5d99",
    "payment_request": "lnbcrt21u1p5kyv0upp59j28ylg868yywuwyp667u4uc0vz5gzxux5kp8h9ahcpkqtzdtkvsdqqcqzzsxqyz5vqsp5cjjwl7hj79s9lkykepsy2xe0azc5qujxnyaftaj72zjwa2x3xxcs9qxpqysgq26786l6en7535neeam4284ydq9mj8ssd77veer340kundy55mt6pv3azqrqqm9m9v7y73rxkmvpwcupf8nf2kycjllt63acfzthr2aqpazsetq",
    "add_index": "17",
    "payment_addr": "c4a4effaf2f1605fd896c860451b2fe8b1407246993a95f65e50a4eea8d131b1"
}

# before paying cancel it using the returned r_hash
$ nigiri lnd cancelinvoice 2c94727d07d1c84771c40eb5ee57987b054408dc352c13dcbdbe03602c4d5d99
{}

```
