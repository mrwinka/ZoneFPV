## 0.3.0 RC1 — 2026-10-08

- Retain bounded deferred discovery for still-live NPCs whose meshes load after the initial retry window; preserve native-read and discovery budgets.
- Require unchanged identity and ownership throughout a captured equipment attachment chain before any visibility or restoration write.
- Add regression coverage for late mesh readiness and transferred intermediate equipment. No live gameplay correction is claimed; see RELEASE_STATUS.md.

## RC1 debug v57 — 2026-10-08

- Retain the player's original CharacterMovement tick state during FPV; keep MOVE_None, zero velocity and input suppression.
- Hide player equipment only while each component or attached actor still belongs to the current player; discard transferred snapshots and restore unchanged detached equipment.
- Add bounded read-only player/anchor and NPC residency diagnostics. No forced NPC visibility or guessed native position writes.
- Reuse helper55/native51 and frozen v56 input fixtures. The A-Life synchronization hypothesis and live gameplay correction remain unverified. See DEBUG_V57_REPORT_RU.md.

## RC1 debug v56 — 2026-10-08

- Apply the16-target overlay/metadata cap after visibility; use a bounded128-candidate pool so closer offscreen NPCs do not displace visible targets.
- Use fresh physical bounds for unavailable skeletal poses, including actual owned capsule geometry when collision is disabled.
- Cover simultaneous crowd tracking over612 frames at60/144Hz, lifecycle rejection and the retained projection/native-work bounds.
- Reuse unchanged helper55/native51, verify current Lua packets with compiled readers and preserve current preferences. See DEBUG_V56_REPORT_RU.md.

## RC1 debug v55 — 2026-10-08

- Show all14 OSD indicators in a vertical scrollable PDA selector; synchronize list, preview and inspector, and label the display toggle «Отображать».
- Correct loaded NPC mesh compatibility with UE4SS missing-field sentinels and use live collider bounds for degenerate skeletal poses.
- Add an actual discovery-to-publisher runtime-contract regression; retain invalid-target and stale-frame filtering.
- Rebuild helper55 and preserve native51/current preferences. See DEBUG_V55_REPORT_RU.md.

## RC1 debug v54 — 2026-10-08

- Remove per-call Lua argument tables/closures in14 protected engine wrappers; retain nil arguments, return shapes and failure isolation.
- Skip hidden PDA OSD geometry/rendering and duplicate snapshot preview generation; avoid idle controller reads while external F6 is closed.
- Remove unused legacy external PDA tool IPC polling. Respect explicit CLI device selection without recurring WinMM discovery.
- Rebuild helper54, preserve native51 and current settings; retain current-frame scanner behavior. See DEBUG_V54_REPORT_RU.md.

## RC1 debug v52 — 2026-10-08

- Align OSD preview drawing, selection and dragging with the actual local widget dimensions. Measure owned text widgets so the mouse region covers the rendered label.
- Fix the live v51 small-label selection mismatch; keep removed PDA X/Y rows, compact choice arrows and1–20→Unlimited grenade capacity in both menus.
- Reuse the tested native51/input51 binaries unchanged. Preserve installed preferences. See DEBUG_V52_REPORT_RU.md for tests and manual validation status.

## RC1 debug v51 — 2026-10-08

Keep opaque FGeometry inside a guarded native scalar query to fix the v50 drag failure observed in the game's log. Remove PDA X/Y inspector rows; retain click selection, local drag draft and one save on release. Place choice arrows directly beside the value. In both menus, expose1–20 grenade charges followed by Unlimited at slider21 while preserving storage0 and existing settings. Rebuild helper/native51 and preserve the armament PAK/runtime. Fresh63 Lua,6 helper C++ and2 native fixture programs pass; actual new in-game dragging remains to be verified. See DEBUG_V51_REPORT_RU.md.

## RC1 debug v50 — 2026-10-08

Add click selection, highlighting and drag placement of OSD preview items inside the PDA; save once on release and cancel unfinished movement on focus/section changes. Replace pagination with native vertical scrolling and reduce label/value gaps. Restore Equipment naming in both menus; remove FPV/return/binocular/artifact action rows and Theme, preserving bindings. Show combat parameters only for the selected drone type. Persist flashlight/lower-camera input permissions independently of active feature state. Rebuild the input helper for controller selection, bounded owner-read recovery and specific failure causes. Share v7 OSD preferences; preserve current settings and unchanged native v46/armament PAK. See DEBUG_V50_REPORT_RU.md for validation scope.

