--=================================================================================
-- Filename: WoWThreadsLib.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
WoWThreadsLib = WoWThreadsLib or {}

local core = ns.Core
local post  = ns.PostMessages
local utils = ns.UtilsLib
local L     = ns.Locales
local sig	= ns.SignalQueue

--=============== Create As A Libstub Library ===========
-- Configure WoWThreadsLib as a LibStub managed library
local _, localizedVersion, expansionName = core:getLibInfo()
local thread, oldVersion = LibStub:NewLibrary( "WoWThreadsLib", localizedVersion )
if not thread then return end  -- no upgrade needed
--=======================================================
--                                  LOCAL DATA
local CURRENTLY_RUNNING_THREAD = nil
local DEFAULT_YIELD_TICKS    = 1
local THREAD_SEQUENCE_ID     = 4 -- a number representing the order in which the thread was created

local threadControlBlock    = {} -- Table to hold all running and suspended threads
local conditionTable        = {} -- Table for threads waiting on a condition
local morgue                = {}

local CLOCK_TICK_INTERVAL    = 1/GetFramerate() -- approx 16.7 ms on a 60Hz system
local WoWThreadsStarted      = false
local debuggingIsEnabled     = true
local dataCollectionIsEnabled = true
-- =====================================================================
--                      NUMERIC CONSTANTS
-- =====================================================================
local TH_COROUTINE          = 1 -- the coroutine created to execute the thread's function
local TH_COROUTINE_ARGS     = 2
local TH_UNIQUE_ID          = 3 -- a number representing the order in which the thread was created
local TH_SIGNAL_QUEUE       = 4 -- a table of all currently pending signals
local TH_YIELD_TICKS        = 5 -- the number of clock ticks for which a thread must suspend after a yield.
local TH_REMAINING_TICKS    = 6
local TH_RESUMPTIONS        = 7 -- the number of times a thread yields
local TH_CHILDREN           = 8
local TH_PARENT_HANDLE      = 9
local TH_ADDON_NAME       	= 10
local TH_ELAPSED_TICKS		= 11
local TH_TIME_CREATED       = 12 -- timestamped from debugprofilestop()
local TH_TIME_COMPLETED     = 13 -- timestamped from debugprofilestop()
local TH_NUM_HANDLE_ELEMENTS = TH_TIME_COMPLETED

-- Each thread has a signal queue. Each element in the signal queue
-- consists of 3 elements: the signal, the sending thread, and data. 
-- Example: sigTable = {signalValue, sender_h, ... }
--
-- These constants are the signal values found in sigTable[1]
thread.SIG_READY            = 1 -- info: thread is ready to receive something
thread.SIG_CALLBACK         = 2  -- info: Signal entry contains a callback function in Sig[3]
thread.SIG_ALERT            = 3 -- schedule for immediate execution
thread.SIG_CONDITION_MET    = 4 -- resumes a thread waiting for a condition of occur
thread.SIG_COMPLETE         = 5
thread.SIG_TERMINATE        = 6 -- thread terminates itself upon receipt.
thread.SIG_NONE_PENDING     = 7 -- signal queue is empty.

thread.signalTable = {
    SIG_READY           = thread.SIG_READY,
    SIG_CALLBACK        = thread.SIG_CALLBACK,
    SIG_ALERT           = thread.SIG_ALERT,
    SIG_CONDITION_MET   = thread.SIG_CONDITION_MET,
    SIG_COMPLETE        = thread.SIG_COMPLETE,
    SIG_TERMINATE       = thread.SIG_TERMINATE,
    SIG_NONE_PENDING    = thread.SIG_NONE_PENDING,
}

local SIG_READY             = thread.SIG_READY
local SIG_CALLBACK          = thread.SIG_CALLBACK
local SIG_ALERT             = thread.SIG_ALERT
local SIG_CONDITION_MET     = thread.SIG_CONDITION_MET
local SIG_COMPLETE          = thread.SIG_COMPLETE
local SIG_TERMINATE         = thread.SIG_TERMINATE
local SIG_NONE_PENDING      = thread.SIG_NONE_PENDING

thread.signalNameTable = {
    "SIG_READY",
    "SIG_CALLBACK",
    "SIG_ALERT",
    "SIG_CONDITION_MET",
    "SIG_TERMINATE",
    "SIG_COMPLETE",
    "SIG_NONE_PENDING"
}
local signalNameTable = thread.signalNameTable

--                          LOCAL FUNCTIONS 
local function dbgLog( prefix, msg )
    if debuggingIsEnabled then
         local logMsg = string.format("[LOG]  %s %s\n", prefix, msg )
         print( utils:dbgPrefix(), logMsg )
        post:message( logMsg )
    end
end

local function coroutineIsDead(H)
    local dead = false

    local status = coroutine.status( H[TH_COROUTINE])
    if status == "dead" then
        dead = true
    end
    return dead
