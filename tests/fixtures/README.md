# Cross-language test fixtures

These synthetic packets were emitted by the C++ menu/PDA test harnesses and frozen for the Lua contract tests. They contain test settings, not personal preferences. Test.ps1 consumes the armament and PDA packets; its telemetry test emits a fresh fixture under build.

The corresponding producers are src/menu_window_test.cpp and src/pda_settings_bridge_test.cpp. Protocol changes require both producers and consumers to be validated together.
