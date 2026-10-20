

# The WoWThreads Programming Guide

> *If your only tool is a hammer, all problems look like nails.*  
> — Abraham Maslow  
>
> *I’ve never met a young engineer who didn’t think threads were great.  
> I’ve never met an older engineer who didn’t shun them like the plague.*  
> — Anonymous

## Caveat

I am a developer who could have written that second aphorism. I’m a [former] software engineer/architect and I have a love‑hate relationship with threading. I’ve written thousands of lines of multithreaded applications, including protected‑mode operating system internals. For Linux, I wrote the first POSIX thread package, **PCThreads**. Over the years, I’ve learned that while experience with multithreading can be impressive on a résumé, using multiple threads seldom lives up to their hype. And so it is with threads when applied to WoW addon programming. They can be quite useful, but lead to madness if not applied appropriately.

WoWThreads was motivated by some WoW addon work I did for personal use. Over the course of playing World of Warcraft, I noted that many of the addons I used were quite impressive. The code was clean and functional. None seemed overly complex, especially for complexity’s sake, as is so often the case with code written by less experienced engineers. Writing addons looked to be fun (and useful), so I jumped in.

Initially, I wrote a couple of simple addons — one to display information when my character experienced a skill‑up and [yet another] bank management addon. But as I gained more familiarity with Blizzard’s addon programming and especially its event‑driven execution model, I couldn’t help but wonder if threading, rightly applied, might be useful. So I wrote a simple combat logger and immediately ran into difficulty.

Since WoW, like many games of its type, is an event‑driven application, I thought I’d write a small prototype threads facility that would enable me to dedicate threads to the tasks of receiving, processing, and displaying individual combat events. More specifically, I needed a more flexible way to control the spacing between lines of text as they scrolled across the screen. Using threads to handle events would allow the WoW client to return and wait for the next event.

As it happened, the prototype thread package worked. My application didn’t run faster — that wasn’t the goal — but I needed to slow down the rate at which text frames scrolled up the screen (which I later learned did not need to be executed within a thread). Talon, my code name for what became the WoWThreads facility, offered a set of primitives that allowed me to easily assign tasks to specific threads and coordinate their execution using a signals‑based communication scheme.

So, is multithreading the way to go when developing WoW addons? Probably not directly. But does threading make for better addons? In my opinion, the structure of the addon will change in that the code will better express the event‑driven pattern of the World of Warcraft execution model. However, its major benefit will be in its **efficiency**. Which brings us to the myth that coroutine‑based software is inefficient.

---

# Why Threads

The concepts described in this section are geared toward experienced developers who may not have had experience with thread programming before. If this is not you, please skip to the section *WoWThreads API*.

With that out of the way, here we go.

A thread created by the WoWThreads library consists of two components:

1. A thread handle (by convention, `thread_h` in this document).  
2. A coroutine that executes the thread’s function.

The thread’s handle is a table of attributes that WoWThreads uses to schedule and manage the execution of the thread’s coroutine. Each thread handle controls exactly one coroutine.

To implement asynchronous scheduling, WoWThreads implements its own scheduler and assumes complete control over a thread’s coroutine. When created, the thread’s handle (containing a reference to its coroutine) is inserted into the library’s Thread Control Block (TCB). A timer‑based scheduler (based on Blizzard’s `C_Timer.After`) examines the TCB on every clock tick (60 times per second or about 16.667 ms) for threads whose yield‑timer has expired. The coroutine of any thread whose yield‑timer has expired is resumed.

---

# Threads — Why Coroutines

The concepts described in this section are geared toward experienced developers who may not have had experience with thread programming before. If this is not you, please skip to the section *WoWThreads API*.

With that out of the way, here we go.

A thread created by the WoWThreads library consists of two components:

1. A thread handle (by convention, `thread_h` in this document).  
2. A coroutine that executes the thread’s function.

The thread’s handle is a table of attributes that WoWThreads uses to schedule and manage the execution of the thread’s coroutine. Each thread handle controls exactly one coroutine.

To implement asynchronous scheduling, WoWThreads implements its own scheduler and assumes complete control over a thread’s coroutine. When created, the thread’s handle (containing a reference to its coroutine) is inserted into the library’s Thread Control Block (TCB). A timer‑based scheduler (based on Blizzard’s `C_Timer.After`) examines the TCB on every clock tick for threads whose yield‑timer has expired. The coroutine of any thread whose yield‑timer has expired is resumed.

---

## Why Coroutines?

World of Warcraft is fundamentally **event‑driven**. Most of the time, nothing needs to happen. Work occurs in short bursts when the game fires events, the player interacts with the UI, or the world state changes.

A traditional addon often responds to this environment by running logic **every frame**, typically through an `OnUpdate` handler. Even when the addon has nothing meaningful to do, its `OnUpdate` code still executes every ~16.67 ms. This consumes CPU unnecessarily and competes with:

- other addons  
- UI updates  
- rendering  
- the game engine itself

Coroutines provide a different, more efficient model.

A coroutine is a lightweight, cooperative thread of execution managed entirely inside the Lua VM. Unlike a traditional `OnUpdate` loop, a coroutine:

- runs only when resumed,  
- yields immediately when idle,  
- consumes no CPU between resumes,  
- does not compete with other addons when suspended.

This makes coroutine‑based addons naturally efficient in an event‑driven environment.

---

## OnEvent vs OnUpdate — The Heart of the Execution Model

It is essential to distinguish between **event handlers** and **frame update handlers**, because WoWThreads integrates with the game engine through both — but in very different ways.

### **Event Handlers (`OnEvent`)**

Event handlers fire only when the game engine emits an event:

- `PLAYER_LOGIN`  
- `COMBAT_LOG_EVENT_UNFILTERED`  
- `BAG_UPDATE`  
- etc.

Event handlers:

- may send signals to threads  
- may update thread state  
- must return immediately  
- do **not** resume coroutines  
- do **not** run the scheduler  

When your addon receives an event and calls:

```lua
thread:sendSignal(thread_h, SIG_ALERT, payload)
```

the signal is inserted into the target thread’s queue, but **no coroutine is resumed at this time**.  
Your event handler returns immediately to WoW.exe, and the game client continues servicing other addons, UI updates, and engine tasks.

### **Frame Update Handlers (`OnUpdate`)**

The WoWThreads scheduler runs inside an `OnUpdate` handler:

```lua
frame:SetScript("OnUpdate", function()
    WoWThreadsLib:runScheduler()
end)
```

This callback fires **once per frame**, typically every 16.67 ms.

This is the heartbeat of WoWThreads.

During each frame, the scheduler:

1. checks thread tick delays  
2. checks signal queues  
3. determines which threads are runnable  
4. resumes only those threads that need to run  

If **all threads are suspended** — because they yielded, delayed, or are waiting for signals — the scheduler performs only a minimal check and returns immediately.

In this state:

- your addon is effectively idle  
- WoW.exe is free to service other addons  
- the UI remains responsive  
- rendering proceeds without competition  
- the game engine runs without additional load  

This is the core execution model:

> **Event handlers mutate thread state.  
> The OnUpdate handler executes thread state.**

---

## Why This Matters

Event‑driven workloads are **bursty**:

- A player clicks a button → a burst of logic runs.  
- A combat log event fires → a burst of logic runs.  
- A timer expires → a burst of logic runs.  
- Everything quiets down → nothing needs to run.

Coroutines map perfectly to this pattern:

- They wake when needed.  
- They run until they yield.  
- They sleep until resumed.  
- They impose no cost while sleeping.

This is why coroutine‑based scripting models are used in many modern games and engines:

- Minecraft datapacks  
- Roblox scripts  
- Factorio mods  
- Unity coroutines  
- Godot coroutines  
- Embedded cooperative runtimes  
- And now, WoWThreads

Coroutines allow developers to write linear, readable logic while still behaving cooperatively within the game’s event loop.

---

## The Key Efficiency Insight

A traditional addon often does this:

```lua
frame:SetScript("OnUpdate", function()
    -- runs every frame, even when idle
end)
```

A WoWThreads addon does this:

- run only when a coroutine is runnable  
- yield immediately when idle  
- impose almost no load between resumes  
- let the game engine and other addons run freely  

This is the core benefit:

> **Coroutines allow addons to express complex logic without consuming CPU when idle.  
> They are a natural fit for event‑driven environments and lead to broadly more efficient addons.**

---

## Why Coroutines?

World of Warcraft is fundamentally **event‑driven**. Most of the time, nothing needs to happen. Work occurs in short bursts when the game fires events, the player interacts with the UI, or the world state changes.

A traditional addon often responds to this environment by running logic **every frame**, typically through an `OnUpdate` handler. Even when the addon has nothing meaningful to do, its `OnUpdate` code still executes every 16.67 ms. This consumes CPU unnecessarily and competes with:

- other addons  
- UI updates  
- rendering  
- the game engine itself

Coroutines provide a different, more efficient model.

A coroutine is a lightweight, cooperative thread of execution managed entirely inside the Lua VM. Unlike a traditional `OnUpdate` loop, a coroutine:

- runs only when resumed,  
- yields immediately when idle,  
- consumes no CPU between resumes,  
- does not compete with other addons when suspended.

This makes coroutine‑based addons naturally efficient in an event‑driven environment.

### The Scheduler Runs Only Once Per Frame

WoWThreads uses a scheduler that runs once per frame (via `OnUpdate`). During each frame, the scheduler:

1. checks thread tick delays,  
2. checks signal queues,  
3. determines which threads are runnable,  
4. resumes only those threads that need to run.

If **all threads are suspended** — because they yielded, delayed, or are waiting for signals — the scheduler performs only a minimal check and returns immediately.

In this state:

- your addon is effectively idle,  
- WoW.exe is free to service other addons,  
- the UI remains responsive,  
- rendering proceeds without competition,  
- the game engine runs without additional load.

A coroutine‑based addon imposes almost no overhead when it has no runnable work.

### Why This Matters

Event‑driven workloads are **bursty**:

- A player clicks a button → a burst of logic runs.  
- A combat log event fires → a burst of logic runs.  
- A timer expires → a burst of logic runs.  
- Everything quiets down → nothing needs to run.

Coroutines map perfectly to this pattern:

- They wake when needed.  
- They run until they yield.  
- They sleep until resumed.  
- They impose no cost while sleeping.

This is why coroutine‑based scripting models are used in many modern games and engines:

- Minecraft datapacks  
- Roblox scripts  
- Factorio mods  
- Unity coroutines  
- Godot coroutines  
- Embedded cooperative runtimes  
- And now, WoWThreads

Coroutines allow developers to write linear, readable logic while still behaving cooperatively within the game’s event loop.

### The Key Efficiency Insight

A traditional addon often does this:

```lua
frame:SetScript("OnUpdate", function()
    -- runs every frame, even when idle
end)
```

A WoWThreads addon does this:

- run only when a coroutine is runnable,  
- yield immediately when idle,  
- impose almost no load between resumes,  
- let the game engine and other addons run freely.

In other words, coroutine-based threads allow addons to express complex logic without consuming CPU when idle. They are a natural fit for event‑driven environments and lead to broadly more efficient addons.