end
local function handleIsInMorgue( H )
    if #morgue == 0 then 
        return nil 
    end

    for _, entry in ipairs(morgue) do
        if entry[TH_UNIQUE_ID] == H[TH_UNIQUE_ID] then
            return H
        end
    end
	return nil
end
local function wakeupThread(H)
    if #conditionTable == 0 then 
        return nil, L["THREAD_NOT_FOUND"]
    end

    for i, entry in ipairs(conditionTable) do
        if entry[TH_UNIQUE_ID] == H[TH_UNIQUE_ID] then
            table.remove( conditionTable, i )
            table.insert( threadControlBlock, H )			        
            H[TH_REMAINING_TICKS] = 1
            return H, nil
        end
    end
    return nil, L["THREAD_NOT_FOUND"]
end
local function inConditionTable( H )
	if #conditionTable == 0 then return nil end

	for _, entry in ipairs( conditionTable ) do
		if entry[TH_UNIQUE_ID] == H[TH_UNIQUE_ID] then
			return H
		end
	end
	return nil
end
-- deprecated
local function getHandleOfCallingThread()
    return CURRENTLY_RUNNING_THREAD
end
local function createHandle( addonName, parent_h, yieldTicks, func, ...)

    if yieldTicks < DEFAULT_YIELD_TICKS then
        yieldTicks = DEFAULT_YIELD_TICKS
    end

    THREAD_SEQUENCE_ID = THREAD_SEQUENCE_ID + 1
    local H = {
        [TH_COROUTINE]          = coroutine.create(func),
        [TH_COROUTINE_ARGS]     = {...},
        [TH_UNIQUE_ID]          = THREAD_SEQUENCE_ID,
        [TH_SIGNAL_QUEUE]       = sig.new(),
        [TH_YIELD_TICKS]        = yieldTicks,
        [TH_REMAINING_TICKS]    = 1,
        [TH_ELAPSED_TICKS]      = 0,
        [TH_RESUMPTIONS]        = 0,
        [TH_CHILDREN]           = {},
        [TH_PARENT_HANDLE]      = parent_h,
        [TH_ADDON_NAME]         = ADDON_NAME,
        [TH_TIME_CREATED]       = debugprofilestop(),
        [TH_TIME_COMPLETED]     = 0,
    }
    if parent_h ~= nil then
        table.insert( parent_h[TH_CHILDREN], H)
    end

    return H
end

