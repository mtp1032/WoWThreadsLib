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
local L     = ns.Locales.L
local sig	= ns.SignalQueue

--=============== Create As A Libstub Library ===========
-- Configure WoWThreadsLib as a LibStub managed library
local _, localizedVersion, expansionName = core:getLibInfo()
local thread, oldVersion = LibStub:NewLibrary( "WoWThreadsLib", localizedVersion )
if not thread then return end  -- no upgrade needed
--=======================================================
--                                  LOCAL DATA
local CALLING_THREAD = nil
local DEFAULT_YIELD_TICS    = 1
local THREAD_SEQUENCE_ID     = 4 -- a number representing the order in which the thread was created

local threadControlBlock    = {} -- Table to hold all running and suspended threads
local sleepTable            = {} -- Table for threads waiting on a condition
local morgue                = {}
local metrics               = {}

local WoWClockTicInterval    = 1/GetFramerate() -- approx 16.7 ms on a 60Hz system
local WoWThreadsStarted      = false
local debuggingIsEnabled     = true
-- =====================================================================
--                      NUMERIC CONSTANTS
-- =====================================================================
local TH_COROUTINE          = 1 -- the coroutine created to execute the thread's function
local TH_COROUTINE_ARGS     = 2
local TH_UNIQUE_ID          = 3 -- a number representing the order in which the thread was created
local TH_PENDING_SIGNALS    = 4 -- a table of all currently pending signals
local TH_TICS_PER_YIELD     = 5 -- the number of frame updates for which a thread must suspend after a yield.
local TH_REMAINING_TICS     = 6
local TH_RESUMPTIONS        = 7 -- the number of times a thread yields
local TH_CHILDREN           = 8
local TH_PARENT_HANDLE      = 9
local TH_ADDON_NAME       	= 10
local TH_EXECUTION_STATE    = 11 -- "suspended", "dead"
local TH_TIME_CREATED       = 12 -- timestamped from debugprofilestop()
local TH_TIME_COMPLETED     = 13 -- timestamped from debugprofilestop()
local TH_EXIT_DATA          = 14 -- data (varargs) saved when thread:exit() is called
local TH_EXIT_STATUS_NORMAL = 15 -- contains "normal" or "abnormal" exit
local TH_ERROR_EXIT_STACK   = 16
local TH_COROUTINE_ERROR    = 17
local TH_NUM_HANDLE_ELEMENTS = TH_COROUTINE_ERROR

