--=================================================================================
-- Filename: WoWThreadsLib.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
WoWThreadsLib = WoWThreadsLib or {}

local global = ns.Globals
local post  = ns.PostMessages
local utils = ns.UtilsLib
local L     = ns.Locales
local sig	= ns.SignalQueue

--=============== Create As A Libstub Library ===========
-- Configure WoWThreadsLib as a LibStub managed library
local _, localizedVersion, expansionName = global:getLibInfo()
local thread, oldVersion = LibStub:NewLibrary( "WoWThreadsLib", localizedVersion )
if not thread then return end  -- no upgrade needed
--=======================================================
--                                  LOCAL DATA
local CURRENTLY_RUNNING_THREAD = nil
local DEFAULT_YIELD_TICKS    = 1
local THREAD_SEQUENCE_ID     = 4 -- a number representing the order in which the thread was created

local threadControlBlock    = {} -- Table to hold all running and suspended threads
local threadSleepTable      = {} -- Table to hold sleeping threads
local threadDelayTable      = {}
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
thread.SIG_HAS_PAYLOAD  = 1 -- TBD
thread.SIG_SEND_PAYLOAD = 2 -- TBD
thread.SIG_BEGIN        = 3 -- TBD
thread.SIG_HALT         = 4 -- TBD
thread.SIG_COMPLETED  = 5 -- info: thread is complete
thread.SIG_SUCCESS      = 6 -- info: thread completed successfully
thread.SIG_FAILURE      = 7 -- info: thread completed with failure
thread.SIG_IS_READY     = 8
thread.SIG_CALLBACK     = 9  -- info: Signal entry contains a callback function in Sig[3]
thread.SIG_THREAD_DEAD  = 10 -- info: thread has completed or failed.
thread.SIG_ALERT        = 11 -- schedule for immediate execution
thread.SIG_WAKEUP       = 12 -- unused. Intended for thread pools.
thread.SIG_TERMINATE    = 13 -- thread terminates upon receipt.
thread.SIG_NONE_PENDING = 14 -- signal queue is empty.

thread.signalTable = {
    SIG_HAS_PAYLOAD     = thread.SIG_HAS_PAYLOAD,
    SIG_SEND_PAYLOAD    = thread.SIG_SEND_PAYLOAD,
    SIG_BEGIN        = thread.SIG_BEGIN,
    SIG_HALT         = thread.SIG_HALT,
    SIG_COMPLETED  = thread.SIG_COMPLETED,
    SIG_SUCCESS      = thread.SIG_SUCCESS,
    SIG_FAILURE      = thread.SIG_FAILURE,
    SIG_IS_READY     = thread.SIG_IS_READY,
    SIG_CALLBACK     = thread.SIG_CALLBACK,
    SIG_THREAD_DEAD  = thread.SIG_THREAD_DEAD,
    SIG_ALERT        = thread.SIG_ALERT,
    SIG_WAKEUP       = thread.SIG_WAKEUP,
    SIG_TERMINATE    = thread.SIG_TERMINATE,
    SIG_NONE_PENDING = thread.SIG_NONE_PENDING,
}

local SIG_HAS_PAYLOAD   = thread.SIG_HAS_PAYLOAD
local SIG_SEND_PAYLOAD  = thread.SEND_DATA
local SIG_BEGIN         = thread.SIG_BEGIN
local SIG_HALT          = thread.SIG_HALT
local SIG_COMPLETED     = thread.SIG_COMPLETED
local SIG_SUCCESS       = thread.SIG_SUCCESS
local SIG_FAILURE       = thread.SIG_FAILURE
local SIG_IS_READY      = thread.SIG_IS_READY
local SIG_CALLBACK      = thread.SIG_CALLBACK
local SIG_THREAD_DEAD   = thread.SIG_THREAD_DEAD
local SIG_ALERT         = thread.SIG_ALERT
local SIG_WAKEUP        = thread.SIG_WAKEUP
local SIG_TERMINATE     = thread.SIG_TERMINATE
local SIG_NONE_PENDING  = thread.SIG_NONE_PENDING