-- returns true if successful, false otherwise + errorMsg
local function moveToMorgue( H, normalCompletion )
	local logMsg = nil
    for i, handle in ipairs( threadControlBlock ) do
        if H[TH_UNIQUE_ID] == handle[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            if normalCompletion then
                table.insert( morgue, H)
                H[TH_TIME_COMPLETED] = debugprofilestop()
                logMsg = string.format("Thread[%d] Normal termination.", H[TH_UNIQUE_ID] )
                dbgLog( utils:dbgPrefix(), logMsg )
            else
                H[TH_COROUTINE] = nil
                utils:dbgPrefix()
                logMsg = string.format("*** ABNORMAL termination *** %s Thread[%d] died a horrible death.\n", H[TH_UNIQUE_ID])
                dbgLog( prefix, logMsg )
            end
        end
        -- don't need this anymore.
    end
end
-- returns true if successful, false otherwise + errorMsg
local function moveToConditionTable( H )
    local errorMsg = nil

    -- Remove thread from TCB and insert it into the condition table
    for i, entry in ipairs(threadControlBlock) do
        if H[TH_UNIQUE_ID] == entry[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            table.insert( conditionTable, H )
            dbgLog( utils:dbgPrefix(), string.format("Thread[%d] removed from TCB, inserted into condition table.\n", H[TH_UNIQUE_ID]) )
            return true, nil
        end
    end
    local logMsg = string.format("Thread[%d] not found in the condition table.", H[TH_UNIQUE_ID])
    dbgLog( utils:dbgPrefix(), logMsg )
    return false, L["THREAD_NOT_FOUND"]
end

local function handleIsValid(H)
    local isValid = true

    if H == nil then
        return false, L["PARAMETER_NIL"]
    end

    if type(H) ~= "table" then
        return false, L["INVALID_TYPE"]
    end
    if type(H[TH_SIGNAL_QUEUE]) ~= "table" then
        return false, L["INVALID_TYPE"]
    end
    if type(H[TH_COROUTINE]) ~= "thread" then
        utils:dbgPrint( type( H[TH_COROUTINE]))
        return false, L["INVALID_TYPE"]
    end

    return true, nil
end
local function signalIsValid(signal)
    if signal == nil then
        return false, L["SIGNAL_IS_NIL"]
    end

    if type(signal) ~= "number" then
        return false, L["SIGNAL_INVALID_TYPE"]
    end

    if signal < SIG_READY or signal > SIG_NONE_PENDING then
        return false, L["SIGNAL_OUT_OF_RANGE"]
    end

    return true, nil
end
-- new resume function
local function resumeThread(H)
    local co   = H[TH_COROUTINE]
    local args = H[TH_COROUTINE_ARGS] or {}
    H[TH_RESUMPTIONS] = H[TH_RESUMPTIONS] + 1

    -- this will be the running thread once resume is complete
    CURRENTLY_RUNNING_THREAD = H
            -- Normal resume
    local logMsg = string.format("Thread[%d] resumed.", H[TH_UNIQUE_ID])
    dbgLog( utils:dbgPrefix(), logMsg )

    -- Error handler for xpcall
    local function errorHandler(err)
        return {
            ok      = false,
            type    = "lua_error",
            message = tostring(err),
            stack   = debugstack(2)
        }
    end

    --------------------------------------------------------------------
    -- Run coroutine.resume under xpcall and normalize results
    --------------------------------------------------------------------
    local raw = { xpcall(coroutine.resume, errorHandler, co, unpack(args)) }

    CURRENTLY_RUNNING_THREAD = nil

    local ok        = raw[1]   -- xpcall succeeded?
    local resumeOK  = raw[2]   -- coroutine.resume succeeded?

    -- Collect all coroutine return values (if any)
    local values = {}
    for i = 3, #raw do
        values[#values+1] = raw[i]
    end

    --------------------------------------------------------------------
    -- Normalize into a unified result object
    --------------------------------------------------------------------
    local result = {}

    if not ok then
        -- xpcall caught a Lua error inside coroutine.resume
        local errObj = raw[2]  -- this is the table returned by errorHandler
        result.ok      = false
        result.type    = "xpcall_error"
        result.message = errObj.message
        result.stack   = errObj.stack

    elseif not resumeOK then
        -- coroutine.resume returned false → coroutine error
        result.ok      = false
        result.type    = "coroutine_error"
        result.message = raw[3] or "unknown coroutine error"
        result.stack   = debugstack(2)

    else
        -- coroutine resumed normally
        result.ok     = true
        result.values = values
    end

    --------------------------------------------------------------------
    -- Handle thread lifecycle transitions
    --------------------------------------------------------------------
    if not result.ok then
        local logMsg = string.format(
            "Thread[%d] died a horrible death (%s): %s\n%s",
            H[TH_UNIQUE_ID],
            result.type,
            tostring(result.message),
            tostring(result.stack)
        )
        dbgLog( utils:dbgPrefix(), logMsg )
        moveToMorgue(H, false)
        return false, result.message
    end

    -- Coroutine completed?
    if coroutine.status(co) == "dead" then
        local logMsg = string.format("Thread[%d] has completed", H[TH_UNIQUE_ID])
        dbgLog( utils:dbgPrefix(), logMsg )
        moveToMorgue(H, true)
        return true, nil
    end
    return true, nil
end

local function scheduleThreads()
    if #threadControlBlock == 0 then
        return
    end

    for i = #threadControlBlock, 1, -1 do
        local H = threadControlBlock[i]
        local co = H[TH_COROUTINE]
        if coroutine.status(co) == "suspended" then
            H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1
            if H[TH_REMAINING_TICKS] <= 0 then
                H[TH_REMAINING_TICKS] = H[TH_YIELD_TICKS]
				---------------------------------------
                local success, errorMsg = resumeThread(H)
                ---------------------------------------
                if not success then
                    local logMsg = string.format("Thread[%d] error: %s", utils:dbgPrefix(), H[TH_UNIQUE_ID], errorMsg )
                    dbgLog( utils:dbgPrefix(), logMsg )
				end
            end
        end
    end
end

local function startTimer( tickInterval )
    scheduleThreads()
        C_Timer.After(
            tickInterval,
            function()
                startTimer(tickInterval)
            end
        )
end

--================================================================
--==================== PUBLIC (EXPORTED) SERVICES ================
--================================================================
local running = false
function thread:libInit()
    if running == false then
        startTimer(CLOCK_TICK_INTERVAL)
        running = true
    end
    return running
end

function thread:mgmtThreadsInitialize()
    return WoWThreadsStarted
end

function thread:debuggingIsEnabled()
    return debuggingIsEnabled
end
function thread:enableDebugging()
    debuggingIsEnabled = true
end
function thread:disableDebugging()
    debuggingIsEnabled = false
end
function thread:dataCollectionIsEnabled()
    return dataCollectionIsEnabled
end
function thread:enableDataCollection()
    dataCollectionIsEnabled = true
end
function thread:disableDataCollection()
   dataCollectionIsEnabled = false
end
local function formatErrorMsg( prefix,  errorMsg, functionName )
    if functionName == nil then
        errorMsg = string.format( "%s %s.\n", prefix,  errorMsg)
    else
        errorMsg = string.format( "%s %s | Caller: %s\n", utils:dbgPrefix(),  errorMsg, functionName )
    end
    return errorMsg
end

--[[@Begin
Signature:
    thread_h, errorMsg = thread:create(yieldTicks, threadFunction [, ...])

Description:
    Creates a new executable thread and returns its thread handle (thread_h).
    The thread handle is the opaque reference used internally by WoWThreadsLib
    to manage, schedule, and track the coroutine associated with the thread.

Parameters:
    - yieldTicks (number)
        The number of scheduler ticks the new thread will wait before its first
        execution. A scheduler tick corresponds to one frame update. On a 60 FPS
        system, one tick is approximately 16.7 milliseconds. For example, 60 ticks
        is roughly one second.

    - threadFunction (function)
        The function the thread will execute. In POSIX terminology, this is the
        thread’s “action routine.” WoWThreadsLib invokes this function inside a
        coroutine context managed by the library.

    - ... (varargs, optional)
        Additional arguments to pass to the threadFunction when the thread begins
        execution.

Returns:
    - Success:
        A valid thread handle (thread_h) and nil for errorMsg.

    - Failure:
        A nil thread handle and an error message describing the failure.
        Error messages include:
            • the file name
            • the line number
            • the diagnostic message
            • the calling function

        Example:
            If FooBar.lua calls thread:create() at line 45 with an invalid
            yieldTicks value, the error message may look like:

            "[FooBar.lua:45] Unknown or unexpected data type | Caller: thread:create()"

        This indicates that thread:create() rejected one of the arguments due to
        an invalid type.

Usage Example:
    local thread_h, errorMsg = thread:create(60, greetings, "Hello World")
    if not thread_h then
        print(errorMsg)
        return
    end
@End]]

function thread:create( yieldTicks, someFunction,... )
    local fname = "thread:create()"
    local parent_h = nil
    local errorMsg = nil

    if type( yieldTicks) ~= "number" then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), L["INVALID_TYPE"], fname )
        return nil, errorMsg
    end

    if type(someFunction) ~= "function" then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), L["PARAMETER_NIL"], fname )
        return nil, errorMsg
    end
    parent_h = getHandleOfCallingThread()

	-- If parent_h is nil, the caller must be the WoW game client whose 
	-- addon name can be extracted from the stack trace.
    if parent_h == nil then 
        addonName = ADDON_NAME
    else
        -- the caller  is a thread. Therefore, it has a parent thread from which the addon name is obtained.
        addonName = parent_h[TH_ADDON_NAME]
    end

    local H = createHandle( addonName, parent_h, yieldTicks, someFunction, ... )

    table.insert( threadControlBlock, H )
    if H[TH_UNIQUE_ID] == 5 then
        post:message( tostring( debugstack(2)))
    end
    local logMsg = string.format("Thread[%d] (ticks %d) inserted into TCB.", H[TH_UNIQUE_ID], H[TH_YIELD_TICKS])
    dbgLog( utils:dbgPrefix(),  logMsg )
    return H, nil