-- Each thread has a signal queue. Each element in the signal queue contain
-- a sigEntry, tuple consisting of 3 elements: the signal, the sending thread, 
-- optional data (often termed the signal's payload). 
-- Example: sigTable = {signalValue, sender_h, [,...] }, where ... contains an
-- untyped and optional payload.
-- 
thread.SIG_READY            = 1 -- signal target_h the sender_h is ready.
thread.SIG_START            = 2 -- signal target_h that it is to start.
thread.SIG_STOP             = 3 -- signal a thread to stop its activities.
thread.SIG_COMPLETE         = 4 -- signal target_h that the sender_h is done
thread.SIG_ALERT            = 5 -- schedule target_h for immediate execution
thread.SIG_CONDITION_MET    = 6 -- resumes target_h waiting for a condition of occur
thread.SIG_TERMINATE        = 7 -- target_h is to terminate itself upon receipt.
thread.SIG_NONE_PENDING     = 8 -- signal queue is empty.

thread.signalTable = {
    SIG_READY           = thread.SIG_READY,
    SIG_START           = thread.SIG_START,
    SIG_STOP            = thread.SIG_STOP,
    SIG_COMPLETE        = thread.SIG_COMPLETE,
    SIG_ALERT           = thread.SIG_ALERT,
    SIG_CONDITION_MET   = thread.SIG_CONDITION_MET,
    SIG_TERMINATE       = thread.SIG_TERMINATE,
    SIG_NONE_PENDING    = thread.SIG_NONE_PENDING,
}
local SIG_NUM_SIGNALS   = #thread.signalTable

local SIG_READY           = thread.SIG_READY
local SIG_START           = thread.SIG_START
local SIG_STOP            = thread.SIG_STOP
local SIG_COMPLETE        = thread.SIG_COMPLETE
local SIG_ALERT           = thread.SIG_ALERT
local SIG_CONDITION_MET   = thread.SIG_CONDITION_MET
local SIG_TERMINATE       = thread.SIG_TERMINATE
local SIG_NONE_PENDING    = thread.SIG_NONE_PENDING

thread.signalNameTable = {
    "SIG_READY",
    "SIG_START",
    "SIG_STOP",
    "SIG_COMPLETE",
    "SIG_ALERT",
    "SIG_CONDITION_MET",
    "SIG_TERMINATE",
    "SIG_NONE_PENDING"
}
local signalNameTable = thread.signalNameTable

local SIG_SIGNAL  = 1
local SIG_SENDER  = 2
local SIG_PAYLOAD = 3
--================================================================
--                     LOCAL FUNCTIONS 
--================================================================
local function packArgs(...)
    return {
        n = select("#", ...),
        ...
    }
end
local function unpackArgs(args)
    return unpack(args, 1, args.n)
end

local function handleLenth()
    return TH_NUM_HANDLE_ELEMENTS
end
local CYAN = "|cff00FFFF"
local RED  = "|cffFF4040"
local GOLD = "|cffFFD100"
local END  = "|r"

local function colorize(text, r,g,b )
    return string.format(
        "|cff%02X%02X%02X%s|r",
        r * 255,
        g * 255,
        b * 255,
        text
    )
end

local function strip( dbgTrace )
    trace = dbgTrace:gsub("^.*[/\\]", "")
    trace = dbgTrace:gsub("^(.-:%d+):%s*", "%1 - ")
    return dbgTrace
end

local function dbgLog( prefix, msg )
    if not debuggingIsEnabled then return end
    if prefix() == nil then
        error( "prefix was nil")
    end
    if msg == nil then
        error( "logMsg was nil" )
    end
    if debuggingIsEnabled then
         local logMsg = string.format("%s %s\n", colorize(utils:dbgPrefix(), 0, 1, 0.5), msg )
        --  post:message( logMsg )
    end
end
local function formatErrorMsg( prefix, errorMsg, functionName )
    local errorMsg = string.format("%s (%s) %s \n", colorize( prefix, 0, 1, 0), functionName, errorMsg)
    return errorMsg
end

local METRICS_ID                = 1
local METRICS_LIFETIME          = 2  
local METRICS_TICS_PER_YIELD    = 3
local METRICS_RESUMPTIONS       = 4

local function insertStats( H )
    
    local threadId 		= H[TH_UNIQUE_ID]
    local lifetime 		= H[TH_TIME_COMPLETED] - H[TH_TIME_CREATED]
    local ticsPerYield  = H[TH_TICS_PER_YIELD]
    local resumptions 	= H[TH_RESUMPTIONS]

    local stats = {threadId, lifetime, ticsPerYield, resumptions }
    table.insert( metrics, stats )
end
-- entry = {threadId, lifetime, ticsPerYield, resumptions }
local function getThreadStats( H )
    local threadId = H[TH_UNIQUE_ID]
    for _, stats in ipairs(metrics) do
        if stats[METRICS_ID] == threadId then
            return stats, nil
        end
    end
    return nil, L["THREAD_NOT_FOUIND"]
end

local function coroutineIsDead(H)
    local dead = false

    if H == nil then
        return nil, L["THREAD_HANDLE_NIL"]
    end
    if H[TH_COROUTINE] == nil then
        return nil, L["THREAD_COROUTINE_NIL"]
    end

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
            return table.remove(tbl, i), nil
        end
    end
    return nil, L["THREAD_NOT_FOUND"]
end

local function handleIsInMorgue( H )
    if #morgue == 0 then 
        return false
    end

    for _, entry in ipairs(morgue) do
        if entry[TH_UNIQUE_ID] == H[TH_UNIQUE_ID] then
            return true
        end
    end
	return false
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

    if H == nil then
        return nil, L["THREAD_HANDLE_NIL"]
    end

    if not handleIsSleeping(H) then
        return nil, L["THREAD_NOT_FOUND"]
    end
    
    local H, errorMsg = removeFromTable( sleepTable, H )
    if not H then
        return nil, errorMsg
    end

    table.insert( threadControlBlock, thread_h )
    logMsg = string.format("Thread[%d] awakened and returned to TCB.", H[TH_UNIQUE_ID] )
    dbgLog( utils:dbgPrefix(), logMsg )  
    return true, nil       
end
local function createHandle( addonName, parent_h, yieldInterval, func, ...)

    if yieldInterval < DEFAULT_YIELD_TICS then
        yieldInterval = DEFAULT_YIELD_TICS
    end

    THREAD_SEQUENCE_ID = THREAD_SEQUENCE_ID + 1
    local H = {
        [TH_COROUTINE]          = coroutine.create(func),
        [TH_COROUTINE_ARGS]     = packArgs(...),
        [TH_UNIQUE_ID]          = THREAD_SEQUENCE_ID,
        [TH_PENDING_SIGNALS]    = {},
        [TH_TICS_PER_YIELD]     = yieldInterval,
        [TH_REMAINING_TICS]     = 1,
        [TH_RESUMPTIONS]        = 0,
        [TH_CHILDREN]           = {},
        [TH_PARENT_HANDLE]      = parent_h,
        [TH_ADDON_NAME]         = ADDON_NAME,
        [TH_EXECUTION_STATE]    = "suspended",
        [TH_TIME_CREATED]       = debugprofilestop(),
        [TH_TIME_COMPLETED]     = 0,
        [TH_EXIT_DATA]          = "",
        [TH_EXIT_STATUS_NORMAL]  = "normal", -- contains "normal" or "abnormal" exit
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
            H, errorMsg = removeFromTable( threadControlBlock, H)
            if not H then return errorMsg end

            table.insert( morgue, H)
            local stats, errorMsg = getThreadStats( H)
            if not stats then
                return nil, errorMsg
            end
            table.insert( metrics, stats )
            if H[TH_COROUTINE] ~= nil then H[TH_COROUTINE] = nil end
        end
    end
end
local function dumpPayload(payload)
    print("payload count =", payload.n)

    for i = 1, payload.n do
        print(i, tostring(payload[i]))
    end
end
local function handleIsValid(H)
    if type(H) ~= "table" then
        return false, L["INVALID_TYPE"]
    end
    if TH_NUM_HANDLE_ELEMENTS ~= #H then
        return false, L["THREAD_HANDLE_CORRUPTED"]
    end
    return true, nil
end
local function signalIsValid(signal)
    if signal == nil then
        return nil, L["SIGNAL_IS_NIL"]
    end

    if type(signal) ~= "number" then
        return nil, L["SIGNAL_INVALID_TYPE"]
    end

    if signal < SIG_READY then
        return nil, L["SIGNAL_OUT_OF_RANGE"]
    end
    if signal > SIG_TERMINATE  then
        return nil, L["SIGNAL_OUT_OF_RANGE"]
    end
    return true, nil
end
local function resumeThread(H)
    local co   = H[TH_COROUTINE]
    local args = H[TH_COROUTINE_ARGS] or {}

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
    CALLING_THREAD = H
    local raw = { xpcall(coroutine.resume, 
                        errorHandler, 
                        H[TH_COROUTINE], 
                        unpackArgs( H[TH_COROUTINE_ARGS])) }
                        
    CALLING_THREAD = nil 

    local ok        = raw[1]   -- xpcall succeeded?
    local resumeOK  = raw[2]   -- coroutine.resume succeeded?
    local status = coroutine.status(H[TH_COROUTINE])

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
        local flag = true

        if result.message == "THREAD_EXIT" then
            flag = true
        end
        moveToMorgue(H, flag )
        return true, result.message
    end

    --------------------------------------------------------------------
    -- Coroutine completed?
    --------------------------------------------------------------------
    if coroutine.status(co) == "dead" then

        -- Case 1: Normal exit via thread:exit()
        if H[TH_EXIT_STATUS_NORMAL] == "normal_exit" then
            dbgLog(utils:dbgPrefix(),
            string.format("Thread[%d] exited normally", H[TH_UNIQUE_ID]))
            moveToMorgue(H, true)

        -- Case 2: Abnormal exit (already handled above)
        elseif H[TH_COROUTINE_ERROR] then
            -- No action; already moved to morgue

        -- Case 3: Natural completion (function returned normally)
        else
            dbgLog(utils:dbgPrefix(),
                string.format("Thread[%d] normal completion", H[TH_UNIQUE_ID]))
            moveToMorgue(H, true)
        end
        return true, nil
    end

    --------------------------------------------------------------------
    -- Coroutine is still alive → return yielded values
    --------------------------------------------------------------------
    return true, unpack(result.values)
end

--================================================================
--                     PUBLIC (EXPORTED) SERVICES               ==
--================================================================
--[[@Begin
### Signature:
    thread_h, errorMsg = thread:create(yieldInterval, threadFunction [, ...])

#### 
    Creates a new executable thread and returns its thread handle (thread_h).
    The thread handle is the opaque reference used internally by WoWThreadsLib
    to manage, schedule, and track the coroutine associated with the thread.

####  Parameters:
    - yieldInterval (number)
        The number of frame updates the new thread will suspend before its first
        execution. On a 60 FPS system, the duration of one frame is approximately 
        16.7 milliseconds. For example, 60 tics is roughly one second.

    - threadFunction (function)
        The function the thread will execute. In POSIX terminology, this is the
        thread’s “action routine.” WoWThreadsLib invokes this function inside a
        coroutine context managed by the library.

    - ... (varargs, optional)
        Additional arguments to pass to the threadFunction when the thread begins
        execution.

####  Returns:
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
            yieldInterval value, the error message may look like:

            "[FooBar.lua:45] Unknown or unexpected data type | Caller: thread:create()"

        This indicates that thread:create() rejected one of the arguments due to
        an invalid type.

Usage Example:
    -- thread is to  yield appoximately 1 second between executions.
    local thread_h, errorMsg = thread:create(60, greetings, "Hello World")
    if not thread_h then
        print(errorMsg)
        return
    end
@End]]
function thread:create( yieldInterval, someFunction,... )
    local fname = "thread:create()"
    local parent_h = nil
    

    if type( yieldInterval) ~= "number" then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), L["INVALID_TYPE"], fname )
        return nil, errorMsg
    end

    if type(someFunction) ~= "function" then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), L["PARAMETER_NIL"], fname )
        return nil, errorMsg
    end
    parent_h = CALLING_THREAD
	-- If parent_h is nil, the caller must be the WoW game client whose 
	-- addon name can be extracted from the stack trace.
    if parent_h == nil then 
        addonName = ADDON_NAME
    else
        -- the caller  is a thread. Therefore, it has a parent thread from which the addon name is obtained.
        addonName = parent_h[TH_ADDON_NAME]
    end

    local H = createHandle( addonName, parent_h, yieldInterval, someFunction, ... )
    table.insert( threadControlBlock, H )
    local logMsg = string.format( "Thread[%d] inserted into TCB.", H[TH_UNIQUE_ID])
    return H, nil
