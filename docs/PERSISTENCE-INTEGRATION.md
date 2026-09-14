# Persistence integration contract

`SAVE_LIFETIME_SCORE` remains `false` until this checklist is implemented and
verified in a separate published development place. When enabled, it means the
entire player profile is persistent, not only the leaderboard score.

## Server lifecycle

1. Generate one server-held lease token for the player session.
2. Claim `Player_<UserId>` through `ProfileStoreService.claim()` before economy
   actions are enabled.
3. Validate and hydrate the profile through `DataService` and
   `PlayerStateService.applyPersistentState()`.
4. Snapshot Score, Coins, Speed, egg inventory, and creatures during staggered
   autosaves. Preserve the loaded `upgrades` object while that gameplay system
   is not yet implemented.
5. Save with the loaded revision and the active lease token. A successful save
   advances the local revision; a stale revision or lost lease immediately
   disables economy mutations for that session.
6. On leave or server close, save first and release the lease only after a
   successful save. A failed save must leave the lease to expire naturally;
   never write a default profile as recovery.

## Failure behavior

- Load/claim failure: show a retry state and reject deposit, hatch, passive
  income, treadmill rewards, and upgrades. Pickup/drop may remain cosmetic,
  but cannot create persistent rewards.
- Corrupt or unsupported data: do not overwrite it. Log the key and retain the
  locked state for support investigation.
- DataStore transport failure: retry outside `UpdateAsync` with the configured
  bounded exponential backoff. The callback itself must never yield.

## Required Studio checks before enabling persistence

- Earn Coins, eggs, speed, creatures; leave and rejoin 20 times.
- Run two servers with the same account: the second session cannot mutate
  economy while the first lease is active.
- Force a failed load/save and confirm no default profile overwrite occurs.
- Verify a stale server save cannot replace a newer revision.
- Use a published development place and isolated development DataStore name;
  never test Studio API access against production data.
