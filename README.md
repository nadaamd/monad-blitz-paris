# HeatBoard

**A leaderboard where support cools down.**

Submission for [Monad Blitz Paris](https://monad-foundation.notion.site/Monad-Blitz-Paris-2736367594f2836989b9010568428050) — 19 September, Paris.

## The idea

On-chain voting is a ratchet. A vote cast once counts forever, so leaderboards measure
*history*, not *attention*. Whoever got hot first stays on top.

HeatBoard replaces votes with **heat**. Each cheer adds `1.0` heat to an entry, and that
heat decays linearly back to zero over one hour. Nothing is permanent: an entry only stays
at the top of the board while people are actively cheering for it. Stop, and it cools.

That turns a leaderboard into a live signal — "what does the room care about *right now*"
rather than "what did the room care about at some point today".

## Why this needs Monad

The mechanic only works if cheering is something you do repeatedly and casually, several
times a minute across a whole room. That means a transaction has to be cheap enough to be
worthless and fast enough to feel like a click, not a payment. On a chain where a cheer
costs real money or takes twelve seconds to confirm, nobody cheers twice and the decay
just erases the board.

Decay itself is also free here: nothing is written on a timer. Heat is stored as a
`(value, timestamp)` snapshot and the current value is computed at read time, so an entry
cools down with zero transactions.

## Live on Monad Testnet

| | |
|---|---|
| Contract | [`0x79198170A856B43A564344536Fa68e1602946DC3`](https://testnet.monadexplorer.com/address/0x79198170A856B43A564344536Fa68e1602946DC3) |
| Chain | Monad Testnet (10143) |

## Contract

`src/HeatBoard.sol` — no owner, no token, no upgradeability.

| | |
|---|---|
| `createEntry(string name)` | register an entry, returns its id |
| `cheer(uint256 id)` | add `CHEER_HEAT` (1e18) to an entry |
| `heatOf(uint256 id)` | current heat, decay applied as of `block.timestamp` |
| `board()` | whole leaderboard in one call — names, live heat, lifetime cheers, creators |
| `cooldownLeft(id, fan)` | seconds before that address may cheer that entry again |

Constants: `DECAY_WINDOW = 1 hours`, `COOLDOWN = 30 seconds` per address per entry.

## Run it

```bash
git submodule update --init --recursive   # forge-std
forge test                               # 7 tests
```

Deploy to Monad Testnet (chain id 10143, faucet: https://faucet.monad.xyz):

```bash
cp .env.example .env        # put a funded test-wallet key in it
source .env
forge script script/Deploy.s.sol --rpc-url $MONAD_RPC --private-key $PRIVATE_KEY --broadcast
```

`web/index.html` already points at the deployed address above. Serve the page:

```bash
python3 -m http.server 8000 --directory web
# http://localhost:8000
```

The page reads the board from the public RPC every 8 seconds and interpolates the decay
locally every 200 ms, so the bars visibly cool between reads.

## Status

Built in one day at Monad Blitz. It is a prototype of one mechanic, not a product:
there is no sybil resistance beyond the per-address cooldown, and the decay curve is
linear because that is the cheapest honest thing to compute on-chain.