end
--[[@Begin
### Signature: 
    thread:yield()
#### Description: 
    Suspends the calling thread for the number of tics specified in the yieldInterval parameter of the 
    calling thread's create function. Note that thread:yield() is always fatal if the caller is 
        NOT a thread.
####  Parameters:
- None.
####  Returns:
- None
####  Usage:
    local DONE = false
	while not DONE do
		thread:yield()  -- suspend the thread for its specified yieldInterval interval
		local sigEntry = thread:getSignal()
		if sigEntry[1] == SIG_TERMINATE then
			DONE = true
        else
            -- Do some work
        end	
	end
@End]]
function thread:yield()
    coroutine.yield()
end

--[[ 
-- a helpful function to store the exit data in the calling thread's handle
function storeData(...)
    H = CALLING_THREAD
    local exitData = H[TH_EXIT_DATA]
    exitData = { n = select("#", ...)
end
-- a helpful function to retrieve the exit data from the calling thread's handle
function getData(index)
    local t = values[index]
    return unpack(t, 1, t.n)
end

]]
--[[ 
### :
    thread:exit(...)
#### Description:
    Terminates the calling thread and stores the specified varargs in the calling
    thread's handle. The stored data can be retrieved by the parent thread using
    thread:getExitData(thread_h). Note that thread:exit() is always fatal if the
    caller is NOT a thread.
#### Parameters:
    - ... (varargs, optional)
        Any number of values to be stored in the calling thread's handle. These
        values can be retrieved by the parent thread using thread:getExitData(thread_h).
        thread:exit() does not return to the calling thread. Instead, it terminates the 
        thread immediately.
#### Returns:
    - None, this function never returns to the calling thread. The thread is terminated immediately.

#### Usage Example:
    thread:exit("Thread completed successfully", 42, {1, 2, 3})
]]
function thread:exit(...)
    local H = CALLING_THREAD

    -- store the data in the calling thread's handle
    H[TH_EXIT_DATA] = packArgs(...)

    -- Terminate the thread by NOT handling this exeption
    error("THREAD_EXIT")
end

function thread:getExitData(thread_h)
    local fname = "thread:getExitData()"
    
    if not thread_h then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), L["THREAD_NOT_FOUND"], fname )
        return nil, errorMsg
    end

    return unpackArgs(thread_h[TH_EXIT_DATA])