## RC1 debug v49 — 2026-10-08

Embed all remaining PDA tools instead of opening the external menu: controller/profile, live four-axis calibration, eight arbitrary button/CH assignments, General language/theme/audio/object limit and full OSD configuration/preview. Add bounded eight-row internal pagination and a numeric object-limit editor. A fresh owned headless bridge reuses helper hardware/settings algorithms and cancels unfinished tools on section/focus/owner changes. Share the existing v7 OSD layout, preserve migrations/precision and retain the last valid layout during replacement. F6 remains independently usable. See DEBUG_V49_REPORT_RU.md; live v49 gameplay is pending.

## RC1 debug v48 — 2026-10-08

Move Controller into Settings and rename Equipment to Armament in both menus, retaining five groups and eleven internal sections. Add Drop + kamikaze with independent grenade stock and impact charge, existing impact threshold and OSD count. Preserve established camera/CH holds through bounded input delays without integrating stale sticks or producing new delayed actions; actual release and focus/disconnect guards remain active. Production helper rebuilt; unchanged native v46 DLL and armament PAK reused. All 59 Lua suites and five C++ fixture programs pass. See DEBUG_V48_REPORT_RU.md; live v48 gameplay remains pending.

## RC1 debug v47 — 2026-10-07

Fix the logged grenade-drone entry failure caused by UE4SS rejecting engine access from unregistered Lua coroutines. Use explicit preparation phases on the registered game-thread callback. Correct swept-hit classification for packed out-struct bool aliasing while retaining initial-overlap and low-speed landing safety. Reorganize both menus into five groups/eleven sections, with eight inline binding modes in Settings → Buttons. Hold is available for every action, including repeated grenade release/artifact attempts. Start selected vision automatically when unbound; independently enable the lower-camera crosshair. Input helper rebuilt; native v46 DLL and PAK reused. See DEBUG_V47_REPORT_RU.md.

## RC1 debug v46 — 2026-10-07

Prepare grenade bodies before release and replenish the pool in bounded game-thread phases. Pause briefly on axis-only stalls with a fresh independent helper heartbeat; never integrate stale sticks. Add configurable closing-impact threshold for kamikaze, ten-section menus with eight bindings, toggle/hold modes for downward camera/selected vision/flashlight, and six crosshair styles per camera with automatic downward horizon hiding. Fix owned native-detour profile rejection and suppress exact explosion dirt passes during five-second recovery. Input/native helpers rebuilt; armament PAK retained. See DEBUG_V46_REPORT_RU.md for evidence and live-game limits.

## RC1 debug v40 — 2026-10-07

Require a current-game helper, advancing input packets and a possessed character before external F6 can acquire input locks. Restore focus/cursor to an open F6/OSD editor after clicking the verified game viewport. Replace the unavailable SpotLight actor with a camera-owned, registered SpotLightComponent. Preserve assignments, native input locks and v39 sensor/artifact features. See DEBUG_V40_REPORT_RU.md for evidence and gameplay validation limits.

## RC1 debug v39 — 2026-10-07

Restore analog camera parameters on disable across sensor mode changes. Add an assignable, camera-attached drone flashlight and adjustable artifact collection distance in both menus. F6 acquires cursor/focus immediately and owns separate input locks while visible, including no USB and failed foreground transfer. Retain legacy preferences, safe native key registration and DirectInput/XInput hotplug discovery. See DEBUG_V39_REPORT_RU.md.

## RC1 debug v11 — 2026-10-05

Artifact player UID address derived from the exact supported EXE; multi-part thermal targets and 16 camera modes; scoped native Geiger/radiation suppression; separate noclip; native PDA panel; independent anomaly noise selection; teleport handoff; memory-pressure streaming fallback and bounded aggression history. See DEBUG_V11_REPORT_RU.md for findings, limits and game-test checklist. EngineTick-only dispatch retained.
# 0.3.0 RC1 debug v10 — 2026-10-05

- The new dump identifies the Lua scheduler running on Foreground Worker via ProcessEvent. Require EngineTick explicitly; enable Tick and disable the unsafe ProcessEvent action/notification pump, backing up runtime settings with transactional rollback.
- Remove all runtime LUT hooks and use completed Canvas out parameters with same-update Begin/End; preserve bounded palette generation and failures.
- Log material registry/thread errors and use synchronous engine soft-path loading for cooked registry misses.
- Add scheduler, asset-loader and runtime-settings/rollback regressions. Gameplay validation remains pending.