end

--[[@Begin
Signature:
    addonName, errorMsg = thread:getAddonName([thread_h])

Description:
    Returns the name of the addon that owns the specified thread. This function is
    primarily used in the shared-library version of WoWThreadsLib, where threads
    created by multiple addons may coexist. Knowing the owning addon allows the
    scheduler, error system, and debugging tools to correctly attribute thread
    activity.

Parameters:
    - thread_h (thread handle, optional)
        A valid thread handle previously returned by thread:create(). If omitted,
        the addon name of the calling thread is returned.

Returns:
    - Success:
        The name of the addon that created the thread, and errorMsg is nil.

    - Failure:
        addonName is nil, and errorMsg contains an error message describing the
        failure. Error messages follow the same format as those returned by
        thread:create(), including file name, line number, diagnostic text, and
        the calling function.

Usage Example:
    local addonName, errorMsg = thread:getAddonName(target_h)
    if addonName == nil then
        print(errorMsg)
    end
@End]]
function thread:getAddonName( thread_h )
    if thread_h == nil then
        thread_h = CURRENTLY_RUNNING_THREAD
    end
    return thread_h[TH_ADDON_NAME], nil
end

--[[@Begin
Signature: thread:yield()
Description: Suspends the calling thread for the number of ticks specified in the
yieldTicks parameter of the calling thread's create function. Note that thread:yield()
is always fatal if the caller is NOT a thread.
Parameters:
- None.
Returns:
- None
Usage:
    local DONE = false
	while not DONE do
		thread:yield()  -- suspend the thread for its specified yieldTicks interval
		local sigEntry = thread:getSignal()
		if sigEntry[1] == SIG_TERMINATE then
			DONE = true
        else
            -- Do some work
        end	
	end
@End]]
function thread:yield()
    CURRENTLY_RUNNING_THREAD[TH_YIELD_TICKS] = CURRENTLY_RUNNING_THREAD[TH_YIELD_TICKS] + 1
    coroutine.yield()
    H = CURRENTLY_RUNNING_THREAD
    H[TH_RESUMPTIONS] = H[TH_RESUMPTIONS] + 1

