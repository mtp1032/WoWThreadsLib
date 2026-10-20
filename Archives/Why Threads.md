Why Coroutines?
Modern game engines—including World of Warcraft—are fundamentally event‑driven.
Most of the time, nothing needs to happen. Work occurs in short bursts when the game fires events, the player interacts with the UI, or the world state changes.

A traditional addon often responds to this environment by running logic every frame, typically through an OnUpdate handler. Even when the addon has nothing meaningful to do, its OnUpdate code still executes every 16.67 ms. This consumes CPU unnecessarily and competes with:

other addons

UI updates

rendering

the game engine itself

Coroutines provide a different, more efficient model.

Coroutines Run Only When They Have Work
A coroutine is a lightweight, cooperative thread of execution managed entirely inside the Lua VM.
Unlike a traditional OnUpdate loop, a coroutine:

runs only when resumed,

yields immediately when idle,

consumes no CPU between resumes,

does not compete with other addons when suspended.

This makes coroutine‑based addons naturally efficient in an event‑driven environment.

The Scheduler Runs Only Once Per Frame
WoWThreads uses a scheduler that runs once per frame (via OnUpdate).
During each frame, the scheduler:

checks thread tick delays,

checks signal queues,

determines which threads are runnable,

resumes only those threads that need to run.

If all threads are suspended—because they yielded, delayed, or are waiting for signals—the scheduler performs only a minimal check and returns immediately.

In this state:

your addon is effectively idle,

WoW.exe is free to service other addons,

the UI remains responsive,

rendering proceeds without competition,

the game engine runs without additional load.

A coroutine‑based addon imposes almost no overhead when it has no runnable work.

Why This Matters in an Event‑Driven Game
Event‑driven workloads are bursty:

A player clicks a button → a burst of logic runs.

A combat log event fires → a burst of logic runs.

A timer expires → a burst of logic runs.

Everything quiets down → nothing needs to run.

Coroutines map perfectly to this pattern:

They wake when needed.

They run until they yield.

They sleep until resumed.

They impose no cost while sleeping.

This is why coroutine‑based scripting models are used in many modern games and engines:

Minecraft datapacks

Roblox scripts

Factorio mods

Unity coroutines

Godot coroutines

Embedded cooperative runtimes

And now, WoWThreads

Coroutines allow developers to write linear, readable logic while still behaving cooperatively within the game’s event loop.

The Key Efficiency Insight
A traditional addon often does this:

lua
frame:SetScript("OnUpdate", function()
    -- runs every frame, even when idle
end)
A WoWThreads addon does this:

run only when a coroutine is runnable

yield immediately when idle

impose almost no load between resumes

let the game engine and other addons run freely

This is the core benefit:

Coroutines allow addons to express complex logic without consuming CPU when idle.
They are a natural fit for event‑driven environments and lead to broadly more efficient addons.

Summary
Coroutines are not just a convenience—they are a performance model.
In an event‑driven game like World of Warcraft, coroutine‑based addons:

run only when necessary,

sleep when idle,

reduce frame‑to‑frame CPU usage,

avoid competing with other addons,

integrate cleanly with the game’s event loop,

and scale better as addon complexity grows.

WoWThreads brings this model to WoW addon development, enabling developers to write clearer, more maintainable code while remaining highly efficient within the game client.