# 0.3.0 RC1 debug v9 — 2026-10-05

- Fix artifact/AI profile validation after the combat detour; retain independent exact function/vtable guards and profile diagnostics.
- Remove repeated missing-template particle lookups identified in actual timing; retain weather/leaf handoffs and export separate stage metrics.
- Add camera night/infrared and six thermal palettes with occluded NPC/mutant skeletal silhouettes, bounded work and material restoration.
- Add sixth experimental page, separate persisted mode, five-language labels and lifecycle/UI regression coverage.
- Unpublished debug build; v9 gameplay validation remains pending.

# 0.3.0 RC1 debug v8 — 2026-10-05

- Replace the concurrent Lua worker with one recurring game-thread callback; bounded input read failures retain the existing 250 ms safety lease.
- Connect the original artifact interaction and native immediate inventory path; validate original identities/container and report concrete menu errors instead of a generic load-save prompt.
- Pause/resume only the player's Geiger Wwise event during FPV.
- Intercept cached-index concussion/blinking scalar writes that bypass the original FName setter; preserve unrelated materials/parameters.
- Park the protected receiving pawn before cleaning drone-acquired AI targets and before restoring the body. Preserve pre-existing targets and faction relationships.
- Unpublished debug build. v8 gameplay validation remains pending.

# 0.3.0 RC1 debug v7 — 2026-10-05

- Intercept the actual native ActorCore receive routine; use real attack payloads for drone HP and cancel player-body side effects. Verify executable bytes, receiver UObject/core/UID identity and expiring leases.
- Suppress exact concussion/blinking MID scalar writes before the native setter, including direct C++ game calls. Disarm before restoring captured state.
- Remove recurring missing-UFunction/UMG searches. Use spatial nearby queries, bounded discovery/refresh, prioritized streamed-anomaly readiness retries and per-stage performance diagnostics.
- Check anomaly damage against the complete movement segment every frame; refresh nearby movers and marker selection during fast flight.
- Use actual native binocular faction ancestry and per-target relationships, original extracted binocular icons, red/white/green frames and short rounded corners. Unknown metadata remains explicit.
- Replace live loading-grid ForEach with bounded indexed reads; keep rendering settings and values.
- Build the new native DLL and helper; validate 30 Lua suites, five native UI/input tests, a real MinHook fixture and installer preservation/rollback. Gameplay validation remains pending. Unpublished experiment.

# 0.3.0 RC1 debug v6 — 2026-10-04

- Fix immediate DRONE DESTROYED on entry: remove v5 synthetic maxHP/HP writes and health-loss damage inference. The native effective-stat tick can reset the reserve without any attack.
- Remove physics OnHit timestamps as enemy attack evidence. Keep the player body shielded, preserve fractional/unowned health changes, and stop queuing/counting drone hits after destruction.
- Defer God-setting edits while the receiving proxy owns the body; apply the current choice after teardown. Restore time dilation in the owned world and isolate expired-controller/world-accessor errors from other teardown steps.
- Retry initializing HUD widgets and exact effect MIDs within fixed budgets; safely handle stale UI validity and avoid registering hooks for absent live UFunctions.
- Reject trailing telemetry tokens without replacing the last valid frame.
- Recheck scanner/world/particle guards and native helper ownership. All 29 Lua suites (30 lifecycle cases, 27 combat checks), five fresh native test programs and installer preservation/rollback fixtures pass. Reproduce v5 entry destruction and verify v6 survives the same stat-update model.
- Actual NPC/mutant damage routing, faction icons/relationships, artifact pickup and gameplay crash/effect verification remain pending. This is an unpublished experimental build.

# 0.3.0 RC1 debug v5 — 2026-10-04

- Remove GetAgentType_BP/IsAlive calls on cached NPCs after the latest dump identifies a null native gameplay core. Use verified engine skeleton/component APIs.
- Replace two-second full world discovery with bounded cached processing and streaming notifications; replace periodic global HUD searches with notifications on supported UE4SS builds.
- Spread native leaf/crow LOD updates across frames rather than synchronizing up to six effects once a second.
- Test anomalies after movement each frame, including the portion of a swept segment inside their zones; publish HP/loss changes immediately.
- Attempt direct C++ attack damage through a synchronously read-back-verified temporary HP reserve (removed in v6 after delayed game-stat normalization caused instant destruction); retain AI-compatible receiving collision, suppress proxy bleeding, and restore configured god mode and player state after flight or partial failure.
- Discover existing/new exact concussion/blinking materials and correct direct native scalar writes each frame; accept callable-table FName constructors.
- Human scan bounds follow native binocular bone configuration, with shorter softened corners and compact distance labels. Faction icons and relationship colours remain pending verified per-target metadata access.
- All 29 Lua suites (26 lifecycle cases), five fresh native test programs and installer preservation/rollback checks passed. Gameplay verification remains pending; this is not a published stable release.