end

--[[@Begin
*** :
    addonName, errorMsg = thread:getAddonName([thread_h])

####  Description: 
    Returns the name of the addon that owns the specified thread. This function is
    useful only for the shared, standalone version of WoWThreads where threads
    created by multiple addons may coexist. Knowing the owning addon allows the
    scheduler, error system, and debugging tools to correctly attribute thread
    activity.

####  Parameters:
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
    return thread_h[TH_ADDON_NAME], nil
end

function thread:getState( H )
    local fname = "thread:getState()"
    

    if H == nil then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(),  L["THREAD_HANDLE_NIL"], fname )
        return nil, errorMsg
    end
    local isValid, errorMsg = handleIsValid( H )
    if not isValid then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), errorMsg, fname )
        return nil, errorMsg
    end

    local state = coroutine.status(H[TH_COROUTINE])
    return state, nil
end

--[[@Begin
*** Signature: 
    local delayInterval, errorMsg = thread:delay( delayInterval )
####  Description:  
    Suspends the calling thread for the specified number of frame updatdes (also
    called 'tics'). 
    Note: when signaled, delayed threads respond as normal. Note: thread:delay()
    is always fatal if the caller is not a thread.
####  Parameters:
- delayInterval (number): the number of frames the thread is to be delayed.
Note that when the delay has expired, the thread's original delay interval
will have been restored.
####  Returns:
- Success: the actual number of frames the thread had been delayed. The errorMsg is set to nil.
- Failure: the first value is nil, and the errorMsg parameter contains an error message.
####  Usage:
    ```-- delay a thread 1 minute
    local actualDelay, errorMsg = thread:delay( 3600 )
    if actualDelay == nil then 
        print( errorMsg) 
        return 
    end```
@End]]
function thread:delay(tics)
    local fname = "thread:delay()"
    

    if not tics or type(tics) ~= "number" then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), L["INVALID_TYPE"], fname)
		return nil, errorMsg 
    end

    local H = CALLING_THREAD
    
    -- Set delay and remove from TCB
    H[TH_REMAINING_TICS] = tics + H[TH_TICS_PER_YIELD]
    coroutine.yield()