thread.signalNameTable = {
    "SIG_HAS_PAYLOAD",
    "SIG_SEND_PAYLOAD",
    "SIG_BEGIN",
    "SIG_HALT",
    "SIG_COMPLETED",
    "SIG_SUCCESS",
    "SIG_FAILURE",
    "SIG_IS_READY",
    "SIG_CALLBACK",
    "SIG_THREAD_DEAD",
    "SIG_ALERT",
    "SIG_WAKEUP",
    "SIG_TERMINATE",
    "SIG_NONE_PENDING"
}
local signalNameTable = thread.signalNameTable

--                          LOCAL FUNCTIONS 
local function dbgLog( msg )
    if debuggingIsEnabled then
        local newMsg = string.format("[LOG] %s\n", msg )
        post:message( newMsg )
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
    if #threadSleepTable == 0 then 
        return nil, L["THREAD_NOT_FOUND"]
    end

    for i, entry in ipairs(threadSleepTable) do
        if entry[TH_UNIQUE_ID] == H[TH_UNIQUE_ID] then
            table.remove( threadSleepTable, i )
            table.insert( threadControlBlock, H )			        
            H[TH_REMAINING_TICKS] = 1
			local logStr = string.format("%s thread[%d] inserted into TCB", utils:dbgPrefix(), H[TH_UNIQUE_ID])
			dbgLog( logStr )
            return H, nil
        end
    end
        return nil, L["THREAD_NOT_FOUND"]
end
local function inSleepTable( H )
	if #threadSleepTable == 0 then return nil end

	for _, entry in ipairs( threadSleepTable ) do
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
                logMsg = string.format("%s Thread[%d] Normal termination. Moved thread to morgue.", utils:dbgPrefix(), H[TH_UNIQUE_ID] )
                dbgLog( logMsg )
            else
                H[TH_COROUTINE] = nil
                logMsg = string.format("*** ABNORMAL termination *** %s Thread[%d] died horribly.\n",utils:dbgPrefix(), H[TH_UNIQUE_ID])
                dbgLog( logMsg )
            end
        end
    end
