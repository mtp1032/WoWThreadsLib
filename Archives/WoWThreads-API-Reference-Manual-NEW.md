# The WoWThreads Programming Guide

> *If your only tool is a hammer, all problems look like nails.*  
> — Abraham Maslow  
>
> *I’ve never met a young engineer who didn’t think threads were great.  
> I’ve never met an older engineer who didn’t shun them like the plague.*  
> — Anonymous

## Preface

I am a developer who could have written that second aphorism. I’m a [former] software engineer/architect and I have a love‑hate relationship with threading. I’ve written thousands of lines of multithreaded applications, including protected‑mode operating system internals. For Linux, I wrote the first POSIX thread package, **PCThreads**. Over the years, I’ve learned that while experience with multithreading can be impressive on a résumé, using multiple threads seldom lives up to their hype. And so it is with threads when applied to WoW addon programming. They can be quite useful, but lead to madness if not applied appropriately.

WoWThreads was motivated by some WoW addon work I did for personal use. Over the course of playing World of Warcraft, I noted that many of the addons I used were quite impressive. The code was clean and functional. None seemed overly complex, especially for complexity’s sake, as is so often the case with code written by less experienced engineers. Writing addons looked to be fun (and useful), so I jumped in.

Initially, I wrote a couple of simple addons — one to display information when my character experienced a skill‑up and [yet another] bank management addon. But as I gained more familiarity with Blizzard’s addon programming and especially its event‑driven execution model, I couldn’t help but wonder if threading, rightly applied, might be useful. So I wrote a simple combat logger and immediately ran into difficulty.

Since WoW, like many games of its type, is an event‑driven application, I thought I’d write a small prototype threads facility that would enable me to dedicate threads to the tasks of receiving, processing, and displaying individual combat events. More specifically, I needed a more flexible way to control the spacing between lines of text as they scrolled across the screen. Using threads to handle events would allow the WoW client to return and wait for the next event.

As it happened, the prototype thread package worked. My application didn’t run faster — that wasn’t the goal — but I needed to slow down the rate at which text frames scrolled up the screen (which I later learned did not need to be executed within a thread). Talon, my code name for what became the WoWThreads facility, offered a set of primitives that allowed me to easily assign tasks to specific threads and coordinate their execution using a signals‑based communication scheme.

So, is multithreading the way to go when developing WoW addons? Probably not directly. But does threading make for better addons? In my opinion, the structure of WoWThreads-based addon will change in that the code will better express the event‑driven pattern of the World of Warcraft execution model. However, its major benefit will be in its **efficiency**. Which brings us to the myth that coroutine‑based software is inefficient.

---

## Why Threads

The concepts described in this section are geared toward experienced developers who may not have had experience with thread programming. If this is not you, please skip to the section *WoWThreads API*.

With that out of the way, let's dive in.

A thread created by the WoWThreads library consists of two components:

1. A thread handle (by convention, `thread_h` in this document).  
2. A coroutine that executes the thread’s function.

The thread’s handle is a table of attributes that WoWThreads uses to schedule and manage the execution of the thread’s coroutine. Each thread handle controls exactly one coroutine.

To implement asynchronous scheduling, WoWThreads implements its own scheduler and assumes complete control over a thread’s coroutine. When created, the thread’s handle (containing a reference to its coroutine) is inserted into the library’s Thread Control Block (TCB). A timer‑based scheduler (based on Blizzard’s `C_Timer.After`) examines the TCB on every clock tick (60 times per second or about 16.667 ms) for threads whose yield‑timer has expired. The coroutine of any thread whose yield‑timer has expired is resumed.

---

### Threads — Why Coroutines

The concepts described in this section are geared toward experienced developers who may not have had experience with thread programming before. If this is not you, please skip to the section *WoWThreads API Reference Manual*.

With that out of the way, here we go.

A thread created by the WoWThreads library consists of two components:

1. A thread handle (by convention, `thread_h` in this document).  
2. A coroutine that executes the thread’s function.

The thread’s handle is a table of attributes that WoWThreads uses to schedule and manage the execution of the thread’s coroutine. Each thread handle controls exactly one coroutine.

To implement asynchronous scheduling, WoWThreads implements its own scheduler and assumes complete control over a thread’s coroutine. When created, the thread’s handle (containing a reference to its coroutine) is inserted into the library’s Thread Control Block (TCB). A timer‑based scheduler (based on Blizzard’s `C_Timer.After`) examines the TCB on every clock tick for threads whose yield‑timer has expired. The coroutine of any thread whose yield‑timer has expired is resumed.