end
-- moves a thread from the TCB into the sleep table. No adjustment
-- to the thread's yield tics.
function thread:sleep()
    local fname = "thread:sleep()"
    
    local errorMsg = nil

    local H = CALLING_THREAD
    H, errorMsg = removeFromTable(tableControlBlock, H )
    if not H then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), errorMsg, fname )
        return nil, errorMsg
    end
    table.insert( sleepTable, H )			        
    return H, nil
end
-- Moves a thread from the sleep table into the TCB
function thread:wakeup( H )
    
    
    local successful, errorMsg = wakeupThread()
    if not succeessful then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), errorMsg, fname )
        return false, errorMsg
    end
    return true, nil
end

--[[@Begin
### Signature:
    thread_h, errorMsg = thread:getSelf()
####  Description:  
    Gets the handle of the calling thread.
####  Parameters:
- None
####  Returns:
- Success: returns a thread handle and its numerical Id.
- Failure: This can only succeed because it is only used by the calling thread.
@End]]
function thread:self()
    return CALLING_THREAD, CALLING_THREAD[TH_UNIQUE_ID]
end

--[[@Begin
### Signature: 
    threadId, errorMsg = thread:getId( [thread_h] )
#### Description:
    Obtains the unique, numerical Id of the specified thread. Note, if the 
    thread parameter (thread_h) is nil, then the Id of the calling thread is
    returned.
####  Parameters:
- thread_h (handle, optional): returns the numeric Id (unique) of the specified
thread. If not specified, the Id of the calling thread is returned.
####  Returns:
- Success: returns the numerical Id of the thread and the errorMsg is set to nil.
- Failure: nil is returned, and the errorMsg parameter contains an error message.
####  Usage:
    ```local threadId, errorMsg = thread:getId()
    if threadId == nil then 
        print( errorMsg, errorMsg[2]) 
        return 
    end```
@End]]
function thread:getId(thread_h)
    local fname = "thread:getId()"

    if thread_h == nil then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), L["NOT_A_THREAD"])
		return CALLING_THREAD[TH_UNIQUE_ID], nil
    end

    local isValid, errorMsg = handleIsValid(thread_h)
    if not isValid then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), errorMsg, fname )
        return nil, errorMsg
    end
    return thread_h[TH_UNIQUE_ID], nil
