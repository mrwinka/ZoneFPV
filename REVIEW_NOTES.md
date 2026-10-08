# ZoneFPV v58 — review notes

The public prerelease includes cumulative 0.3.0 features; the latest v58 runtime delta is confined to three Lua paths:

- `mod/Scripts/world_experiments.lua`: retain bounded deferred discovery for still-living NPCs after the first fast readiness window. Retry once per second; preserve identity/world checks, shared native-read/time budgets and the queued-reference cap.
- `mod/Scripts/player_visibility.lua`: validate every captured equipment attachment ancestor before visibility/restoration writes. Retire transferred/reused ancestors and descendants for the flight, preventing stale baseline restoration onto another owner. Genuine unchanged detached equipment still restores.
- `mod/Scripts/main.lua`: identify v58 in the FPV entry log. The v57 movement-tick preservation remains.

Before the late-readiness correction, an existing actor whose mesh loaded after approximately three seconds could disappear from discovery permanently while construction notifications were working. The offline regression reproduces this without a new construction event. The v58 end-to-end fixture retains the same actor through model readiness at 5/10 seconds and subsequent publication.

Before the attachment correction, an intermediate item could transfer to an NPC while a child still appeared connected to the player. The old path rejected the intermediate capture but permitted child visibility writes. v58 checks and captures the complete bounded chain, validates cached paths before new discovery, and blocks descendants after ancestor ownership/identity changes.

Fresh v58 validation: **66 Lua suites passed**, **139 Lua files parsed**, **23 equipment visibility scenarios passed**. Crowd/projection/protocol tests retain bounded processing and current-frame output. Historical native/helper evidence is reused without pretending a new C++ build occurred.

Reused binaries:

| Artifact | Revision | SHA-256 |
|---|---|---|
| `ZoneFPVInput.exe` | v55 | `06E5B2512A28F4D1440DEBF9C83CD589979BD84ABF1C7A9D75E939A8B178307C` |
| `ZoneFPVNative.dll` | v51 | `F472AD6DA5C768DF01E54A40539DD83A526C75E1C1C07D99E423956D84C334C5` |

**`gameplay_verified=false`.** These regressions demonstrate two concrete faults and their offline corrections. They do not establish the source of every NPC model disappearing in the user’s live session, prove recovery after that disappearance, or quantify game performance. Live NPC preservation/scanning remains to be checked.

The public package excludes private preferences, logs, research, backup installations and internal build artifacts. It keeps its own runtime, installer, source and applicable licenses. A game-compatible UE4SS runtime remains an external dependency.