---

### Why Coroutines?

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

### OnEvent vs OnUpdate — The Heart of the Execution Model

It is essential to distinguish between **event handlers** and **frame update handlers**, because WoWThreads integrates with the game engine through both — but in very different ways.

#### **Event Handlers (`OnEvent`)**

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

#### **Frame Update Handlers (`OnUpdate`)**

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

---

### The Key Efficiency Insight

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

### Why Coroutines?

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

#### The Scheduler Runs Only Once Per Frame

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

#### Why This Matters

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

#### The Key Efficiency Insight

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

Absolutely, Michael — here is a **clean, formal, technically‑precise draft** of the **first part of the WoWThreads API Programmer’s Reference Manual**, following your outline exactly. It is written in Markdown, ready to paste directly into your combined document.

I’ve kept the tone appropriately technical (more formal than the Programmer’s Guide), concise, and structured for reference use. This section is intentionally “dictionary‑like,” as you requested, and sets the stage for the detailed API entries you’ll add later.

---

# The WoWThreads API Programmer’s Reference Manual

This manual provides a formal description of the public interface exported by the WoWThreads and WoWThreadsLib libraries. It is intended to be used alongside the Programmer’s Guide. Whereas the Programmer’s Guide explains *why* WoWThreads works the way it does, this manual explains *what* each API entry point does, *how* it behaves, and *how* it should be used. It is written for developers who require precise, technical information about the WoWThreads execution model, namespace conventions, and error‑handling semantics.

---

## The WoWThreads Execution Model for Developers

WoWThreads implements a **cooperative, asynchronous multitasking model** built on top of Lua’s coroutine system. It does *not* provide parallel execution, preemption, or OS‑level concurrency. Instead, it provides a deterministic scheduling layer that allows addon developers to structure logic as independent tasks (“threads”) that run over time without blocking the game client.

### 1. Control Flow: Client Context vs Thread Context

WoWThreads distinguishes between two execution contexts:

- **Client Context** — Code executed directly by WoW.exe via `lua_pcall()`.  
  - Event handlers (`OnEvent`) run in client context.  
  - Execution is synchronous: WoW.exe must wait until the handler returns.  
  - No coroutines are resumed in this context.  
  - Event handlers may send signals to threads but must return immediately.

- **Thread Context** — Code executed inside a coroutine managed by WoWThreads.  
  - Thread functions run only when resumed by the scheduler.  
  - Execution is asynchronous: WoW.exe does *not* wait for thread completion.  
  - Threads yield voluntarily using `thread:yield()`.  
  - Control returns to the scheduler, not to WoW.exe.

This separation ensures that WoWThreads never blocks the game client and never interferes with the event loop.

### 2. The Scheduler and the Frame Loop

WoWThreads installs its scheduler in an `OnUpdate` handler. This handler fires once per frame (typically every 16.67 ms). During each frame, the scheduler:

1. Decrements each thread’s tick counter.  
2. Checks signal queues for pending signals.  
3. Determines which threads are runnable.  
4. Resumes runnable threads via `coroutine.resume()`.  
5. Processes yields, completions, and errors.  
6. Returns control to WoW.exe.

If no threads are runnable, the scheduler performs minimal work and returns immediately. This ensures that WoWThreads imposes negligible overhead when idle.

### 3. Yielding and Timing

Each thread is created with a **yield interval** measured in clock ticks. When a thread calls `thread:yield()`, it is suspended for the configured number of ticks. The scheduler resumes the thread only when:

- its tick counter reaches zero,  
- the scheduler runs,  
- and the thread is not blocked by signals or termination.

This model provides deterministic timing without relying on OS timers or asynchronous callbacks.

### 4. Signals and Inter‑Thread Communication

Threads communicate using **signals**, which are inserted into a thread’s FIFO signal queue. A signal is a three‑element table:

```
{ sigNumber, sender_h, ...payload }
```

Key properties:

- Signals may be sent from client context or thread context.  
- Only threads may *receive* signals (`thread:getSignal()`).  
- Some signals (e.g., `SIG_ALERT`, `SIG_WAKEUP`) cause immediate resumption.  
- Payloads are untyped and may contain arbitrary Lua values.

Signals allow threads to coordinate work, implement worker pools, and respond to game events asynchronously.

### 5. Determinism and Safety

Because WoWThreads uses cooperative multitasking:

- No preemption occurs.  
- No race conditions exist.  
- No shared‑memory hazards exist.  
- No locks, semaphores, or atomic operations are required.  
- Execution order is deterministic and reproducible.

This makes WoWThreads safe for addon development and easy to reason about, even with many threads.

---

## Programming Best Practices

### Namespaces

All public API functions are exposed through the `thread:` namespace. This ensures:

- a clear separation between WoWThreads and addon code,  
- predictable naming conventions,  
- no accidental collisions with Blizzard API functions,  
- and a consistent interface for both WoWThreads and WoWThreadsLib.

Examples:

```lua
thread:create(...)
thread:yield(...)
thread:sendSignal(...)
thread:getSignal(...)
thread:sleep(...)
thread:terminate(...)
```

Addons should never access internal WoWThreads tables, constants, or scheduler internals. Only the documented `thread:` functions constitute the public interface.

### Error Handling

All WoWThreads API functions follow a consistent error‑handling convention:

- On success:  
  - The function returns a non‑nil value (often `true` or a thread handle).  
  - The error message is `nil`.

- On failure:  
  - The function returns `nil`.  
  - The second return value is an error message formatted as:

```
[file.lua:lineNumber] description of error, from functionName()
```

Examples:

```
[Signal.lua:56] Invalid or unknown signal - thread:getSignalName()
[Thread.lua:112] Attempt to resume a dead thread - thread:resume()
```

Addons should always check return values:

```lua
local thread_h, err = thread:create(60, myFunc)
if not thread_h then
    print(err)
end
```

This ensures that errors are surfaced cleanly and do not propagate silently.

---

## The WoWThreads API

*This section will contain the formal descriptions of all public API functions exported by WoWThreads and WoWThreadsLib. Each entry will include:*

- Function name  
- Namespace  
- Parameters  
- Return values  
- Error conditions  
- Execution context requirements  
- Side effects  
- Examples  
---

#### Signature:
thread_h, result = thread:create( yieldTicks, func [,...] )

#### Description:
Creates a reference (a handle from this point forward) to an executable thread. The reference is called a 
thread handle and is an opaque reference to the thread's coroutine and its attributes. The thread handle is used by the library's internals to manage and schedule the thread.

#### Parameters:
- yieldTicks (number). The duration of time the calling thread is to
be suspended. The time is specified in clock ticks.In WoW, a clock tick 
is the reciprocal of your system's frame rate. On my system, a clock tick 
is about 16.7 milliseconds (1/60). Therefore, 60 ticks is about 1 second.
- func (function). The function the thread is to execute. In 
POSIX and other thread environments, the thread function is often 
called the action routine.
- ... (varargs, optional), Additional arguments to be passed to the thread function.

#### Returns:
- Success: a valid thread handle is returned and the result is set to nil.
- Failure: nil is returned and the result parameter specifies an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local function greetings( greetingString )
            print( greetingString )
        end
        local thread_h, result = thread:create( 60, greetings, "Hello World" )
        if not thread_h then 
            print( result[1], result[2]) 
            return 
        end
```

#### Signature:
addonName, result = thread:getAddonName( [thread_h] )

#### Description:
Obtains the name of the addon within which the specified
thread was created. If thread_h is nil, the addon name of the calling
thread is returned. Because WoWThreads is a library of services shared
among multiple addons, the thread's addon name serves to distinguish
threads by the addon within which they were created. This may prove
useful when implementing shared callbacks.

#### Parameters:
- thread_h (thread handle, optional). A handle to the thread whose addon name is to be 
obtained. If not specified, the addon name of the calling thread will be returned.

#### Returns:
- Success: Returns the name of the specified thread's addon and the result is set to nil.
- Failure: the addonName is nil, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    -- This function is typically used to get the name of the addon for use when
        -- invoking a callback error handler.
        local addonName, result = thread:getAddonName( target_h )
        if addonName == nil then
            print( result[1], result[2])
        end
```

#### Signature:
thread:yield()

#### Description:
Suspends the calling thread for the number of ticks specified in the
yieldTicks parameter of the calling thread's create function. Note that thread:yield()
is always fatal if the caller is NOT a thread.

#### Parameters:
- None.

#### Returns:
- None