end

-- Signature: hasCompleted, errorMsg - thread:hasCompleted( thread_h )
function thread:hasCompleted( thread_h )
    local hasCompleted = true
    local fname = "thread:hasCompleted()"
    local errorMsg = nil

    if thread_h == nil then
        errorMsg = formatErrorMsg( utils:dbgPrefix(),  L["THREAD_HANDLE_NIL"], fname )
        return false, errorMsg
    end

    local isValid, errorMsg = handleIsValid(thread_h)
    if not isValid then
        errorMsg = formatErrorMsg(utils:prefix(), errorMsg, fname)
        return false, errorMsg
    end

    local hasCompleted = handleIsInMorgue( thread_h )
	return hasCompleted, errorMsg
end

--[[@Begin
local metrics = { threadId, lifeTimeMS, lifetimeTicks, yieldReumptions}
Signature: metrics, errorMsg  = thread:getMetrics( thread_h )
Description: Gets some some basic execution metrics; the runtime (ms) and   
congestion (how long the thread had to wait to begin execution after having
been resumed). Note: at this point, only completed threads can be queried.
Parameters:
- thread_h (thread_handle): the thread handle whose metrics are to be returned.
Returns:
- metrics (table): containing the following elements
- metrics.threadId: The thread's unique identifier
- metrics.lifeTimeMS: total time thread was running in milliseconds.
- metrics.lifeTimeTicks: total time thread was running in clock ticks.
- metrics.yieldTicks: The thread's yield interval is ticks (1/framerate)
- metrics.resumptions: number of times the thread resumed from a yield.
- errorMsg - nil if successful otherwise r[1] is an error message, r[2] is the function, r[3] is a stack trace.
Usage:
    local metrics,errorMsg = thread:getMetrics( thread_h )
@End]]
function thread:getMetrics( thread_h )
    local fname = "thread:getMetrics()"
    local errorMsg = nil

    if thread_h == nil then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), L["THREAD_HANDLE_NIL"], fname )
        return nil, errorMsg
    end

    local isValid = handleIsValid(thread_h)
    if not isValid then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), L["THREAD_HANDLE_INVALID"], fname )
        return nil, errorMsg
    end

    if not handleIsInMorgue( thread_h ) then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), L["THREAD_NOT_COMPLETED"], fname )
        return nil, errorMsg
    end

	local metricsTable = {}
	metricsTable.threadId 		= thread_h[TH_UNIQUE_ID]
	metricsTable.Lifetime 		= thread_h[TH_TIME_COMPLETED] - thread_h[TH_TIME_CREATED]
	metricsTable.elapsedTicks	= thread_h[TH_ELAPSED_TICKS]
	metricsTable.yieldTicks 	= thread_h[TH_YIELD_TICKS]
	metricsTable.resumptions 	= thread_h[TH_RESUMPTIONS]

	return metricsTable 
end

--[[@Begin
Signature: local ticksDelayed, errorMsg = thread:delay( ticks )
Description: Suspends the calling thread for the specified number of ticks. 
Note: when signaled, delayed threads respond as normal. Note: thread:delay()
is always fatal if the caller is not a thread.
Parameters:
- ticks (number): the number of ticks the thread is to be delayed.
Note that when the delay has expired, the thread's specified yield ticks
will have been
Returns:
- Success: the actual number of ticks the thread was delayed. The errorMsg is set to nil.
- Failure: the handle is nil, and the errorMsg parameter contains an error message (errorMsg[1])
and a stack trace (errorMsg[2]).
Usage:
    -- delay a thread 1 minute
    local actualDelay, errorMsg = thread:delay( 3600 )
    if actualDelay == nil then 
        print( errorMsg[1], errorMsg[2]) 
        return 
    end
@End]]
function thread:delay(delayTicks)
    local fname = "thread:delay()"
	local errorMsg = nil
    if not delayTicks or type(delayTicks) ~= "number" then
        errorMsg = formatErrorMsg(utils:dbgPrefix(), L["INVALID_TYPE"], fname)
		return false, errorMsg
    end

    local H = getHandleOfCallingThread()
    
    -- Set delay and remove from TCB
    H[TH_REMAINING_TICKS] = delayTicks
    coroutine.yield()
    return true, nil
end

