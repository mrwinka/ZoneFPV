# ZoneFPV 0.3.0 RC2 - review notes

The current native helper, native game bridge, runtime Lua and namespaced armament configs are included in this source tree. See RELEASE_NOTES.md for the RC1-to-RC2 changes, RELEASE_STATUS.md for validation limits and RELEASE_VERIFICATION.json for exact artifact hashes. All 74 Lua suites and syntax checks for 155 files passed again after the release-label change. The public source runner and isolated full-install/update/uninstall/rollback fixtures also passed.

RC2 reuses the locally tested helper, DLL and PAK unchanged. Its only runtime difference from that installed build is one FPV entry log label. Battery behavior is an approximate five-inch-quad model; no hardware-specific runtime or measured FPS improvement is claimed. Compatible game and UE4SS installations remain external dependencies.
