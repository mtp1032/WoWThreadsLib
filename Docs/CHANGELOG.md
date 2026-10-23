# Changelog  
All notable changes to **WoWThreadsLib** will be documented in this file.

This project adheres to the versioning protocol described in `VERSIONING.md`.  
WoWThreadsLib is versioned independently from the standalone **WoWThreads** addon, although both
projects share the same public API and threading semantics.

---

## [0.1.0] - Initial Release
### Added
- First public release of **WoWThreadsLib**, the embeddable version of the WoWThreads threading engine.
- Introduced a pure coroutine/threading implementation suitable for embedding in third-party addons.
- Added core library files:
  - `WoWThreadsLib.lua` — main library engine
  - `Utils.lua` — utility functions used internally by the scheduler
  - `SignalQueue.lua` — inter-thread signaling and queue management
  - `Localizations.lua` — localized error messages and diagnostics
  - `LibStub.lua` — included for convenience; developers may use their own copy
- Added `Docs/` directory containing:
  - `API-Reference.md` — shared API documentation identical to the standalone WoWThreads addon
  - `Programmers-Guide.md` — installation, embedding, and usage instructions specific to WoWThreadsLib
  - `VERSIONING.md` — semantic versioning rules for the library
- Added initial `README.md` describing the library, its purpose, and its relationship to the standalone addon.

### Notes
- WoWThreadsLib uses a **different LibStub name** than the standalone addon, preventing version negotiation or override.
- The public API is identical to the standalone WoWThreads addon, ensuring full compatibility for addon developers.
- Internal implementation differs significantly from the standalone version (no UI, no minimap, no help panel, no documentation UI, no addon-level state). However, the public interface (The WoWThreads API) remains unchanged. 

---

## [Unreleased]
### Planned
- Additional scheduler diagnostics for embedded usage.
- Expanded examples in the Programmer’s Guide.
- Optional debug instrumentation for thread lifecycle events.
- Integration tests for embedded usage scenarios.
- Localization updates.