--[[@Begin
Signature:
    payload, errorMsg = thread:conditionWait()

Description:
    Suspends the calling thread indefinitely until a condition is met.
    A thread in condition-wait state is removed from the runnable queue
    and does not receive normal signals. It is resumed only when another
    thread sends SIG_CONDITION_MET to it. The SIG_CONDITION_MET signal
    may include a payload describing the condition that was satisfied.

    This service may only be invoked by the running thread. The library
    verifies that the calling context is valid; no thread may place
    another thread into condition-wait state.

Parameters:
    None.

Returns:
    Success:
        - payload: The condition payload delivered with SIG_CONDITION_MET.
                   This may contain event information, data structures,
                   or any context the signaling thread provides.
        - errorMsg: nil

    Failure:
        - payload: nil
        - errorMsg: A localized error message describing the failure.
                    Failure occurs when:
                        * The calling thread cannot be identified.
                        * The thread is not found in the condition-wait table
                          upon resumption (internal state corruption).
                        * A signal other than SIG_CONDITION_MET resumes the
                          thread.
    Usage Example:
    local payload, errorMsg = thread:conditionWait()
    if not payload then
        print(errorMsg)
        return
    end

    -- Process the condition that resumed the thread
    print("Condition met:", payload.condition)
    -- Additional payload fields may be accessed as needed.
@End]]
function thread:conditionWait()
    local fname = "thread:conditionWait()"
	local errorMsg = nil
	local success = true

	H = CURRENTLY_RUNNING_THREAD
	if not H then
		errorMsg = formatErrorMsg( utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname )
		return nil, errorMsg
	end
	errorMsg = formatErrorMsg( utils:dbgPrefix(), L["THREAD_NOT_FOUND"], fname)
    moveToConditionTable( H )
	return nil, errorMsg
end
--[[@Begin
Signature: thread_h, errorMsg = thread:getSelf()
Description: Gets the handle of the calling thread.
Parameters:
- None
Returns:
- Success: returns a thread handle and the errorMsg is set to nil.
- Failure: nil is returned, and the errorMsg parameter contains an error message (errorMsg[1])
and a stack trace (errorMsg[2]).
Usage:
@End]]
function thread:getSelf()
    local fname = "thread:getSelf()"
	local H = getHandleOfCallingThread()
    if not H then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname )
        return nil, errorMsg
    end
    return H, nil
end

--[[@Begin
Signature: threadId, errorMsg = thread:getId( [thread_h] )
Description: Obtains the unique, numerical Id of the specified thread. Note,
if the thread parameter (thread_h) is nil, then the Id of the calling thread
is returned.
Parameters:
- thread_h (handle, optional): returns the numeric Id (unique) of the specified
thread. If not specified, the Id of the calling thread is returned.
Returns:
- Success: returns the numerical Id of the thread and the errorMsg is set to nil.
- Failure: nil is returned, and the errorMsg parameter contains an error message (errorMsg[1])
and a stack trace (errorMsg[2]).
Usage:
    local threadId, errorMsg = thread:getId()
    if threadId == nil then 
        print( errorMsg[1], errorMsg[2]) 
        return 
    end
@End]]
function thread:getId(thread_h)
    local fname = "thread:getId()"
    local isValid = true
    local errorMsg = nil

    if thread_h == nil then
		thread_h = getHandleOfCallingThread()
        if thread_h == nil then
            errorMsg = formatErrorMsg( utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname )
            return nil, errorMsg
        end
    end
    isValid, errorMsg = handleIsValid(thread_h)
    if not isValid then
        errorMsg = string.format("%s %s, %s.\n", utils:dbgPrefix(), L["THREAD_HANDLE_NIL"], fname )
		return nil, errorMsg
    end
    
    return thread_h[TH_UNIQUE_ID], nil
end

--[[@Begin
Signature: local equal, errorMsg = thread:areEqual( h1, h2 )
Description: Determines whether two thread handles are identical.
Parameters: 
- h1 (handle): a thread handle
- h2 (handle); another thread handle
Returns: 
- Success: returns either 'true' or 'false' and the errorMsg is set to nil.
- Failure: nil is returned, and the errorMsg parameter contains an error message (errorMsg[1])
and a stack trace (errorMsg[2]).
Usage:
    local equal, errorMsg = thread:areEqual( H1, H2 )
    if equal == nil then 
        print( errorMsg) 
        return 
    end
@End]]
function thread:areEqual(H1, H2)
    local fname = "thread:areEqual()"
    local areEqual = false
    local errorMsg = nil
    local isValid = false
    
    -- check that neither handle is nil
    if H1 == nil then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), L["THREAD_HANDLE_NIL"], fname )
        return nil, errorMsg
    end
    if H2 == nil then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), L["THREAD_HANDLE_NIL"],fname)
        return nil, errorMsg
    end

    isValid  = handleIsValid(H1)
    if not isValid then
        errorMsg = formatErrorMsg(utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname )
        return nil, errorMsg
    end
    isValid  = handleIsValid(H2)
    if not isValid then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname )
        return nil, errorMsg
    end

    return H1[TH_UNIQUE_ID] == H2[TH_UNIQUE_ID], nil
end