end
-- returns true if successful, false otherwise + errorMsg
local function moveToSleepTable( H )
    local errorMsg = nil
    local successful = false

    -- Remove thread from TCB and insert it into the sleep table
    for i, entry in ipairs(threadControlBlock) do
        if H[TH_UNIQUE_ID] == entry[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            table.insert( threadSleepTable, H )
            successful = true
            dbgLog( string.format("LOG: %s Thread[%d] removed from TCB, inserted into sleep table.\n", utils:dbgPrefix(), H[TH_UNIQUE_ID]) )
            return successful, nil
        end
		return nil, string.format("LOG: %s Sleep failed. Thread[%d] not put to sleep.", utils:dbgPrefix(), H[TH_UNIQUE_ID] )
    end

    if not successful then
		dbgLog( "LOG: %s, %s\n", utils:dbgPrefix(), L["THREAD_NOT_FOUND"] )
    end
        
    return successful, errorMsg
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
        return false, L["THREAD_NO_COROUTINE"]
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

    if signal < thread.SIG_HAS_PAYLOAD or signal > thread.SIG_NONE_PENDING then
        return false, L["SIGNAL_OUT_OF_RANGE"]
    end

    return true, nil
end
local function resumeOnError()
-- empty
end
-- Old resume function
-- local function resumeThread(H)
--     local co            = H[TH_COROUTINE]
--     local args          = H[TH_COROUTINE_ARGS] or {} -- Ensure args is a table
--     H[TH_RESUMPTIONS]   = H[TH_RESUMPTIONS] + 1 

--     -- Define error handler for xpcall using debugstack
--     local function errorHandler(err)
--         return tostring(err) .. "\nStack trace:\n" .. debugstack(2)
--     end

--     -- make H the currently running thread (it contains the coroutine
--     -- being resumed)
-- 	CURRENTLY_RUNNING_THREAD = H

--     local xpcallResults = { xpcall(coroutine.resume, errorHandler, co, unpack(args)) }
--     CURRENTLY_RUNNING_THREAD = nil

--     local xpcallSucceeded = xpcallResults[1]
--     if not xpcallSucceeded then
--         moveToMorgue(H, false )
-- 		local logMsg = string.format( "%s thread[%d] xpcall failed: results: %s\n", utils:dbgPrefix(), H[TH_UNIQUE_ID], xpcallResults[2] )
--         dbgLog( logMsg )
--         return false, errorMsg
--     end

--     local coroutineSucceeded = xpcallResults[2]
--     if not coroutineSucceeded then
-- 		dbgLog(string.format("%s Thread[%d] XPCALL failed: %s", utils:dbgPrefix(), H[TH_UNIQUE_ID], tostring(xpcallResults[2]):gsub("\n", "\n  ")))        
--         return false, xpcallResults[3]
--     end

--     if coroutine.status(co) == "dead" then
--         dbgLog(string.format("%s Thread[%d] has completed", utils:dbgPrefix(), H[TH_UNIQUE_ID]))
--         moveToMorgue(H, true)
--         return true, nil
--     end
--     dbgLog(string.format("%s Thread[%d] resumed.", utils:dbgPrefix(), H[TH_UNIQUE_ID]))
--     return true, select(2, unpack(xpcallResults))
-- end
-- new resume function
local function resumeThread(H)
    local co   = H[TH_COROUTINE]
    local args = H[TH_COROUTINE_ARGS] or {}
    H[TH_RESUMPTIONS] = H[TH_RESUMPTIONS] + 1

    CURRENTLY_RUNNING_THREAD = H

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
        dbgLog(string.format(
            "%s Thread[%d] failed (%s): %s\n%s",
            utils:dbgPrefix(),
            H[TH_UNIQUE_ID],
            result.type,
            tostring(result.message),
            tostring(result.stack)
        ))

        moveToMorgue(H, false)
        return false, result.message
    end

    -- Coroutine completed?
    if coroutine.status(co) == "dead" then
        dbgLog(string.format("%s Thread[%d] has completed", utils:dbgPrefix(), H[TH_UNIQUE_ID]))
        moveToMorgue(H, true)
        return true, nil
    end

    -- Normal resume
    dbgLog(string.format("%s Thread[%d] resumed.", utils:dbgPrefix(), H[TH_UNIQUE_ID]))
    return true, unpack(result.values)
end

local function scheduleThreads()

    if #threadDelayTable > 0 then
        for i = #threadDelayTable, 1, -1 do
            local H = threadDelayTable[i]
            H[TH_REMAINING_TICKS] = H[TH_REMAINING_TICKS] - 1
            if H[TH_REMAINING_TICKS] <= 0 then
                table.remove(threadDelayTable, i)
                table.insert(threadControlBlock, H)
                H[TH_REMAINING_TICKS] = H[TH_YIELD_TICKS]
                dbgLog(string.format("%s Thread[%d] delay expired, moved to TCB.", utils:dbgPrefix(), H[TH_UNIQUE_ID]))
            end
        end
    end

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
                local success, errorMsging = resumeThread(H)
                ---------------------------------------
                if not success then
                    dbgLog(string.format("%s Thread[%d] error: %s", utils:dbgPrefix(), H[TH_UNIQUE_ID], errorMsging ))
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
function thread:libInit( addonName )
    if WoWThreadsStarted == false then
        startTimer(CLOCK_TICK_INTERVAL)
        WoWThreadsStarted = true
    end
end

function thread:debuggingIsEnabled()
    return debuggingIsEnabled
end
function thread:enableDebugging()
    debuggingIsEnabled = true
	-- utils:postMsg( string.format("%s\n", "Error logging enabled\n"))
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
local function formatErrorMsg( prefix, errorMsg, functionName )
    return string.format( "%s - ERROR %s: called by %s\n", prefix, errorMsg, functionName )
end

--[[@Begin 
Signature: thread_h, errorMsg = thread:create( yieldTicks, func [,...] )
Description: Creates a reference to an executable thread called a 
thread handle. The thread handle is an opaque reference to the 
thread's coroutine. The thread handle is used by the library's 
internals to manage and schedule the thread.
Parameters:
- yieldTicks (number). An interval of time the calling thread is to
be suspended. The time is specified in clock ticks. In WoW, a clock tick 
is the reciprocal of your system's frame rate. On my system, a clock tick 
is about 16.7 milliseconds (1/60). Therefore, 60 ticks is about 1 second.
- func (function). The function the thread is to execute. In 
POSIX and other thread environments, the thread function is often 
called the action routine.
- ... (varargs, optional), Additional arguments to be passed to the thread function.
Returns:
- Success: a valid thread handle is returned and the errorMsg is nil.
- Failure: nil is returned and the errorMsg parameter specifies an error message.
The error message contains a reference to the file, line number, and function where the
error occured. For example

"[WoWThreads.lib:456] - Thread handle was nil in thread:create()

Usage Example:
    local thread_h, errorMsg = thread:create( 60, greetings, "Hello World" )
    if not thread_h then 
        print( errorMsg )
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
    local logMsg = string.format("%s thread[%d] inserted into TCB.", utils:dbgPrefix(), H[TH_UNIQUE_ID])
    dbgLog( logMsg )
    return H, nil
end
--[[@Begin 
Signature: addonName, errorMsg = thread:getAddonName( [thread_h] )
Description: Obtains the name of the addon within which the specified
thread was created. If thread_h is nil, the addon name of the calling
thread is returned.
Parameters:
- thread_h (thread handle, optional). A handle to the thread whose addon name is to be 
obtained. If not specified, the addon name of the calling thread will be returned.
Returns:
- Success: Returns the name of the specified thread's addon and the errorMsg is set to nil.
- Failure: the addonName is nil, and the errorMsg parameter contains an error message, errorMsg.
Usage:
    local addonName, errorMsg = thread:getAddonName( target_h )
    if addonName == nil then
        print( errorMsg )
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
		return nil, errorMsg
    end

    local H = getHandleOfCallingThread()
    -- Set delay and remove from TCB
    H[TH_REMAINING_TICKS] = delayTicks
    for i, entry in ipairs(threadControlBlock) do
        if H[TH_UNIQUE_ID] == entry[TH_UNIQUE_ID] then
            table.remove(threadControlBlock, i)
            table.insert(threadDelayTable, H)
            break
        end
    end

    coroutine.yield()
    return delayTicks, nil
end

--[[@Begin
Signature: thread_h, errorMsg = thread:sleep()
Description: Suspends the calling thread for an indeterminate amount of time.
Parameters:
- None
Returns:
- Success: the thread's handle is returned when it regains the processor (i.e., after 
it is resumed), and the errorMsg parameter is set to nil.
- Failure: the handle is false and the errorMsg parameter contains an error message. This situation arises
when the target thread is not in the thread sleep queue.
Usage:
    local thread_h, errorMsg = thread:sleep()
    if thread_h == nil then                 -- the thread was never put to sleep. 
        print( errorMsg[1], errorMsg[2])
    end
@End]]
function thread:sleep(...)
    local fname = "thread:sleep()"
	local errorMsg = nil
	local success = true

	H = CURRENTLY_RUNNING_THREAD
	if not H then
		errorMsg = formatErrorMsg( utils:dbgPrefix(), L["THREAD+NO_THREAD_CONTEXT"], fname )
		return nil, errorMsg
	end
	
	return moveToSleepTable(H)
end
--[[@Begin
Signature: success, errorMsg = thread:wakup( thread_h )
Description: Awakens a thread put to sleep by a previous call to thread:sleep().
Parameters:
- thread_h  (thread handle): the thread to be awakened.
Returns:
- Success: a boolean true and nil errorMsg if the operation was successful.
- Failure: a boolean false and the errorMsg parameter contains an error message. 
Usage:
    local success, errorMsg = thread:wakeup( thread_h )
    if not success  then 
        print( errorMsg[1], errorMsg[3])
    end
@End]]
function thread:wakeup( thread_h)
	local fname = "thread:wakeup"
	local errorMsg = nil 
	local isAwake = false

	if thread_h == nil then
		local errorMsg = formatErrorMsg( utils:dbgPrefix(), L["THREAD_HANDLE_NIL"], fname )
		return nil, errorMsg
	end
    if not handleIsValid(thread_h) then
        errorMsg = formatErrorMsg( utils:dbgPrefix(),  L["NO_THREAD_CONTEXT"], fname )
		return nil, errorMsg
    end

	local status = coroutine.status( thread_h[TH_COROUTINE])
	if status ~= "suspended" then
		errorMsg = formatErrorMsg(utils:dbgPrefix(), L["INVALID_OPERATION"], fname )
		return nil, errorMsg
	end

	if not inSleepTable( thread_h ) then
		errorMsg = formatErrorMsg( utils:dbgPrefix(), L["INVALID_OPERATION"], fname )
		return nil, errorMsg
	end

	thread_h, errorMsg = wakeupThread( thread_h ) 
	if not thread_h then 
		errorMsg = formatErrorMsg( utils:dbgPrefix(), errorMsg, fname )
		return nil, errorMsg
	end
	return thread_h, errorMsg
end
--[[@Begin
Signature: success, errorMsg = thread:isSleeping( thread_h )
Description: Returns the thread handle if found in the threadSleepTable.
Parameters:
- thread_h  (thread handle): the thread to be found.
Returns:
- Success: the thread handle and nil errorMsg
- Failure: nil and the errorMsg parameter containing an error message. 
Usage:
To be supplied.
@End]]
function thread:isSleeping( thread_h )
	local fname = thread:isSleeping()

		if thread_h == nil then
		local errorMsg = formatErrorMsg( utils:dbgPrefix(), L["THREAD_HANDLE_NIL"], fname )
		return nil, errorMsg
	end
    if not handleIsValid(thread_h) then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), L["NO_THREAD_CONTEXT"], fname )
		return nil, errorMsg
    end

	if inSleepTable( thread_h ) then
		return thread_h, nil
	end

	local errorMsg = formatErrorMsg( utils:dbgPrefix(), L["THREAD_NOT_FOUND"], fname )
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
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), L["INVALID_NO_THREAD_CONTEXT"], fname )
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
        errorMsg = string.format("%s In %s, %s.\n STACK: %s\n", utils:dbgPrefix(), errorMsg, fname )
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
2. If failed: nil is returned indicating the signal was not delivered. Usually
this means that the target's thread handle was was not found, sleeping, or completed ("dead").
The errorMsg parameter contains an error message (errorMsg[1]) and a stack trace (errorMsg[2]).
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
    local isValid = false
	
    -- check that the target handle is valid
    if target_h == nil then
        errorMsg = formatErrorMsg(utils:dbgPrefix(), L["THREAD_HANDLE_NIL"], fname )
        return nil, errorMsg
	end

	if type( target_h) ~= "table" then
        errorMsg = string.format("%s in %s. %s.\n", utils.dbgPrefix(), L["INVALID_TYPE"], fname)
        errorMsg = formatErrorMsg( utils:dbgPrefix(), errorMsg, fname )
        return nil, errorMsg
    end
    
	-- is the target thread a real thread?
    isValid = handleIsValid( target_h )

    if not isValid then
        errorMsg = formatErrorMsg(utils:dbgPrefix(),  L["NO_THREAD_CONTEXT"], fname )
        return nil, errorMsg
    end
    isValid, errorMsg = signalIsValid(signal)
	if not isValid then
        errorMsg = formatErrorMsg(utils:dbgPrefix(), errorMsg, fname )
        return nil, errorMsg
    end
    -- User code cannot send SIG_NONE_PENDING signals.
	if signal == thread.SIG_NONE_PENDING then
        errorMsg = formatErrorMsg(utils:dbgPrefix(), L["SIGNAL_INVALID_OPERATION"], fname )
        return nil, errorMsg
    end
    -- because dead threads cannot receive signals
	if handleIsInMorgue( target_h ) then
        return nil, L["THREAD_HAS_COMPLETED"]
    end
	-- Initialize and insert an entry into the recipient thread's signalTable
    local sender_h = getHandleOfCallingThread()
	local sigEntry = {signal, sender_h, ... }

    target_h[TH_SIGNAL_QUEUE]:enqueue(sigEntry)

	if signal == thread.SIG_ALERT then
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