# 0.3.0 RC1 — experimental

- RC1 debug v4 retains the stable rendering dropdown and draw-distance settings.
- Editable decimal flight speed 0–5, default 2; zero cuts thrust while inertia and gravity continue.
- Optional simulated RSSI, adjustable 50–20000 m maximum range and attenuation multiplier 0–5, default 2. Positive multipliers shape the distance curve without moving the selected distance-loss limit; zero disables distance/wall/anomaly attenuation. Wall/anomaly penalties scale by multiplier / 2.
- Editable RSSI OSD, progressive native-overlay interference and video loss.
- Latched signal loss cuts thrust, allows falling, then restores player/UI on FPV exit.
- Explicit button requests all three binocular prototypes from the player inventory.
- Prior OSD layouts migrate with existing positions preserved.
- Five interference styles (including a new analog receiver simulation); previous four preserved. Optional collision-based signal attenuation behind loaded obstacles.
- Character/mutant/anomaly scanning brackets, prototype anomaly interference/damage and loaded-artifact detector.
- Scanner brackets now use Unreal's viewport projection and actor collider bounds, with live positions at 30 Hz and bounds at 5 Hz. Up to 16 closest markers are drawn; the native binocular aiming mode is not activated.
- Softer ordinary landings (ground normal impact up to 5 m/s); collision damage multiplier 0–5, default 2, recalibrated to retain the previous soft default of 0.25. Independently saved and applied from the durability page.
- Opt-in shielded enemy target proxy: native `/Script/Stalker2.Obj:ReceiveDamage` observes actual positive incoming damage for drone HP and clears pawn damage/armor/bleeding parameters. Four Blueprint hit events remain an optional 25-HP fallback. Duplicate feedback is merged; hooks are retired on exit. Engine bypass while shielded and actual gameplay delivery remain unverified.
- Refresh poppy-field sleepiness/stun suppression every frame, update the native camera and target `ConcussionIntensity` / `BlinkAlpha` material parameters. In-game effect removal is unverified.
- The crash dump points to `GetFullName` / native name conversion. Remove those calls from two particle modules and the optional broad UserWidget subtitle scan; retain exact SubtitleView/HUD paths, the native subtitle API and the removal of live schema introspection in experiments. Exact offending object/cause are unknown; analog-style switching still needs a fresh game test.
- Artifact detector remains available; collection explicitly reports unavailable because no verified integer UID API exists for AArtifact in this build.
- Five experimental subpages, including read-only controller diagnostics for 32 buttons, four hats and eight channels. Simultaneous held inputs clear on release/disconnect/device change; no action bindings are assigned. V3 telemetry and bounded cached actor queries remain.
- All 29 Lua suites, including 24 lifecycle adapter cases, and five freshly compiled native test executables passed.
- New game verification is pending; no FPS improvement is claimed.

# 0.2.0 — 2026-10-03

Stable release, following the user's final in-game verification.

Changes since RC4:

- Preserve rain, falling leaves and crows when entering FPV. Recover supported particle sources after the game retires or reuses their components, using bounded rediscovery instead of continuous world scans.
- Make the F6 menu and OSD settings window resizable and maximizable. Scale their controls/fonts and save window dimensions; preserve the OSD preview's game aspect ratio and existing element positions.
- Restore the game HUD immediately after leaving FPV, without requiring an Esc/settings round trip. Restore each saved widget independently and remove global hide/show commands that could leave the HUD hidden.
- Reduce repeated camera/presentation/particle work and keep the accepted rendering behavior. Physics remains at 240 Hz; all collision queries are retained.
- Improve restoration after partial failures, controller/OSD window thread synchronization and analog-style saving.
- Preserve UTF-8 mod names in the Windows PowerShell 5.1 installer and roll back failed installation/update operations, including the original mod list and previous ZoneFPV files.
- Remove obsolete diagnostic artifacts from the distribution and automatically discover all Lua test suites.