--[[@Begin
Signature: parent_h, errorMsg = thread:getParent( [thread_h] )
Description: Gets the specified thread's parent. NOTE: if the 
the thread was created by the WoW client it will not have a parent
Note: In this document all threads created by thw WoW client (WoW.exe)
are termed primary threads.
Parameters
- thread_h (handle, optional): if nil, then the calling thread's parent is returned.
Returns
- Success: returns the handle of the parent thread and the errorMsg is set to nil.
- Failure: nil is returned, and the errorMsg parameter contains an error message (errorMsg[1])
and a stack trace (errorMsg[2]).
Usage:
    local parent_h, errorMsg = thread:getParent( thread_h )
    if parent_h == nil then 
        print( errorMsg[1], errorMsg[2])
    end
@End]]
function thread:getParent( thread_h )
    local fname = "thread:getParent()"
	local errorMsg = nil
    local errorMsg = nil
    if thread_h == nil then    
		thread_h = getHandleOfCallingThread()
    end

	return thread_h
end

--[[@Begin
Signature: childTable, errorMsg = thread:getChildThreads( [thread_h] )
Description: Obtains a table of the handles of the specified thread's children.
Parameters
- thread_h (handle, optional). If nil, then a table of the child threads of the calling 
thread is returned.
Returns
- Success: returns a table of thread handles and the errorMsg is set to nil.
- Failure: nil is returned, and the errorMsg parameter contains an error message (errorMsg[1])
and a stack trace (errorMsg[2]).
Note: a nil, nil return means that the thread has no children.
Usage:
    local childThreads, errorMsg = thread:getChildThreads( thread_h )
    if not childThreads then 
        print( errorMsg[1], errorMsg[2] ) 
    end
@End]]
function thread:getChildThreads(thread_h)
    local fname = "thread:getChildThreads()"
    local errorMsg = nil
    local errorMsg = nil

    if thread_h == nil then
        thread_h  = getHandleOfCallingThread()
    end

    local isValid = handleIsValid( thread_h )
    if not isValid then
        errorMsg = formatErrorMsg( utils:dbgPrefix(),  L["NO_THREAD_CONTEXT"], fname )
        return nil, errorMsg
    end

    return thread_h[TH_CHILDREN], nil
end
--[[@Begin
Signature: value, errorMsg = thread:isSignalValid( signal )
Description: Checks whether the specified signal is valid
Parameters: 
- signalValue (number): signal to be sent.
Returns:
- Success: value = true is returned and the errorMsg is set to nil.
- Failure: value = false is returned and the signal is invalid.
Usage:
    local isValid, errorMsg = thread:isSignalValid( signal )
    if not isValid then 
        print( errorMsg[1], errorMsg[2] )
        return 
    end
@End]]
function thread:isSignalValid( signal )
	local fname = "thread:isSignalValid()"
	local errorMsg = nil	
    local isValid, errorMsg = signalIsValid( signal )
	if not isValid then
		errorMsg = formatErrorMsg(utils:dbgPrefix(), errorMsg, fname )
	end
	return isValid, errorMsg
end

--[[@Begin
Signature: value, errorMsg = thread:sendSignal( target_h, signaValue [,...] )
Description: Sends a signal to the specified thread. Note: a return value of
true only means the signal was delivered. It does mean the signal has been seen
by the target thread.
Parameters: 
- thread_h (handle): The thread to which the signal is to be sent. 
- signalValue (number): the signal being sent.
- ... (varargs, optional) Data (including functions) to be passed to the receiving thread.
Returns:
1. If successful: value = true or false. A 'true' value means that...
- The signal was inserted into the target thread's signal queue.
A value = false can mean one of two alternatives:
- The target thread was dead (completed or faulted).
2. If failed: nil is returned indicating the signal was not delivered. 
Usage:
    local wasSent, errorMsg = thread:sendSignal( target_h, thread.signal, data )
    if wasSent == nil then 
        print( errorMsg[1], errorMsg[2] )
        return 
    elseif wasSent == false then
        print( "target thread has completed or is dormant.")
    end
@End]]
function thread:sendSignal( target_h, signal, ... )
    local fname = "thread:sendSignal()"
    local wasSent = true
    local errorMsg = nil
    local isValid = true
	
    -- check that the target handle is valid
    if target_h == nil then
        errorMsg = formatErrorMsg(utils:dbgPrefix(), L["THREAD_HANDLE_NIL"], fname )
        return false, errorMsg
	end

	if type( target_h) ~= "table" then
        errorMsg = string.format("%s %s. %s.\n", utils.dbgPrefix(), L["INVALID_TYPE"], fname)
        return false, errorMsg
    end
    
	-- is the target is running in thread context?
    isValid, errorMsg = handleIsValid( target_h )
    if not isValid then
        errorMsg = formatErrorMsg(utils:dbgPrefix(), errorMsg, fname )
        return false, errorMsg
    end
    isValid, errorMsg = signalIsValid(signal)
	if not isValid then
        errorMsg = formatErrorMsg(utils:dbgPrefix(), errorMsg, fname )
        return false, errorMsg
    end
    -- User code cannot send SIG_NONE_PENDING signals.
	if signal == SIG_NONE_PENDING then
        errorMsg = formatErrorMsg(utils:dbgPrefix(), L["SIGNAL_INVALID_OPERATION"], fname )
        return false, errorMsg
    end
    -- because dead threads cannot receive signals
	if handleIsInMorgue( target_h ) then
        return false, L["THREAD_HAS_COMPLETED"]
    end
	-- Initialize and insert an entry into the recipient thread's signalTable
    local sender_h = getHandleOfCallingThread()
	local sigEntry = {signal, sender_h, ... }

    target_h[TH_SIGNAL_QUEUE]:enqueue(sigEntry)

	if signal == SIG_ALERT then
        target_h[TH_REMAINING_TICKS] = 1
    end

	return wasSent, errorMsg