#### Usage:
```lua
    -- A simple function that waits (yields) for a specified period of 
        -- time. When it returns it checks for a signal.
        local function waitForSignal( signal )
            local DONE = false
            while not DONE do
                thread:yield()
                local sigEntry, result = thread:getSignal()
                if not sigEntry then
                    print( result[1], result[2])
                    return
                end
                if sigEntry[1] == SIG_TERMINATE then
                    DONE = true
                end
                if sigEntry[1] == signal then
                ... do something
                end
            end
        end
        -- Create a thread to execute the waitForSignal function.
        local thread_h, result = thread:create( 60, waitForSignal, signal )
        if thread_h == nil then 
            print( result[1], result[2]) 
            return 
        end
```

#### Signature:
local overhead, errorMsg = thread:getMetrics( thread_h )

#### Description:
Gets some some basic execution metrics; the runtime (ms) and
congestion (how long the thread had to wait to begin execution after having
been resumed). Note: at this point, only completed threads can be queried.

#### Parameters:
- thread_h (thread_handle): the thread handle whose metrics are to be returned.

#### Returns:
- Success: the thread's elapsed time and congestion metrics are returned and the result is set to nil.
- Failure: the runtime and congestion metrics are nil, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local elapsedTime, congestion, result = thread:getMetrics( thread_h )
        if runtime == nil then 
            print( result[1], result[2]) 
            return 
        end
```

#### Signature:
local ticksDelayed, errorMsg = thread:delay( ticks )

#### Description:
Suspends the calling thread for the specified number of ticks.

#### Parameters:
- ticks (number): the number of ticks the thread is to be delayed.
Note that when the delay has expired, the thread's specified yield ticks
will have been

#### Returns:
- Success: the actual number of ticks the thread was delayed. The result is set to nil.
- Failure: the handle is nil, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    -- delay a thread 1 minute
        local actualDelay, result = thread:delay( 3600 )
        if actualDelay == nil then 
            print( result[1], result[2]) 
            return 
        end
```

#### Signature:
thread:sleep()

#### Description:
Suspends the calling thread for an indeterminate amount of time.
Note, unlike thread:yield(), this call doesn't  return until awakened by receipt 
of a SIG_WAKEUP signal. Note, thread:sleep() is always fatal if the caller is not
a thread.

#### Parameters:
- None

#### Returns:
- Success: the thread's handle is returned when it regains the processor (i.e., after 
it is resumed), and the result parameter is set to nil.
- Failure: the handle is false and the result parameter contains an error message. This situation arises
when the target thread is not in the thread sleep queue.

#### Usage:
```lua
    local thread_h, result = thread:sleep()
        if thread_h == false then                 -- the thread was never put to sleep. 
            print( result[1], result[2])
        end
```

#### Signature:
thread_h, result = thread:getSelf()

#### Description:
Gets the handle of the calling thread.

#### Parameters:
- None

#### Returns:
- Success: returns a thread handle and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    
```

#### Signature:
threadId, result = thread:getId( [thread_h] )

#### Description:
Obtains the unique, numerical Id of the specified thread. Note,
if the thread parameter (thread_h) is nil, then the Id of the calling thread
is returned.

#### Parameters:
- thread_h (handle, optional): returns the numeric Id (unique) of the specified
thread. If not specified, the Id of the calling thread is returned.

#### Returns:
- Success: returns the numerical Id of the thread and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local threadId, result = thread:getId()
        if threadId == nil then 
            print( result[1], result[2]) 
            return 
        end
```

#### Signature:
local equal, result = thread:areEqual( h1, h2 )

#### Description:
Determines whether two thread handles are identical.

#### Parameters:
- h1 (handle): a thread handle
- h2 (handle); another thread handle

#### Returns:
- Success: returns either 'true' or 'false' and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local equal, result = thread:areEqual( H1, H2 )
        if equal == nil then 
            print( result) 
            return 
        end
```

#### Signature:
parent_h, result = thread:getParent( [thread_h] )

#### Description:
Gets the specified thread's parent. NOTE: if the 
the thread was created by the WoW client it will not have a parent

#### Usage:
```lua
    local parent_h, result = thread:getParent( thread_h )
        if parent_h == nil then 
            print( result[1], result[2])
        end
```

#### Signature:
childTable, result = thread:getChildThreads( [thread_h] )

#### Description:
Obtains a table of the handles of the specified thread's children.
Parameters
- thread_h (handle, optional). If nil, then a table of the child threads of the calling 
thread is returned.
Returns
- Success: returns a table of thread handles and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local childThreads, result = thread:getChildThreads( thread_h )
        if not childThreads then 
            print( result[1], result[2] ) 
        end
```

