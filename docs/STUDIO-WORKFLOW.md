# Studio and Rojo Workflow

## Source of truth

- Luau source lives in `src/` and `tests/`.
- The graybox map source lives at `map/World.project.json` and mounts as `Workspace.GameMap`.
- Generated `.rbxl` and `.rbxlx` files belong in `build/` and must not be committed.
- Do not edit Rojo-owned scripts in Studio because the next sync can replace those edits.

## Install the pinned tools

The project pins Rojo, StyLua, and Selene in `rokit.toml`. Install Rokit first, then run:

```bash
rokit install
```

The selected versions are:

- Rojo 7.7.0
- StyLua 2.5.2
- Selene 0.31.0

## Build and validate

```bash
make verify
```

This checks formatting, lints Luau, builds `build/StealAnEggs.rbxlx`, and checks whitespace errors. The map contract is now included, but clean gameplay startup and geometry remain Studio-only gates.

## Live sync

1. Run `make serve`.
2. Open the development place in Roblox Studio.
3. Connect the Rojo Studio plugin to the local server.
4. Confirm the target place before accepting a sync.
5. Stop playtesting before applying structural map changes.

Once the private development place exists, add its place ID to `servePlaceIds` in `default.project.json`. This prevents accidental live sync into a different experience.

## Studio-only tests

After `make build`:

1. Open `build/StealAnEggs.rbxlx` in Studio.
2. Confirm `MapContractSpec`, `EggCatalogSpec`, and `CreatureCatalogSpec` exist under `TestService`.
3. Press **Test → Run**. The project sets `TestService.AutoRuns` and `ExecuteWithStudioRun` to run the mapped specs.
4. Inspect Output for all three `passed` messages and no assertion failures.
5. The M1 map is now included; verify that gameplay starts without missing-map warnings or errors.

For multiplayer verification, use **Test → Server & Clients**. Start with two clients for pickup/steal behavior and increase to eight for the production soak gate.

## DataStore safety

Use a separate published development place and development DataStore namespace. Never enable Studio API access against the production experience. Persistence remains disabled until the versioned profile work in M3 is complete.
