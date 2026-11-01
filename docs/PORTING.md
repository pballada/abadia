# Port architecture

`Sources/Core` is derived from Samuel85/Abbey commit `048c3141f0bd1772c8b0bba82d18ebc72d837be1`. It includes the VIGASOCO reconstruction plus Abbey's configuration reader and translated menu strings. The upstream README license is unchanged. Platform-specific builds and original assets were deliberately not imported.

`Sources/Platform` replaces SDL with a small native contract:

- AppKit owns the application, menus, panels, window, keyboard events, and run loop.
- The original 130 ms gameplay cadence and 60 ms prologue cadence run on the main thread. Rendering and state mutation therefore cannot race. Pausing discards held/pending input, and no catch-up burst runs after focus returns.
- The engine supplies a 640 × 400 RGBA framebuffer. Core Graphics presents it directly in sRGB with nearest-neighbor scaling, aspect preservation, and a framed native surround. No edge smoothing is applied.
- AVAudioPlayer handles optional WAV music and sound effects. No external codec libraries are needed.
- Apple's GameController framework supplies D-pad, left-stick, and button state.
- A staged, SHA-256-validated import keeps disk data outside the bundle. The working directory is explicitly set to Application Support before the inherited relative-path loader and save system run.

## Changes to inherited code

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