end

--[[@Begin
### Signature: parent_h, errorMsg = thread:getParent( [thread_h] )
####  Description:  Gets the specified thread's parent. NOTE: if the 
the thread was created by the WoW client it will not have a parent
Note: In this document all threads created by thw WoW client (WoW.exe)
are termed primary threads.
Parameters
- thread_h (handle, optional): if nil, then the calling thread's parent is returned.
Returns
- Success: returns the handle of the parent thread and the errorMsg is set to nil.
- Failure: nil is returned, and the errorMsg parameter contains an error message.
####  Usage:
    local parent_h, errorMsg = thread:getParent( thread_h )
    if parent_h == nil then 
        print( errorMsg, errorMsg[2])
    end
@End]]
function thread:getParent( thread_h )
    local fname = "thread:getParent()"
	local errorMsg = nil
    

    if thread_h == nil then
        return CALLING_THREAD, nil
    end

    local isValid, errorMsg = handleIsValid(thread_h)
    if not isValid then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), errorMsg, fname )
        return nil, errorMsg
    end
	return H[TH_PARENT_HANDLE], nil
end

--[[@Begin
### Signature: 
children, errorMsg = thread:getChildren( [parent_h] )
####  Description:  Obtains a table of the handles of the specified thread's children.
Parameters
- parent_h (handle, optional). If nil, then a table of child threads belongingto the calling 
thread is returned.
Returns
- Success: returns a table of thread handles and the errorMsg is set to nil.
- Failure: nil is returned, and the errorMsg parameter contains an error message.
Note: a nil, nil return means that the thread has no children.
####  Usage:
    local child_h, errorMsg = thread:getChildren( parent_h )
    if not child_h then 
        print( errorMsg, errorMsg[2] ) 
    end
@End]]

function thread:getChildren(parent_h)
    local fname = "thread:getChildren()"
    local errorMsg = nil
    

    if parent_h == nil then
        return H[TH_CHILDREN], nil
    end

    local isValid, errorMsg = handleIsValid( parent_h )
    if not isValid then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), errorMsg, fname )
        return nil, errorMsg
    end

    return parent_h[TH_CHILDREN], nil
