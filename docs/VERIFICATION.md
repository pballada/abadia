# Local verification — 2026-10-31

Environment: macOS 26.6.2, Xcode 27.1, Apple Silicon. Deployment target: macOS 13.

Verified locally:

- ARM64 and x86_64 compile and link using system frameworks only.
- Both architecture executables pass the asset-free validation tests; the Intel executable runs under Rosetta.
- Both architectures pass the real-data smoke test: intro, menu, new game, prologue skip, player turn, framebuffer, slot write, load confirmation, restoration of deliberately modified player coordinates, and 500 further game ticks.
- AddressSanitizer and UndefinedBehaviorSanitizer pass the same real-data scenario after fixing the inherited negative array index in the save writer. Leak detection is disabled for this legacy process-lifetime engine.
- The native file picker successfully imports the supported local data pack; the next launch loads it from Application Support.
- AppKit UI checked for title rendering, quick Return taps, starting play, pause, and fullscreen. Additional visual refinements restore the menu palette and composite the pause overlay over the frozen scene.
- Universal Mach-O architecture and ad-hoc bundle signature verified.

Not claimed: a full seven-day playthrough, all endings, physical Intel hardware, physical gamepad testing, older macOS runtime testing, Developer ID signing, or notarization.

Upstream game data used for local tests is excluded from source and distributable archives. The built app expects the player's locally imported data.

## 0.2 reliability regressions

The local real-data check now covers all seven slot round trips, a corrupted payload, an empty slot, and an unwritable staging path. Rejected loads preserve the current player position; failed overwrites preserve the previous file. This is targeted regression coverage, not a completed seven-day playthrough.

The 0.2 regression scenario passed locally with AddressSanitizer and UndefinedBehaviorSanitizer (leak detection disabled for the process-lifetime engine). The first-launch guide was also opened and dismissed through the native UI.