end
--[[@Begin
Signature: local sigEntry, errorMsg = thread:getSignal()
Description: The retrieval semantics of the thread's signal queue is FIFO. So, getting a
signal means getting the first signal in the calling thread's signal queue.
In other words, then signal that has been in the queue the longest. Note, thread:getSignal()
is always fatal if the caller is not a thread.
Parameters:
- sigEntry (table): sigEntry is a table containing 3 values:
```
errorMsg = {
    sigEntry[1] -- (number): the numerical signal, e.g., SIG_ALERT, SIG_TERMINATE, etc.
    sigEntry[2] -- (handle): the handle of the thread that sent the signal.
    sigEntry[3] -- (varargs): data
}
```
Returns:
- Success: returns a signal entry and the errorMsg is set to nil.
- Failure: nil is returned, and the errorMsg parameter contains an error message (errorMsg[1])
and a stack trace (errorMsg[2]).
Usage:
    local sigInt, errorMsg = thread:getSignal()
    if not sigInt then 
        print( errorMsg[1, errorMsg[2] )
    end

    local signal = sigEntry[1]
    local sender_h = sigEntry[2]
    local data = signal[3]
    ... do something
@End]]
function thread:getSignal()
    local fname 	= "thread:getSignal()"
    local sigEntry 	= nil
    local errorMsg 	= nil

    local H  = getHandleOfCallingThread()
	if H == nil then
		errorMsg = utils:formatErrorMsg( utils:dbgPrefix(),L["THREAD_HANDLE_NIL"], fname )
		return nil, errorMsg
	end

    if H[TH_SIGNAL_QUEUE]:size() == 0 then
        sigEntry = { SIG_NONE_PENDING, nil, nil }
        return sigEntry, nil
    end

    sigEntry = H[TH_SIGNAL_QUEUE]:dequeue()
    return sigEntry, nil
end

--[[@Begin
Signature: signalName, errorMsg = thread:getSignalName( signal )
Description: Gets the string name of the specified signal value. for
example, when submitting the numerical constant, SIG_ALERT (11) the
service returns the string, "SIG_ALERT"
end
end
Parameters:
- signal (number): the numerical signal whose name is to be returned.
Returns:
- Success: returns the name associated with the signal value and the errorMsg is set to nil.
- Failure: nil is returned, and the errorMsg parameter contains an error message (errorMsg[1])
and a stack trace (errorMsg[2]).
Usage:
    local signalName, errorMsg = thread:getSignalName( signal )
    if signalName == nil then print( errorMsg ) return end
@End]]
function thread:getSignalName(signal)
    local fname = "thread:getSignalName()"
    local errorMsg = nil
	local signalName = nil

    local isValid, errorMsg = signalIsValid(signal)
    if not isValid then
		errorMsg = formatErrorMsg( utils:dbgPrefix(), errorMsg, fname )
        return nil, errorMsg
    end
	local signalName = signalNameTable[signal]
	return signalName, errorMsg
end

--[[@Begin
Signature: signalCount, errorMsg = thread:getNumPendingSignals()
Description: Gets the number of pending signals for the calling thread.
Note, thread:getNumPendingSignals() is always fatal if the caller is not
a thread.
Parameters:
- None
Returns:
- Success: returns the number of the threads waiting to be retrieved (i.e., in
the thread's signal queue). The errorMsg parameter will be nil.
- Failure: nil is returned, and the errorMsg parameter contains an error message (errorMsg[1])
and a stack trace (errorMsg[2]).
Usage:
    local sigCount, errorMsg = thread:getNumPendingSignals( thread_h )
    if signalCount == nil then 
        print( errorMsg[1], errorMsg[2]) return end
@End]]
function thread:getNumPendingSignals()
    local H = getHandleOfCallingThread()
    return H[TH_SIGNAL_QUEUE]:size(), nil
end

