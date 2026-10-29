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
local sleepTable            = {} -- Table for threads waiting on a condition
local morgue                = {}

local CLOCK_TICK_INTERVAL    = 1/GetFramerate() -- approx 16.7 ms on a 60Hz system
local WoWThreadsStarted      = false
local debuggingIsEnabled     = true
local dataCollectionIsEnabled = false
-- =====================================================================
--                      NUMERIC CONSTANTS
-- =====================================================================
local TH_COROUTINE          = 1 -- the coroutine created to execute the thread's function
local TH_COROUTINE_ARGS     = 2
local TH_UNIQUE_ID          = 3 -- a number representing the order in which the thread was created
local TH_SIGNAL_QUEUE       = 4 -- a table of all currently pending signals
local TH_YIELD_TICKS        = 5 -- the number of clock tics for which a thread must suspend after a yield.
local TH_REMAINING_TICKS    = 6
local TH_RESUMPTIONS        = 7 -- the number of times a thread yields
local TH_CHILDREN           = 8
local TH_PARENT_HANDLE      = 9
local TH_ADDON_NAME       	= 10
local TH_ELAPSED_TICKS		= 11
local TH_TIME_CREATED       = 12 -- timestamped from debugprofilestop()
local TH_EXECUTION_STATE    = 13 -- "suspended", "dead"
local TH_TIME_COMPLETED     = 14 -- timestamped from debugprofilestop()
local TH_EXIT_DATA          = 15 -- data (varargs) saved when thread:exit() is called
local TH_ERROR_EXIT_STATUS  = 16 -- contains "normal" or "abnormal" exit
local TH_ERROR_EXIT_STACK   = 17
local TH_COROUTINE_ERROR    = 18
local TH_NUM_HANDLE_ELEMENTS = TH_COROUTINE_ERROR