This stable release also includes the RC4 changes below: default main FPV with an explained alternative mode, stronger collision, player/exposure/subtitle state restoration, player detection isolation, weather/freeze/focus fixes, uniform geometry loading up to 5×, optional manual object-limit configuration and the DualShock 4 DirectInput profile.

Known limitations: the CNPP black anomaly effect remains unresolved; checkpoint quest fog is unchanged. Some geometry or collision may still be unavailable while streaming. Higher loading multipliers and object limits can increase RAM use and reduce performance. Physical DS4 testing and actual startup object-capacity verification are pending; no numerical FPS improvement is claimed.

# 0.2.0 RC4 — 2026-10-02

Changes relative to RC3:

- Main FPV is the default, with an explained alternative mode.
- Stronger simple/complex sphere collision using both trace channel and player profile.
- Player/weapon/shadow/subtitle hiding, supported exposure/audio suppression and state restoration.
- RC2/RC3-style hidden simulation anchor prevents player detection without stopping NPC/mutant fights with each other.
- Weather/time changes preserve drone position; world freeze keeps FPV usable; F6 closing and focus loss do not end FPV.
- Full uniform geometry loading multipliers 1×, 1.25×, 1.5×, 2×, 3×, 4×, 5× across all ten original terrain/building/prop/tree/foliage/HLOD grids. Exact original values are restored on exit.
- Rendering tab: optional, manually entered `gc.MaxObjectsInGame`, with Save to Engine.ini and Game default actions. Changes require explicit user input and a full game restart, affect the whole game and can increase RAM/loading/GC costs. Existing Engine.ini is backed up before a requested change; unrelated settings and UTF-8/UTF-16LE content are preserved. Installation/startup do not edit this setting automatically.
- Explicit DualShock 4 DirectInput identification/profile; physical hardware test pending.
- Reduce physics allocations/repeated math, cache unchanged packets, skip held-camera writes and duplicate presentation setters; audio-state reads at 50 Hz and cached OSD positioning. Keep 240 Hz physics and all collision queries.
- Remove unused experimental tools; update build, tests, documentation and installer cleanup checks.

The CNPP black effect remains unresolved; quest checkpoint fog is unchanged. Unloaded geometry and missing collision remain possible. Higher rendering multipliers can reduce FPS and increase RAM use; changing the object limit does not guarantee stability. Physical DS4 testing is pending. These optimizations have no measured in-game FPS result.

# 0.2.0 RC3 — 2026-09-27

- Respect UE4SS's configured game-thread method, including EngineTick; remove the RC2 ProcessEvent override.
- Catch dispatch errors, release the pending flag and rate-limit retries without switching hooks.
- Reduce worker polling from 1 ms to 4 ms while keeping at most one queued callback.
- Stop hiding a potentially inherited console during the PowerShell bootstrap.
- Restrict native game focus/hotkeys/OSD targeting to the Unreal viewport; ignore queued hotkeys after focus leaves eligible windows.
- Document the reported game 2.0.6 / UE4SS 527a483b setup. The reporter confirmed RC3 worked without the earlier freezes.

# 0.2.0 RC2 — 2026-09-21

- Camera tilt dropdown has a scrollbar and supports mouse-wheel scrolling.
- Explicitly select ProcessEvent for game-thread dispatch when available, matching the original runtime configuration.
- Add publication, installation and build documentation.
- Clarify runtime and version-specific compatibility requirements.

# 0.2.0 RC1

- Acro / Angle / reversible-thrust 3D selection.
- Controller profiles, guided calibration and hotplug handling.
- Five languages, dark/light themes and configurable keys.
- Four analog styles and configurable telemetry OSD.
- Steam-aware installer, update backups and uninstall script.

## RC1 debug v53 — 2026-10-08

- Project scanner targets through the current FPV mount, calibrating the native viewport lens with five engine probes; remove 30 Hz publication stepping.
- Validate streamed/pooled target lifecycle, world, identity and fresh transforms before publishing. Reject camera-plane crossing boxes rather than bounding partial front corners.
- Alternate complete generation/sequence packets, reject stale rollback and expire unchanged frames after 100 ms. Refresh visible brackets at 8 ms in the existing helper loop.
- Rebuild helper53; retain native51, PDA52, armament PAK and current preferences. See DEBUG_V53_REPORT_RU.md for verification and manual flight checks.