end
--[[@Begin
### Signature: value, errorMsg = thread:sendSignal( target_h, signaValue [,...] )
####  Description:  Sends a signal to the specified thread. Note: a return value of
true only means the signal was delivered. It does mean the signal has been seen
by the target thread.
####  Parameters: 
- thread_h (handle): The thread to which the signal is to be sent. 
- signalValue (number): the signal being sent.
- ... (varargs, optional) Data (including functions) to be passed to the receiving thread.
####  Returns:
- If successful: value = non-nil. A non-nil value means that the signal was 
inserted into the target thread's signal queue.
- If not successful, nil is returned along with an errorMsg
####  Usage:
    local wasSent, errorMsg = thread:sendSignal( target_h, thread.signal, data )
    if not wasSent then 
        error( errorMsg )
    end
@End]]
function thread:sendSignal( target_h, signal, ... )
    local fname = "thread:sendSignal()"
    local errorMsg = nil
    
    if target_h == nil then
        local st = debugstack(2)
        -- post:message( string.format("%s\n", st ))
        errorMsg = formatErrorMsg(utils:dbgPrefix(), L["THREAD_HANDLE_NIL"], fname )
        return false, errorMsg
    end
    local isValid, errorMsg = handleIsValid( target_h )
    if not isValid then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), errorMsg, fname )
        return false, errorMsg
    end
    isValid, errorMsg = signalIsValid(signal)
	if not isValid then
        errorMsg = formatErrorMsg(utils:dbgPrefix(), errorMsg, fname )
        return false, errorMsg
    end
    local sigName, errorMsg = thread:getSignalName( signal )
    if not sigName then 
        return false, errorMsg
    end
    if handleIsInMorgue( target_h ) then
        errorMsg = formatErrorMsg( utils:dbgPrefix(), L["THREAD_IS_DEAD"], fname )
        -- post:message( string.format("%s - Thread[%d]\n%s\n", errorMsg, thread_h[TH_UNIQUE_ID], debugstack(2) ))
        return false, errorMsg
    end

	-- Initialize and insert an entry into the recipient thread's signalTable
    local sender_h = CALLING_THREAD
	local sigEntry = {signal, sender_h, packArgs(...) }

    table.insert( target_h[TH_PENDING_SIGNALS], sigEntry )

	if signal == SIG_ALERT then
        target_h[TH_REMAINING_TICS] = 1
    end

	return true, nil
end
--[[@Begin
### Signature: 
    local signal, sender_h, ... = thread:getSignal()
####  Description:  
The retrieval semantics of the thread's signal queue is FIFO. Retrieving
a signal removes and returns the signal that has been waiting in the
calling thread's signal queue the longest.

SIG_NONE_PENDING is returned when the queue is empty. This is a normal
condition and does not indicate an error.

This service may only be called from thread context. Calling it from the
game client (WoW.exe) is a programming error and raises an exception.
####  Parameters:
- signal (number): 
- sender_h (thread handle): the handle of the thread that sent the signal.
- ... (varargs): any additional data associated with the signal.
####  Returns:
- SIG_NONE_PENDING: Returned when no signals are pending in the calling thread's
    signal queue.
- signal (number): The signal identifier.
- sender_h (thread handle): The handle of the thread that sent the signal.
- ... (varargs):
    Any payload associated with the signal.
####  Usage:
@End]]
function thread:getSignal()
    local fname = "thread:getSignal()"
    
    local H = CALLING_THREAD

    if #H[TH_PENDING_SIGNALS] == 0 then        
        return SIG_NONE_PENDING, nil, nil
    end

    local sigEntry = table.remove( H[TH_PENDING_SIGNALS], 1 )
    if sigEntry[SIG_PAYLOAD] then
        return sigEntry[SIG_SIGNAL],
               sigEntry[SIG_SENDER],
               unpackArgs(sigEntry[SIG_PAYLOAD])
    end

    return sigEntry[SIG_SIGNAL], sigEntry[SIG_SENDER]
