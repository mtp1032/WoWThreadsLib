# WoWThreadsLib  

A lightweight, embeddable coroutine-based threading library for World of Warcraft addons.

WoWThreadsLib is the \*\*embedded-library counterpart\*\* to the standalone \*\*WoWThreads\*\* addon.  

Both projects expose the same public API and threading semantics, but WoWThreadsLib is designed  

specifically for addon developers who want to embed a pure coroutine/threading engine directly  

into their own addons without shipping the full standalone addon.

For information about the standalone addon, its UI features, and player-facing functionality,  

see the \*\*WoWThreads README\*\* in the main WoWThreads repository.

---



## Overview



\*\*WoWThreadsLib\*\* provides a deterministic, cooperative threading model built on Lua coroutines.  

It allows addon authors to create lightweight threads, yield execution, sleep, wake, and exchange  

signals without blocking the WoW client’s event-driven execution model.



The library is intentionally minimal:



\- No minimap icon  

\- No help panel  

\- No documentation UI  

\- No error UI  

\- No standalone addon state  

\- No player-facing features  



It is a pure library intended for embedding.



\---



\## Features



\- Deterministic coroutine scheduling  

\- Thread creation and lifecycle management  

\- Sleep/wakeup semantics  

\- Signal queue and inter-thread communication  

\- Addon-aware thread attribution  

\- Identical API surface to the standalone WoWThreads addon  

\- Lightweight footprint suitable for embedding  

\- Distributed via LibStub under a distinct library name (e.g., `"WoWThreadsLib"`)



\---



\## Installation (Embedding in Your Addon)



1\. Copy the `WoWThreadsLib` directory into your addon’s `Libs/` folder.

2\. Ensure `LibStub.lua` is present in your addon (either your own copy or the one included here).

3\. Add the following lines to your addon’s `.toc` file:





