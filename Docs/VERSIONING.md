\# WoWThreadsLib Versioning Protocol



WoWThreadsLib uses a clear, predictable semantic versioning model designed for embedded

World of Warcraft libraries. The versioning rules mirror the standalone WoWThreads addon

where appropriate, but WoWThreadsLib maintains its own independent version stream and

LibStub identity.



Both libraries share the same public API, but their internal implementations, packaging,

and release cycles differ. This document defines how version numbers are assigned and how

compatibility is maintained.



\---



\## Semantic Versioning



WoWThreadsLib uses the following version format:





Each component has a specific meaning:



\### \*\*PATCH (x.y.Z)\*\*  

Internal changes only. No API or behavioral changes.



PATCH increments include:

\- Internal refactoring  

\- Performance improvements  

\- Bug fixes  

\- Logging changes  

\- Documentation updates  

\- Code cleanup  

\- Reorganization  

\- Pure refactoring (even large-scale)



PATCH changes:

\- Do \*\*not\*\* require addon authors to update their embedded copy  

\- Do \*\*not\*\* affect API compatibility  

\- Do \*\*not\*\* change thread semantics  

\- Do \*\*not\*\* introduce new features  



PATCH releases are always safe and backward-compatible.



\---



\### \*\*MINOR (x.Y.z)\*\*  

Backward-compatible behavioral or feature changes.



MINOR increments include:

\- New optional features  

\- New public functions  

\- New scheduler modes  

\- New thread utilities  

\- Meaningful behavior changes that do not break existing addons  

\- Additions to the API that preserve backward compatibility  



MINOR changes:

\- Should prompt addon authors to update their embedded copy  

\- May change behavior in ways that matter to consumers  

\- Must not break existing addons  

\- Must not remove or alter existing API signatures  



MINOR releases remain backward-compatible but introduce new capabilities.



\---



\### \*\*MAJOR (X.y.z)\*\*  

Breaking changes or new architectural functionality.



MAJOR increments include:

\- Removed API functions  

\- Changed function signatures  

\- Changed scheduler semantics  

\- Changed coroutine behavior  

\- New architectural subsystems  

\- Any change that breaks existing addons  



MAJOR changes:

\- Require addon authors to update their code  

\- May break older versions of embedded WoWThreadsLib  

\- Must be accompanied by clear migration documentation  



MAJOR releases define new compatibility boundaries.



\---



\## Version Independence from Standalone WoWThreads



WoWThreadsLib is versioned independently from the standalone WoWThreads addon.



Examples:

\- Standalone WoWThreads: `2.0.0` (mature)

\- WoWThreadsLib: `0.1.0` → `1.x.x` (early-stage)



This independence exists because:

\- The libraries have different LibStub names  

\- They have different internal implementations  

\- They have different packaging  

\- They have different audiences  

\- They have different release cycles  



However, both libraries share the \*\*same public API\*\*, and the API documentation is identical.



For details on standalone versioning, see the \*\*WoWThreads README\*\* in the main repository.



\---



\## LibStub Version Encoding



WoWThreadsLib uses LibStub’s integer version encoding:





This ensures:

\- Correct numeric ordering  

\- Proper version negotiation  

\- No accidental collisions  

\- Clear separation between MAJOR, MINOR, and PATCH  



Example:





0.1.0 → 100

1.0.0 → 10000

1.2.3 → 10203





Because WoWThreadsLib uses a \*\*different LibStub name\*\* than the standalone addon, the two

libraries do not override each other and do not participate in shared version negotiation.



\---



\## Compatibility Guarantees



WoWThreadsLib guarantees:

\- Stable public API across PATCH and MINOR releases  

\- No breaking changes except in MAJOR releases  

\- Identical API semantics to the standalone WoWThreads addon  

\- Deterministic coroutine and signal behavior across all versions  



The standalone addon guarantees the same API semantics, but its version numbers and internal

features (UI, minimap, help panel, documentation UI) are independent.



\---



\## Release Policy



Each release of WoWThreadsLib must include:

\- Updated version number in `WoWThreadsLib.lua`  

\- Updated LibStub version integer  

\- Updated `CHANGELOG.md`  

\- Updated `API-Reference.md` if needed  

\- Updated `Programmers-Guide.md` if needed  



MAJOR releases must include:

\- A migration guide  

\- Clear documentation of breaking changes  

\- Updated examples  



\---



\## Summary



\- \*\*PATCH\*\* — internal changes only; no API or behavior changes  

\- \*\*MINOR\*\* — backward-compatible feature or behavior changes  

\- \*\*MAJOR\*\* — breaking changes or architectural changes  

\- WoWThreadsLib and WoWThreads have \*\*independent version streams\*\*  

\- Both libraries share the \*\*same public API\*\*  

\- LibStub names differ, preventing version collisions  

\- Version encoding follows the ACE3 numeric model  



This protocol ensures predictable, stable evolution of WoWThreadsLib while preserving API

compatibility with the standalone WoWThreads addon.











