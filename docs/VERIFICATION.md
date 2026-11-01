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

## 0.2.1 crash fix and presentation cleanup

The maintainer's 2026-11-01 crash report identified SIGABRT at
`BuscadorRutas.cpp:1110`, inside `reconstruyeCamino`. A new slope-exit fixture
reproduced that exact assertion in the unmodified engine (exit status 134).
With the boundary check corrected, the fixture passes: planning restores the
original live position and emits the slope movement followed by a replan command.
The real-data smoke test, all seven save slots, and the fixture pass with
AddressSanitizer and UndefinedBehaviorSanitizer (leak detection disabled).

The native title screen was inspected after removal of the decorative frame and
key legend. The icon's outer emerald tile was removed with the built-in image
editing tool; its packaging script regenerates all icon sizes from the new
transparent master. The existing notarized 0.2.0 release is not modified by these
source changes. A new 0.2.1 distribution requires its own signing/notarization.

## 0.2.2 audio fixes — 2026-11-01

The ARM64 and Intel development executables pass the audio playback regression
test using a simulated output. Coverage includes repeated music requests,
track replacement without interrupting effects, mute/unmute, repeated pause,
mute while paused, resume while muted, track changes while muted, stopping a
paused track, invalid identifiers, and recovery after an output start failure.

Both architectures pass the real-data smoke test, now also checking the requested
tracks for title, prologue, gameplay, and ending. The same scenario and audio
regressions pass with AddressSanitizer and UndefinedBehaviorSanitizer. The local
0.2.2 app is universal and ad-hoc signed; the existing signed 0.2.1 release files
are preserved. The native 0.2.2 app launches through AppKit.

Audible speaker/headphone output has not been confirmed. The automation
environment previously failed audio-device preparation, so simulated playback
tests are deliberately distinguished from hardware listening tests.
All twelve installed WAV files were opened and decoded into PCM buffers with
AVFoundation, including both the 8-bit music and the 16-bit effects.
The smoke tests also remove an imported background WAV, reimport the data, and
verify that the WAV returns while the existing save file remains unchanged.