-- Each thread has a signal queue. Each element in the signal queue contain
-- a sigEntry, tuple consisting of 3 elements: the signal, the sending thread, 
-- optional data (often termed the signal's payload). 
-- Example: sigTable = {signalValue, sender_h, [,...] }, where ... contains an
-- untyped and optional payload.
-- 
thread.SIG_READY            = 1 -- signal target_h the sender_h is ready.
thread.SIG_START            = 2 -- signal target_h that it is to start.
thread.SIG_COMPLETE         = 3 -- signal target_h that the sender_h is done
thread.SIG_ALERT            = 4 -- schedule target_h for immediate execution
thread.SIG_CONDITION_MET    = 5 -- resumes target_h waiting for a condition of occur
thread.SIG_CREATE_THREAD    = 6 -- signal the target_h to create a thread from its payload.
thread.SIG_TERMINATE        = 7 -- target_h is to terminate itself upon receipt.
thread.SIG_NONE_PENDING     = 8 -- signal queue is empty.

thread.signalTable = {
    SIG_READY           = thread.SIG_READY,
    SIG_START           = thread.SIG_START,
    SIG_COMPLETE        = thread.SIG_COMPLETE,
    SIG_ALERT           = thread.SIG_ALERT,
    SIG_CONDITION_MET   = thread.SIG_CONDITION_MET,
    SIG_CREATE_THREAD   = thread.SIG_TERMINATE,
    SIG_TERMINATE       = thread.SIG_TERMINATE,
    SIG_NONE_PENDING    = thread.SIG_NONE_PENDING,
}
local SIG_READY             = thread.SIG_READY
local SIG_START             = thread.SIG_START
local SIG_COMPLETE          = thread.SIG_COMPLETE
local SIG_ALERT             = thread.SIG_ALERT
local SIG_CONDITION_MET     = thread.SIG_CONDITION_MET
local SIG_CREATE_THREAD     = thread.SIG_CREATE_THREAD
local SIG_TERMINATE         = thread.SIG_TERMINATE
local SIG_NONE_PENDING      = thread.SIG_NONE_PENDING

thread.signalNameTable = {
    "SIG_READY",
    "SIG_START",
    "SIG_COMPLETE",
    "SIG_ALERT",
    "SIG_CONDITION_MET",
    "SIG_CREATE_THREAD",
    "SIG_TERMINATE",
    "SIG_NONE_PENDING"
}
local signalNameTable = thread.signalNameTable

--================================================================
--                     LOCAL FUNCTIONS 
--================================================================
local function dbgLog( prefix, msg )

    if prefix == nil then
        error( "prefix was nil")
    end
    if msg == nil then
        error( "logMsg was nil" )
    end

    if debuggingIsEnabled then
         local logMsg = string.format("[LOG]  %s %s\n", prefix, msg )
        post:message( logMsg )
    end
end
local function formatErrorMsg( prefix, errorMsg, functionName )
    local infoMsg = string.format("%s (%s) %s\n", prefix, functionName, errorMsg)
    return infoMsg
end

local function getThreadMetrics( H )
        local threadId 		= H[TH_UNIQUE_ID]
        local lifetime 		= H[TH_TIME_COMPLETED] - H[TH_TIME_CREATED]
        local elapsedTics	= H[TH_ELAPSED_TICKS]
        local yieldTics 	= H[TH_YIELD_TICKS]
        local resumptions 	= H[TH_RESUMPTIONS]

    return {threadId, lifetime, elapsedTics, yieldTics, resumptions }
end

local function coroutineIsDead(H)
    local dead = false

    local status = coroutine.status( H[TH_COROUTINE])
    if status == "dead" then
        dead = true
    end
    return dead
    end
local function removeFromTable(tbl, H)
    local targetId = H[TH_UNIQUE_ID]
    
    for i = 1, #tbl do
        if tbl[i][TH_UNIQUE_ID] == targetId then
            return table.remove(tbl, i)
        end
    end
end

local function handleIsInMorgue( H )
    local inMorgue = false
    if #morgue == 0 then 
        return inMorgue
    end

    for _, entry in ipairs(morgue) do
        if entry[TH_UNIQUE_ID] == H[TH_UNIQUE_ID] then
            inMorgue = true
        end
    end
	return inMorgue
end
local function handleIsSleeping(H)
    local targetId = H[TH_UNIQUE_ID]
    
    for _, entry in ipairs(sleepTable) do
        if entry[TH_UNIQUE_ID] == targetId then
            return true
        end
    end
    
    return false
end

local function wakeupThread(H)
    local isSleeping = false

    if not handleIsSleeping(H) then
        return nil, L["THREAD_NOT_FOUND"]
    end
    
    local h = removeFromTable( sleepTable, H )
    table.insert( threadControlBlock, h )
    logMsg = string.format("Thread[%d] awake and returned to TCB.", H[TH_UNIQUE_ID] )
    dbgLog( utils:dbgPrefix(), logMsg )  
    return true, nil       
end

local function createHandle( addonName, parent_h, yieldTics, func, ...)

    if yieldTics < DEFAULT_YIELD_TICKS then
        yieldTics = DEFAULT_YIELD_TICKS
    end

    THREAD_SEQUENCE_ID = THREAD_SEQUENCE_ID + 1
    local H = {
        [TH_COROUTINE]          = coroutine.create(func),
        [TH_COROUTINE_ARGS]     = {...},
        [TH_UNIQUE_ID]          = THREAD_SEQUENCE_ID,
        [TH_SIGNAL_QUEUE]       = sig.new(),
        [TH_YIELD_TICKS]        = yieldTics,
        [TH_REMAINING_TICKS]    = 1,
        [TH_ELAPSED_TICKS]      = 0,
        [TH_RESUMPTIONS]        = 0,
        [TH_CHILDREN]           = {},
        [TH_PARENT_HANDLE]      = parent_h,
        [TH_ADDON_NAME]         = ADDON_NAME,
        [TH_EXECUTION_STATE]    = "suspended",
        [TH_TIME_CREATED]       = debugprofilestop(),
        [TH_TIME_COMPLETED]     = 0,
        [TH_EXIT_DATA]          = "",
        [TH_ERROR_EXIT_STATUS]  = "", -- contains "normal" or "abnormal" exit
        [TH_ERROR_EXIT_STACK]   = "",
        [TH_COROUTINE_ERROR]    = "",
    }
    if parent_h ~= nil then
        table.insert( parent_h[TH_CHILDREN], H)
    end

    return H
end
local function moveToMorgue( H, normalCompletion )
	local logMsg = nil
    for _, entry in ipairs( threadControlBlock ) do
        if H[TH_UNIQUE_ID] == entry[TH_UNIQUE_ID] then
            H = removeFromTable( threadControlBlock, H)
            table.insert( morgue, H)
            if H[TH_COROUTINE] ~= nil then H[TH_COROUTINE] = nil end

            if normalCompletion then
                H[TH_TIME_COMPLETED] = debugprofilestop()
                logMsg = string.format("Thread[%d] Normal termination.", H[TH_UNIQUE_ID] )
                dbgLog( utils:dbgPrefix(), logMsg )
            else
                logMsg = string.format("ABNORMAL termination. Thread[%d] has died a horrible death.\n", H[TH_UNIQUE_ID])
                dbgLog( utils:dbgPrefix(), logMsg )
            end
        end
    end
end
local function handleIsValid(H)
    local isValid = true

    if type(H) ~= "table" then
        return false, L["INVALID_TYPE"]
    end
    if #H ~= TH_NUM_HANDLE_ELEMENTS then
        local errorMsg = string.format("%s %d elements in handle.\n", utils:dbgPrefix(), #H )
        return false, errorMsg
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
local function resumeThread(H)
    local co   = H[TH_COROUTINE]
    local args = H[TH_COROUTINE_ARGS] or {}

    -- Increment resumption count
    H[TH_RESUMPTIONS] = H[TH_RESUMPTIONS] + 1

    -- Mark this thread as currently running
    CURRENTLY_RUNNING_THREAD = H

    dbgLog(utils:dbgPrefix(),
        string.format("Thread[%d] resumed.", H[TH_UNIQUE_ID]))

    --------------------------------------------------------------------
    -- Error handler for xpcall
    --------------------------------------------------------------------
    local function errorHandler(err)
        return {
            ok      = false,
            type    = "lua_error",
            message = tostring(err),
            stack   = debugstack(2)
        }
    end

    --------------------------------------------------------------------
    -- Run coroutine.resume under xpcall and capture raw results
    --------------------------------------------------------------------
    local raw = { xpcall(coroutine.resume, errorHandler, co, unpack(args)) }

    -- Clear running thread marker
    CURRENTLY_RUNNING_THREAD = nil

    local ok        = raw[1]   -- xpcall succeeded?
    local resumeOK  = raw[2]   -- coroutine.resume succeeded?

    -- Collect all coroutine return values (yielded values)
    local values = {}
    for i = 3, #raw do
        values[#values+1] = raw[i]
    end

    --------------------------------------------------------------------
    -- Normalize into unified result object
    --------------------------------------------------------------------
    local result = {}

    if not ok then
        -- xpcall caught a Lua error inside coroutine.resume
        local errObj = raw[2]
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
        -- Normal resume (yield or return)
        result.ok     = true
        result.values = values
    end

    --------------------------------------------------------------------
    -- Handle abnormal exit (uncaught error)
    --------------------------------------------------------------------
    if not result.ok then
        H[TH_COROUTINE_ERROR] = {
            type    = result.type,
            message = result.message,
            stack   = result.stack,
        }

        dbgLog(utils:dbgPrefix(),
            string.format("Thread[%d] died a horrible death %s - %s",
                H[TH_UNIQUE_ID], result.type, tostring(result.message)))

        moveToMorgue(H, false)
        return false, result.message
    end

    --------------------------------------------------------------------
    -- Coroutine completed?
    --------------------------------------------------------------------
    if coroutine.status(co) == "dead" then

        -- Case 1: Normal exit via thread:exit()
        if H[TH_EXIT_STATUS] == "normal_exit" then
            dbgLog(utils:dbgPrefix(),
                string.format("Thread[%d] exited normally", H[TH_UNIQUE_ID]))
            moveToMorgue(H, true)

        -- Case 2: Abnormal exit (already handled above)
        elseif H[TH_COROUTINE_ERROR] then
            -- No action; already moved to morgue

        -- Case 3: Natural completion (function returned normally)
        else
            dbgLog(utils:dbgPrefix(),
                string.format("Thread[%d] completed naturally", H[TH_UNIQUE_ID]))
            moveToMorgue(H, true)
        end
        return true, nil
    end

    --------------------------------------------------------------------
    -- Coroutine is still alive → return yielded values
    --------------------------------------------------------------------
return true, unpack(result.values)
end


local function scheduleThreads()
    if #threadControlBlock == 0 then
        return
    end

    for i = #threadControlBlock, 1, -1 do
        local H = threadControlBlock[i]
        local co = H[TH_COROUTINE]
        local status = coroutine.status(co)
        -- XXXXX
        if status == "suspended" then
            H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1
            if H[TH_REMAINING_TICKS] <= 0 then
                H[TH_REMAINING_TICKS] = H[TH_YIELD_TICKS]
				---------------------------------------
                local success, errorMsg = resumeThread(H)
                ---------------------------------------
                local logMsg = string.format("Thread[%d] resumed.", H[TH_UNIQUE_ID])
            end
        end
    end
end
local function startTimer(CLOCK_TICK_INTERVAL)
    scheduleThreads(CLOCK_TICK_INTERVAL)
    C_Timer.After( CLOCK_TICK_INTERVAL,
        function()
            startTimer(CLOCK_TICK_INTERVAL)
        end
    )
    WoWThreadsStarted = true
end

--================================================================
--                     PUBLIC (EXPORTED) SERVICES               ==
--================================================================
--[[@Begin
Signature:
    thread_h, errorMsg = thread:create(yieldTics, threadFunction [, ...])

Description:
    Creates a new executable thread and returns its thread handle (thread_h).
    The thread handle is the opaque reference used internally by WoWThreadsLib
    to manage, schedule, and track the coroutine associated with the thread.

Parameters:
    - yieldTics (number)
        The number of scheduler tics the new thread will suspend before its first
        execution. A scheduler tic corresponds to one frame update. On a 60 FPS
        system, one tic is approximately 16.7 milliseconds. For example, 60 tics
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
            yieldTics value, the error message may look like:

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
function thread:create( yieldTics, someFunction,... )
    local fname = "thread:create()"
    local parent_h = nil
    local errorMsg = nil

    if type( yieldTics) ~= "number" then
        return nil, L["INVALID_TYPE"]
    end

    if type(someFunction) ~= "function" then
        return nil,  L["PARAMETER_NIL"]
    end
    parent_h = CURRENTLY_RUNNING_THREAD
	-- If parent_h is nil, the caller must be the WoW game client whose 
	-- addon name can be extracted from the stack trace.
    if parent_h == nil then 
        addonName = ADDON_NAME
    else
        -- the caller  is a thread. Therefore, it has a parent thread from which the addon name is obtained.
        addonName = parent_h[TH_ADDON_NAME]
    end

    local H = createHandle( addonName, parent_h, yieldTics, someFunction, ... )
    table.insert( threadControlBlock, H )
    local logMsg = string.format("Thread[%d] (tics %d) inserted into TCB.", H[TH_UNIQUE_ID], H[TH_YIELD_TICKS])
    dbgLog( utils:dbgPrefix(),  logMsg )
    return H, nil
end
--[[@Begin
Signature: thread:yield()
Description: Suspends the calling thread for the number of tics specified in the
yieldTics parameter of the calling thread's create function. Note that thread:yield()
is always fatal if the caller is NOT a thread.
Parameters:
- None.
Returns:
- None
Usage:
    local DONE = false
	while not DONE do
		thread:yield()  -- suspend the thread for its specified yieldTics interval
		local sigEntry = thread:getSignal()
		if sigEntry[1] == SIG_TERMINATE then
			DONE = true
        else
            -- Do some work
        end	
	end
@End]]
function thread:yield()
    if #CURRENTLY_RUNNING_THREAD ~= 18 then
        local trace = strip( debugstack(2))
        utils:dbgPrint( trace, CURRENTLY_RUNNING_THREAD.TH_UNIQUE_ID )
    end
    coroutine.yield()
    if #CURRENTLY_RUNNING_THREAD ~= 18 then
        local trace = strip( debugstack(2))
        utils:dbgPrint( trace, CURRENTLY_RUNNING_THREAD.TH_UNIQUE_ID )
    end

    H = CURRENTLY_RUNNING_THREAD
    H[TH_RESUMPTIONS] = H[TH_RESUMPTIONS] + 1
end

-- analogous to return, but permits the thread to save data for
-- other threads to query. This service is called when a thread
-- must save state before exiting. For example, if a thread receives
-- a SIG_TERMINATE signal the dev can either execute a normal return
-- or call thread:exit( data )
-- WARNING: Calling this service will terminate the thread.
function thread:exit(...)
    local H = CURRENTLY_RUNNING_THREAD
    if not H then
        error("thread:exit() called outside of a running thread")
    end

    -- Store exit data (may be nil, string, table, etc.)
    H[TH_EXIT_DATA] = ...

    -- Mark this as a normal, intentional exit
    H[TH_ERROR_EXIT_STATUS] = "normal_exit"

    -- Optional: capture a stack trace for debugging
    H[TH_ERROR_EXIT_STACK] = debugstack(2)

    -- Yield control; scheduler will detect coroutine death
    return coroutine.yield()
end
function thread:getExitData( thread_h )
    local fname = "thread:getExitData()"
    local errorMsg = nil

    if not thread_h then
        errorMsg = formatErrorMsg( utils:dbgPrefix(),  L["THREAD_HANDLE_NIL"], fname )
        return nil, errorMsg
    end
    assert( #thread_h == 18, "thread_h size wrong.")
    local isValid, errorMsg = handleIsValid( thread_h )
    if not isValid then
        errorMsg = formatErrorMsg( utils:dbgPrefix(),  L["THREAD_HANDLE_INVALID"], fname )
        return nil, errorMsg
    end
    local co = thread_h[TH_COROUTINE]
    if co.status ~= "suspended" then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), L["THREAD_NOT_COMPLETED"])
        return nil, errorMsg
    end
    return thread_h[TH_EXIT_DATA], nil
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
    -- if thread_h == nil then
    --     thread_h = CURRENTLY_RUNNING_THREAD
    -- end
    -- local isValid, errorMsg = handleIsValid( thread_h)
    -- if not isValid then
    --     return nil, errorMsg
    -- end
    -- return thread_h[TH_ADDON_NAME], nil
end

-- Signature: hasCompleted, errorMsg - thread:hasCompleted( thread_h )
function thread:hasCompleted( thread_h )
    local fname = "thread:hasCompleted()"
    local errorMsg = nil

    if thread_h == nil then
        errorMsg = formatErrorMsg(utils:dbgPrefix(), L["THREAD_HANDLE_NIL"], fname )
        return false,  errorMsg
    end

    local isValid, errorMsg = handleIsValid(thread_h)
    if not isValid then return false, errorMsg end

    if thread_h[TH_EXECUTION_STATE] == "dead" then
        return true, nil
    end
    return false, errorMsg end

function thread:getExecutionState( H )
    local fname = "thread:getExecutionState()"
    local errorMsg = nil

    if H == nil then
        errorMsg = formatErrorMsg( utils:dbgPrefix(),  L["THREAD_HANDLE_NIL"], fname )
        return nil, errorMsg
    end
    local isValid, errorMsg = handleIsValid( H )
    if not isValid then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), errorMsg, fname )
        return nil, errorMsg
    end
    return H[TH_EXECUTION_STATE]
end

--[[@Begin
Signature: local ticsDelayed, errorMsg = thread:delay( tics )
Description: Suspends the calling thread for the specified number of tics. 
Note: when signaled, delayed threads respond as normal. Note: thread:delay()
is always fatal if the caller is not a thread.
Parameters:
- tics (number): the number of tics the thread is to be delayed.
Note that when the delay has expired, the thread's specified yield tics
will have been
Returns:
- Success: the actual number of tics the thread was delayed. The errorMsg is set to nil.
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

-- Adjusts the number of yield tics to the delay tics.
function thread:delay(delayTics)
    local fname = "thread:delay()"
	local errorMsg = nil
    if not delayTics or type(delayTics) ~= "number" then
        errorMsg = formatErrorMsg(utils:dbgPrefix(), L["INVALID_TYPE"], fname)
		return false, errorMsg
    end

    local H = CURRENTLY_RUNNING_THREAD
    
    -- Set delay and remove from TCB
    H[TH_REMAINING_TICKS] = delayTics
    coroutine.yield()
end
-- moves a thread from the TCB into the sleep table. No adjustment
-- to the thread's yield tics.
function thread:sleep()
    local H = CURRENTLY_RUNNING_THREAD
    H = removeFromTable(tableControlBlock, H )
    table.insert( sleepTable, H )			        
    return H, nil
end
-- Moves a thread from the sleep table into the TCB
function thread:wakeup( H )
    local isAwake, errorMsg = wakeupThread(H)
    return isWake, errorMsg
end
-- removes the target thread from the TCB to the morgue and
-- ets the thread's coroutine to nil
function thread:kill( thread_h )
    -- NOT YET IMPLEMENTED
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
	local H = CURRENTLY_RUNNING_THREAD
    if not H then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname )
        return nil, L["NO_THREAD_CONTEXT"]
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
		thread_h = CURRENTLY_RUNNING_THREAD
        if thread_h == nil then
            errorMsg = formatErrorMsg( utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname )
            return nil, L["NO_THREAD_CONTEXT"]
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
		thread_h = CURRENTLY_RUNNING_THREAD
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
        thread_h  = CURRENTLY_RUNNING_THREAD
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
    local sender_h = CURRENTLY_RUNNING_THREAD
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

    local H  = CURRENTLY_RUNNING_THREAD
	if H == nil then
		errorMsg = formatErrorMsg( utils:dbgPrefix(),L["THREAD_HANDLE_NIL"], fname )
        utils:dbgPrint( errorMsg )
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
	local signalName, errorMsg = signalNameTable[signal]
	return signalName, errorMsg
end

function thread:mgmtDebuggingIsEnabled()
    return debuggingIsEnabled
end
function thread:mgmtEnableDebugging()
    debuggingIsEnabled = true
end
function thread:mgmtDisableDebugging()
    debuggingIsEnabled = false
end
function thread:mgmtDataCollectionIsEnabled()
    return dataCollectionIsEnabled
end
function thread:mgmtEnableDataCollection()
    dataCollectionIsEnabled = true
end
function thread:mgmtDisableDataCollectionn()
   dataCollectionIsEnabled = false
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
function thread:mgmtGetNumPendingSignals()
    local H = CURRENTLY_RUNNING_THREAD
    return H[TH_SIGNAL_QUEUE]:size(), nil
end
--[[@Begin
local metrics = { threadId, lifeTimeMS, lifetimeTics, yieldReumptions}
Signature: metrics, errorMsg  = thread:getMetrics( thread_h )
Description: Gets some some basic execution metrics; the runtime (ms) and   
congestion (how long the thread had to wait to begin execution after having
been resumed). Note: at this point, only completed threads can be queried.
Parameters:
- thread_h (thread_handle): the thread handle whose metrics are to be returned.
- Returns: 
    table {threadId, lifetime, elapsedTics, yieldTics, resumptions }
    nil or errorMsg
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

	local metrics = getThreadMetrics( thread_h )

	return metrics, nil
end
-- called by the OnEvent handler when PLAYER_LOGIN fires.
-- this doesn't return until WoWThreads has beein inititalized.
function thread:mgmtBootstrap()
    if WoWThreadsStarted then return WoWThreadsStarted end
    startTimer( CLOCK_TICK_INTERVAL)

    while not WoWThreadsStarted do
        C_Timer.After(1.0, 
        function() 
            if WoWThreadsStarted then
                return WoWThreadsStarted
            end
        end)
    end
    return WoWThreadsStarted
end

