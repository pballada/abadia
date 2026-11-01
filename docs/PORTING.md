# Port architecture

`Sources/Core` is derived from Samuel85/Abbey commit `048c3141f0bd1772c8b0bba82d18ebc72d837be1`. It includes the VIGASOCO reconstruction plus Abbey's configuration reader and translated menu strings. The upstream README license is unchanged. Platform-specific builds and original assets were deliberately not imported.

`Sources/Platform` replaces SDL with a small native contract:

- AppKit owns the application, menus, panels, window, keyboard events, and run loop.
- The original 130 ms gameplay cadence and 60 ms prologue cadence run on the main thread. Rendering and state mutation therefore cannot race. Pausing discards held/pending input, and no catch-up burst runs after focus returns.
- The engine supplies a 640 × 400 RGBA framebuffer. Core Graphics presents it in sRGB, keeping its 8:5 proportions with black letterboxing only where the window requires it. Whole-number scales use nearest neighbour. Other scales use sharp bilinear: nearest neighbour up to the next whole multiple, then one smooth resample. Every source pixel is then the same size on screen, avoiding the alternating 3- and 4-pixel columns of fractional nearest-neighbour scaling. **Pixel-Perfect Scaling** restricts the image to whole multiples.
- AVAudioPlayer handles optional WAV music and sound effects at their native sample rates (8-bit/16-bit mono, 11–22 kHz in the Abbey pack). Abbey's SDL_mixer build resamples everything through a 22,050 Hz mixer. All players are prepared when the engine starts, so the first effect plays without delay. No external codec libraries are needed.
- Apple's GameController framework supplies D-pad, left-stick, and button state.
- **Download Game Data** fetches the pack from the pinned Abbey commit `048c314` on GitHub. Every file is checked against a pinned SHA-256: required files fail the download, and mismatched optional audio is skipped. It then uses the same staged import as a local folder.
- A staged, SHA-256-validated import keeps disk data outside the bundle. The working directory is explicitly set to Application Support before the inherited relative-path loader and save system run.

## Changes to inherited code

- Added `Juego::usaGraficosCPC(bool)`, the public entry point to the engine's existing graphics swap (`cambioCPC_VGA`). Upstream never called that swap, so `GraficosCPC` was loaded but never shown. The swap now redraws in place only during gameplay; other states redraw when entered. The CPC pack includes its own palette, so switching gives the original Amstrad colours.

- Removed the unused SDL include from the renderer and replaced the SDL file reader with a checked binary `ifstream` reader. Missing/short files now fail initialization.
- Renamed the engine's global `Rect` to `GameRect` to avoid the macOS SDK's legacy `Rect` type.
- Reordered the object-owner search bounds check in the serializer so an unowned object never reads `personajes[-1]`. Initialized its load temporary.
- Fixed the configuration parser's empty-line/out-of-range access and ignored malformed lines.
- Bounded the language index to the eight supported translations, defaulting to Spanish, and removed a configuration-reader leak.
- Restore the game palette when entering the menu, so the title screen's dark palette does not make menu text difficult to read.
- Released the temporary per-file tracking allocation in the file loader.

`SDLPalette` is an inherited class name, not an SDL dependency. One little-endian conversion helper retains its old name to keep the engine diff small. Core source files retain the upstream byte encoding because its in-game text renderer expects single-byte character codes; do not blindly convert string literals to UTF-8.

## Distribution

`make package` produces a universal app linked only against system frameworks. Codesigning is ad hoc. Developer ID signing and notarization are separate release steps requiring the maintainer's signing identity. The artifact excludes ROMs and other game assets. CI builds both architectures and executes asset-free checks; full gameplay checks require local data supplied separately.

## Save integrity (0.2)

New saves append a versioned SHA-256 footer to the inherited text payload. The loader checks it before the legacy deserializer can mutate the world. Writes go to a sibling temporary file and replace the slot by rename only after close and sealing succeed; configuration metadata is updated afterwards. Configuration writes use a sibling temporary file too. This protects against accidental corruption and incomplete writes; it is not authentication of untrusted saves. Earlier unsealed saves are rejected without modifying them.

## Screen-boundary path reconstruction fix

The 2026-11-01 crash report identified an assertion in
`BuscadorRutas::reconstruyeCamino` when its simulated character left the central
20 × 20 grid. Leaving a slope can advance two cells while search waypoints are
one cell apart. Reconstruction now ends the valid movement prefix at that
boundary; the existing command terminator requests a fresh route after execution.
The live character position is restored after planning as before. Failed height
queries also stop reconstruction before their output values can be used.

`Tests/RouteBoundaryRegression.h` constructs this slope-exit scenario. The
unfixed engine aborts at the same assertion as the reported crash; the fixed
engine preserves the live position and emits a movement command followed by
the replan command. The fixture runs at the end of the real-data smoke test.

## Self-updater (0.3)

`Sources/Platform/Updater.mm` reads `releases/latest` from the GitHub API at most once a day; **Check for Updates…** checks immediately. Automatic checks run only in Developer ID builds, so development builds don't prompt. An update proceeds only if all of these hold:

1. The release tag (`vX.Y.Z`) is numerically newer than the running version.
2. The asset `Abadia-macOS.zip` is downloaded and extracted with `ditto` on the app's own volume.
3. The extracted app passes `SecStaticCodeCheckValidity` (all architectures, strict, nested code). The requirement is: Apple-anchored, Developer ID Application certificate, team `5UXXXESGMK`, identifier `net.pballada.abadia`.
4. The extracted app's own version is newer as well.

The bundle is then swapped with `replaceItemAtURL`. A detached shell waits for the process to exit and reopens the app. If the app is translocated or its folder isn't writable, the player is sent to the release page instead. Game data and saves live in Application Support and are never touched.