#### Signature:
state, result = thread:getState( [thread_h] )

#### Description:
Gets the execution state of the specified thread. A thread may be in one of 
three execution states: "suspended," "running," or "dead." Thread context required.
- Note: a dormant (sleeping) thread is always in the 'suspended' state.

#### Parameters:
- thread_h (handle, optional): if 'nil', then "running" is returned. NOTE: the calling
thread is, by definition, alwaysin the "running" state.

#### Returns:
- Success: returns the state of the specified thread ("suspended", "running", 
or "dead"). The returned result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local state, result = thread:getState( thread_h )
        if not state then
            print( result[1], result[2] )
        end
```

#### Signature:
value, result = thread:signalIsValid( signal )

#### Description:
Checks whether the specified signal is valid

#### Parameters:
- signalValue (number): signal to be sent.

#### Returns:
- Success: value = true is returned and the result is set to nil.
- Failure: value = false is returned and the signal is invalid.

#### Usage:
```lua
    local isValid, result = thread:signalIsValid( signal )
        if not isValid then 
            print( result[1], result[2] )
            return 
        end
```

#### Signature:
value, result = thread:sendSignal( target_h, signaValue [,...] )

#### Description:
Sends a signal to the specified thread. Note: a return value of
true only means the signal was delivered. It does mean the signal has been seen
by the target thread.

#### Parameters:
- thread_h (handle): The thread to which the signal is to be sent. 
- signalValue (number): the signal being sent.
- ... (varargs, optional) Data (including functions) to be passed to the receiving thread.

#### Returns:
1. If successful: value = true or false. A 'true' value means that...
- The signal was inserted into the target thread's signal queue, or
- The target thread was dormant and the signal was SIG_WAKEUP.
A value = false can mean one of two alternatives:
- The target thread was dead (completed or faulted).
- The target thread was dormant (sleeping) the signal was NOT SIG_WAKEUP.
2. If failed: nil is returned indicating the signal was not delivered. Usually
this means that the target's thread handle was was not found in the sleep queue. The 
result parameter contains an error message (result[1]) and a stack trace (result[2]).

#### Usage:
```lua
    local wasSent, result = thread:sendSignal( target_h, signalValue, data )
        if wasSent == nil then 
            print( result[1], result[2] )
            return 
        elseif wasSent == false then
            print( "target thread has completed or is dormant.")
        end
```

#### Signature:
local sigEntry, result = thread:getSignal()

#### Description:
The retrieval semantics of the thread's signal queue is FIFO. So, getting a
signal means getting the first signal in the calling thread's signal queue.
In other words, then signal that has been in the queue the longest. Note, thread:getSignal()
is always fatal if the caller is not a thread.

#### Parameters:
- sigEntry (table): sigEntry is a table containing 3 values:
```
result = {
    sigEntry[1] -- (number): the numerical signal, e.g., SIG_ALERT, SIG_TERMINATE, etc.
    sigEntry[2] -- (handle): the handle of the thread that sent the signal.
    sigEntry[3] -- (varargs): data
}
```

#### Returns:
- Success: returns a signal entry and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local sigInt, result = thread:getSignal()
        if not sigInt then 
            print( result[1, result[2] )
        end
    
        local signal = sigEntry[1]
        local sender_h = sigEntry[2]
        local data = signal[3]
        ... do something
```

#### Signature:
signalName, result = thread:getSignalName( signal )

#### Description:
Gets the string name of the specified signal value. for
example, when submitting the numerical constant, SIG_ALERT (11) the
service returns the string, "SIG_ALERT"
end
end

#### Parameters:
- signal (number): the numerical signal whose name is to be returned.

#### Returns:
- Success: returns the name associated with the signal value and the result is set to nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local signalName, result = thread:getSignalName( signal )
        if signalName == nil then print( errorMsg ) return end
```

#### Signature:
signalCount, result = thread:getNumPendingSignals()

#### Description:
Gets the number of pending signals for the calling thread.
Note, thread:getNumPendingSignals() is always fatal if the caller is not
a thread.

#### Parameters:
- None

#### Returns:
- Success: returns the number of the threads waiting to be retrieved (i.e., in
the thread's signal queue). The result parameter will be nil.
- Failure: nil is returned, and the result parameter contains an error message (result[1])
and a stack trace (result[2]).

#### Usage:
```lua
    local sigCount, result = thread:getNumPendingSignals( thread_h )
        if signalCount == nil then 
            print( result[1], result[2]) return end
```