end
--[[@Begin
### Signature: 
    local signalName, errorMsg = thread:getSignalName( signal )
####  Description:  
    Gets the string name of the specified signal value. for example, when 
    submitting the numerical constant, the service returns the string, 
    "SIG_ALERT"
####  Parameters:
- signal (number): the numerical signal whose name is to be returned.
####  Returns:
- Success: returns the name associated with the signal value and the errorMsg is set to nil.
- Failure: nil is returned, and the errorMsg parameter contains an error message.)
####  Usage:
    ```local signalName, errorMsg = thread:getSignalName( signal )
    if signalName == nil then print( errorMsg ) return end```
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

--========================================================
--          THREAD MANAGEMENT SERVICES
--========================================================
function thread:debuggingIsEnabled()
    return debuggingIsEnabled
end
function thread:enableDebugging()
    debuggingIsEnabled = true
end
function thread:disableDebugging()
    debuggingIsEnabled = false
end
--[[@Begin
### Signature: 
    local signalCount, errorMsg = thread:getSignalCount()
####  Description:  
    Gets the number of pending signals for the calling thread. Note, the function
    is always fatal if the caller is not a thread.
####  Parameters:
- None
####  Returns:
- Success: returns the number of the threads waiting to be retrieved (i.e., in
the thread's signal queue). The errorMsg parameter will be nil.
- Failure: nil is returned, and the errorMsg parameter contains an error message.
####  Usage:
    ```local sigCount, errorMsg = thread:getNumPendingSignals( thread_h )
    if signalCount == nil then 
        print( errorMsg, errorMsg[2]) return end```
@End]]
function thread:countPendingSignals( H )
    local fname = "thread:countPendingSignals()"
    

    if not H then 
        return #CALLING_THREAD[TH_PENDING_SIGNALS]
    end
    local isValid, errorMsg = handleIsValid(H)
    if not isValid then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), errorMsg, fname )
        return nil, errorMsg
    end
    return #H[TH_PENDING_SIGNALS]
end
--[[@Begin
### Signature: 
    local metrics, errorMsg  = thread:getMetrics( thread_h )
####  Description:  
    Gets some some basic execution metrics; the runtime (ms) and congestion 
    (how long the thread had to wait to begin execution after having been 
    resumed). Note: at this point, only completed threads can be queried.
####  Parameters:
- thread_h (handle): the handle of the thread whose metrics are to be retrieved.
- ####  Returns: 
    - entry = {threadId, lifetime, ticsPerYield, resumptions }
    - nil or errorMsg
####  Usage:
    local metrics,errorMsg = thread:getMetrics( thread_h )
@End]]
function thread:getMetrics( H )
    local fname = "thread:getMetrics()"

    if H == nil then
        local errorMsg = formatErrorMsg( utils:dbgPrefix(), L["PARAMETER_NIL"], fname )
        return nil, errorMsg
    end
    if not coroutineIsDead(H) then
        local errorMsg = formateErrorMsg( utils:dbgPrefix(), L["THREAD_NOT_COMPLETED"], fname )
        return nil, errorMsg
    end
    local stats, errorMsg = getThreadStats( H )
    if stats == nil then
        local errorMsg = formatErrorMsg( utils:dbgPrefix() , errorMsg, fname )
		return nil, errorMsg
    end
	return stats, nil
end
--=========================================================
--           NEW FRAME-BASED SCHEDULER
--=========================================================
local function scheduleThreads()
    if #threadControlBlock == 0 then
        return
    end
    
    -- select the thread to be resumed and pass it to
    -- resumeThread() function
    for i = #threadControlBlock, 1, -1 do
        local H = threadControlBlock[i]
        local co = H[TH_COROUTINE]
        local status = coroutine.status(co)

        if status == "suspended" then
            H[TH_REMAINING_TICS] = H[TH_REMAINING_TICS] - 1
            if H[TH_REMAINING_TICS] <= 0 then
                H[TH_REMAINING_TICS] = H[TH_TICS_PER_YIELD]
				---------------------------------------
                local success, errorMsg = resumeThread(H)
                ---------------------------------------
            end
        end
    end
end

local schedulerFrame            = nil
local schedulerInitialized      = false
local accumulator               = 0
local schedulerFrame            = nil
local schedulerInitialized      = false

local function schedulerOnUpdate(_, elapsed)
    accumulator = accumulator + elapsed
    while accumulator >= WoWClockTicInterval do
        accumulator = accumulator - WoWClockTicInterval
        scheduleThreads()
    end
end

function thread:mgmtBootstrap()
    if schedulerInitialized then
        return
    end
    schedulerFrame = CreateFrame("Frame")
    schedulerFrame:SetScript(
        "OnUpdate",
        schedulerOnUpdate
    )
    schedulerInitialized = true
end
