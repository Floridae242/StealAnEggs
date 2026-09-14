# StealAnEggs

An original, server-authoritative Roblox/Luau prototype derived from [`deep-research-report.md`](../Downloads/deep-research-report.md) and the progression ideas in [`deep-research-report-2.md`](../Downloads/deep-research-report-2.md). It does not use or connect to another creator's experience, assets, or scripts.

The current visual direction is **Celestial Egg Rush**: an original,
anime-inspired cel-shaded twilight arena. See [`docs/ART-DIRECTION.md`](docs/ART-DIRECTION.md)
for the palette, UI rules, and asset policy.

## Prerequisites

- Roblox Studio
- [Rokit](https://github.com/rojo-rbx/rokit) for the pinned Rojo, StyLua, and Selene toolchain
- Rojo Studio plugin

## Development commands

```bash
rokit install
make verify
make serve
```

See [`docs/STUDIO-WORKFLOW.md`](docs/STUDIO-WORKFLOW.md) for the source-of-truth, live-sync, Studio test, and DataStore safety workflow.

## Studio map setup

The version-controlled graybox map lives in `map/World.project.json` and builds as `Workspace.GameMap`. It contains eight player bases, six egg spawn points, eight deposit zones, four treadmills, a central arena, cover, and boundary walls.

1. Run `make verify` to produce `build/StealAnEggs.rbxlx`.
2. Open that place in Roblox Studio, or run `make serve` and connect the Rojo Studio plugin.
3. Run `MapContractSpec` in TestService before gameplay testing.
4. Test via **Test → Server & Clients** with two players. Train on a treadmill, pick up an egg with its prompt, steal it with the second player, drop with `Q`, then take it into a deposit zone. The secured egg appears as a hatch button; hatching creates a server-recorded entry in `PetInventory`.

## Creature progression and events

Hatched original creatures (`Chick`, `Bunny`, `Bluebird`, `Fox`, and `Phoenix`) generate passive Coins while the player is online. The server runs a `Lumina Surge` at the interval set in `Config.luau`; eligible creatures may receive a session-only `Lumina` mutation, which doubles their passive output. Event state, mutation chance, earnings, and creature definitions are always calculated on the server. The client only displays the current event and inventory result.

## Trust boundary

`EggClient` sends only `RequestDrop:FireServer()` and a validated rarity intent for `RequestHatch`. It never sends an egg ID, score, player, reward, pet result, or location. `EggServer` owns all authoritative state, rechecks live distance for prompts, verifies the character is truly inside a zone after `Touched`, chooses egg/pet rarity, checks treadmill occupancy from the server, and rate-limits actions.

## Persistence

Scores are session-only until `SAVE_LIFETIME_SCORE` is set to `true` in `Config.luau`. Enable Studio API access only on a non-production test place. The current persistence implementation saves score deltas; Coins, egg inventory, and pets are intentionally session-only in this prototype and must not be marketed as permanent until a versioned player-data save is added.

## Key files

- `src/ReplicatedStorage/StealAnEggs/Config.luau` — balancing values.
- `src/ReplicatedStorage/StealAnEggs/EggCatalog.luau` — public display-safe rarity and pet definitions.
- `src/ReplicatedStorage/StealAnEggs/CreatureCatalog.luau` — original creature income and mutation multipliers.
- `src/ServerScriptService/EggServer.server.luau` — gameplay and persistence bootstrap.
- `src/ServerScriptService/Services/RemoteRegistry.luau` — server-only RemoteEvent registry that rejects conflicting classes.
- `src/ServerScriptService/Services/PlayerStateService.luau` — creates per-player session containers once.
- `src/StarterPlayer/StarterPlayerScripts/EggClient.client.luau` — UI and Q/drop input only.
- `tests/EggCatalog.spec.server.luau` — Studio TestService contract test.
- `tests/MapContract.spec.server.luau` — validates the version-controlled map contract.
- `tests/RemoteRegistry.spec.server.luau` — validates remote reuse and fail-closed class checks.
- `tests/PlayerStateService.spec.server.luau` — validates session container initialization and duplicate rejection.
- `map/World.project.json` — original graybox world source.
