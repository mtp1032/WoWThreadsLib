--=================================================================================
-- Filename: SuiteThreads.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.SuiteThreads    = ns.SuiteThreads or {}
if not ns.CollectResults.loaded then
    print( "CollectResults.lua not loaded!")
    return
end

local collect = ns.CollectResults
local core  = ns.Core
local utils = ns.UtilsLib
local post  = ns.PostMessages
local L     = ns.Locales.L

local _, localizedVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error( L["THREAD_LIB_NOT_FOUND"] )
end
 
local SIG_READY           = thread.SIG_READY
local SIG_START           = thread.SIG_START
local SIG_STOP            = thread.SIG_STOP
local SIG_TASK_COMPLETE   = thread.SIG_TASK_COMPLETE
local SIG_ALERT           = thread.SIG_ALERT
local SIG_CONDITION_MET   = thread.SIG_CONDITION_MET
local SIG_TERMINATE       = thread.SIG_TERMINATE
local SIG_NONE_PENDING    = thread.SIG_NONE_PENDING

local main_h = nil
local threadTests_h = nil
local dead_h = nil
local sleeper_h = nil
local dummy_h = nil
local function dead(...)
    local threadName =...
    thread:yield()
    local _, Id = thread:getSelf()
end
local function sleeping(...)
    local threadName = ...
    local self_h, Id = thread:getSelf()
    local DONE = false

    while not DONE do
        local start = debugprofilestop()
        thread:sleep()
        local elapsedMs = debugprofilestop() - start
        -- wait around to see if anyone wants to send a signal.
        thread:yield()
        local signal, sender_h thread:getSignal()
        while signal ~= SIG_NONE_PENDING do
            if signal == SIG_TERMINATE then
                DONE = true 
            end
            local wasSent = thread:sendSignal( threadTests_h, SIG_READY, threadName, elapsedMs )
        end
    end
end
local function dummy(...)
    local threadName = ...
    local DONE = false

    while not DONE do
        thread:yield()
        local signal, sender_h, payload = thread:getSignal()
        if signal == SIG_TERMINATE then
            DONE = true 
        end
    end
end

-- here are the individual unit test functions, each of which is executed within
--its own thread.
local function threadTests(...)
    local threadName = ...
    local DONE = false
    local testResults = {}

    thread:yield()
    --                    THREAD CREATE
    local thread_h, errorMsg = thread:create("tics_per_yield", dummy )
    if thread_h == nil then
        local pass = "PASS (thread:create()  "
        local descr = "Test: Tics invalid type"
        table.insert( testResults, {pass, descr, errorMsg })
    end
    local thread_h, errorMsg = thread:create(nil, dummy )
    if thread_h == nil then
        local pass = "PASS (thread:create()  "
        local descr = "Test: tics nil param"
        table.insert( testResults, {pass, descr, errorMsg })
    end
    local thread_h, errorMsg = thread:create(30, "dummy" )
    if thread_h == nil then
        local pass = "PASS (thread:create()  "
        local descr = "Test: function invalid type"
        table.insert( testResults, {pass, descr, errorMsg })
    end
        local thread_h, errorMsg = thread:create(30, nil )
    if thread_h == nil then
        local pass = "PASS (thread:create()  "
        local descr = "Test: function nil."
        table.insert( testResults, {pass, descr, errorMsg })
    end

    thread:yield()
    --                    THREAD DELAY & SLEEP & WAkEUP
    local tics = nil
    local thread_h, errorMsg = thread:delay()
    if thread_h == nil then
        local pass = "PASS (thread:delay() - "
        local descr = "Test: tics nil param"
        table.insert( testResults, {pass, descr, errorMsg })
    end
    local tics = "tics"
    local thread_h,errorMsg = thread:delay( tics )
    if thread_h == nil then
        local pass = "PASS (thread:delay() - "
        local descr = "Test: tics Invalid type"
        table.insert( testResults, {pass, descr, errorMsg })
    end
    local tics = "tics"
    local thread_h,errorMsg = thread:delay( tics )
    if thread_h == nil then
        local pass = "PASS (thread:wakeup() - "
        local descr = "Test: Invalid handle"
        table.insert( testResults, {pass, descr, errorMsg })
    end
    local nilHandle_h = nil
    local awake, errorMsg = thread:wakeup( nilHandle_h )
    if not awake then
        local pass = "PASS (thread:wakeup() - "
        local descr = "Test: nil handle"
        table.insert( testResults, {pass, descr, errorMsg })
    end
    local badHandle_h = {}
    local awake, errorMsg = thread:wakeup( badHandle_h )
    if not awake then
        local pass = "PASS (thread:wakeup() - "
        local descr = "Test: Invalid or malformed handle"
        table.insert( testResults, {pass, descr, errorMsg })
    end 
    local awake, errorMsg = thread:wakeup( dummy_h )
    if not awake then
        local pass = "PASS (thread:wakeup() - "
        local descr = "Test: handle valid, but not sleeping"
        table.insert( testResults, {pass, descr, errorMsg })
    end
--==============================    END THREAD PARAMETER TESTS ==================

    -- local asleep, errorMsg = thread:isSleeping( sleeper_h )
    -- if asleep then
    --     asleep, errorMsg = thread:wakeup( sleeper_h )
    --     utils:dbgPrint( tostring( asleep ))
    --     local signal, _, handleName, elapsedMs  = thread:getSignal()
    --     if signal == SIG_READY then
    --         post:message("Elapsed time for %s: %2.f ms\n", handleName, elapsedMs )
    --     end
    -- end

    local collector_h = collect:getCollectorHandle()
    local testName = "Thread Parameter Validity Tests."
    local wasSent, errorMsg = thread:sendSignal( collector_h, SIG_TASK_COMPLETE, testName, testResults )
    assert( wasSent, errorMsg )

    local wasSent, errorMsg = thread:sendSignal( main_h, SIG_TERMINATE )
    assert( wasSent, errorMsg )
    return testResults
end

local function main(...)
    local DONE = false
    local args1, args2, args3 = ...

    -- create the target threads. These are largely dummy threads
    -- for test purposes only.
    dummy_h, errorMsg = thread:create( 30, dummy, "dummy_h" )
    sleeper_h, errorMsg = thread:create( 30, sleeping, "sleeper_h" )
    dead_h, error_msg = thread:create( 30, dead, "dummy_h" )

    -- Create the driver thread. This executes all of the unit tests
    local threadTests_h, errorMsg = thread:create( 50, threadTests, "threadTests_h" )
    assert( threadTests_h, errorMsg )

    while not DONE do
        thread:yield()
        local signal = thread:getSignal()
        assert( signal, "Assert Failure: no signal returned")
        if signal == SIG_TERMINATE then
            DONE = true 
        end
    end
end

local function startSuite()
    thread:enableDebugging()

    -- this thread is the control thread.
    main_h, errorMsg = thread:create( 30, main )
    assert( main_h, errorMsg )
end

startSuite()