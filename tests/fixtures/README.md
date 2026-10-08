# Cross-language test fixtures

These synthetic packets were emitted by the production C++ menu/PDA test harnesses and frozen for the Lua contract tests. They contain test settings, not a player's preferences. The This release checks verify these packets against the unchanged helper sources. `Test.ps1` consumes the armament and PDA packets; telemetry is freshly emitted by its Lua test into build.

The corresponding generators are `src/menu_window_test.cpp` and `src/pda_settings_bridge_test.cpp`. When changing the protocol, regenerate and validate both producers and consumers together.