--=================================================================================
-- Filename: SuiteTemplate.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.SuiteTemplate    = ns.SuiteTemplate or {}

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
    thread:sleep()
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
local function unitTest1(...)
    local threadName = ...
    local DONE = false
    local testResults = {}

    thread:yield()
    --====================================================================
    --                              THREAD CREATE
    --====================================================================
    local thread_h, errorMsg = thread:create("tics_per_yield", dummy )
    if thread_h == nil then
        local pass = "PASS (thread:create()  "
        local descr = "Tics param invalid type"
        table.insert( testResults, {pass, descr, errorMsg })
    end
    local thread_h, errorMsg = thread:create(30, "dummy" )
    if thread_h == nil then
        local pass = "PASS (thread:create()  "
        local descr = "Function param invalid type"
        table.insert( testResults, {pass, descr, errorMsg })
    end
    local thread_h, errorMsg = thread:create(nil, dummy )
    if thread_h == nil then
        local pass = "PASS (thread:create()  "
        local descr = "Tics param nil"
        table.insert( testResults, {pass, descr, errorMsg })
    end
    local thread_h, errorMsg = thread:create(30, nil )
    if thread_h == nil then
        local pass = "PASS (thread:create()  "
        local descr = "Function param nil."
        table.insert( testResults, {pass, descr, errorMsg })
    end
    thread:yield()
    --====================================================================
    --                              THREAD DELAY
    --====================================================================
    local tics = nil
    local thread_h, errorMsg = thread:delay()
    if thread_h == nil then
        local pass = "PASS (thread:delay() - "
        local descr = "Tics param nil"
        table.insert( testResults, {pass, descr, errorMsg })
    end
    local tics = "tics"
    local thread_h,errorMsg = thread:delay( tics )
    if thread_h == nil then
        local pass = "PASS (thread:delay() - "
        local descr = "Tics param nil"
        table.insert( testResults, {pass, descr, errorMsg })
    end
    thread:yield()
    --====================================================================
    --                           SIGNALS
    --====================================================================
    local bad_h = {}
    local wasSent, errorMsg = thread:sendSignal( bad_h, SIG_START )
    if not wasSent then
        local pass = "PASS (thread:sendSignal()"
        local descr = "Bad handle test."
        table.insert( testResults, {pass, descr, errorMsg })
    end
    -- signal to low: out of range
    local wasSent, errorMsg = thread:sendSignal( dummy_h, SIG_READY - 1)
    if not wasSent then
        local pass = "PASS (thread:sendSignal() - "
        local descr = "Invalid signal: too small."
        table.insert( testResults, {pass, descr, errorMsg })
    end
    -- signal too high: out-of-range
    local wasSent, errorMsg = thread:sendSignal( dummy_h, SIG_NONE_PENDING + 1)
    if not wasSent then
        local pass = "PASS (thread:sendSignal()"
        local descr = "Invalid signal: too high."
        table.insert( testResults, {pass, descr, errorMsg })
    end
    local wasSent, errorMsg = thread:sendSignal( sleeper_h, SIG_READY )
    if not wasSent then
        local pass = "PASS (thread:sendSignal()"
        local descr = "Attempted to signal sleeping thread."
        table.insert( testResults, {pass, descr, errorMsg })
    end
    -- send signal to dead thread
    local wasSent, errorMsg = thread:sendSignal( dead_h, SIG_READY)
    if not wasSent then
        local pass = "PASS (thread:sendSignal()"
        local descr = "Attempt to signal a dead thread"
        table.insert( testResults, {pass, descr, errorMsg })
    end
    thread:yield()

    local wasSent, errorMsg = thread:sendSignal( main_h, SIG_TASK_COMPLETE, testResults )
    assert( wasSent, errorMsg )

    return testResults
end

local function main(...)
    local DONE = false
    local args1, args2, args3 = ...

    -- create the target threads
    dummy_h, errorMsg = thread:create( 30, dummy, "dummy_h" )
    sleeper_h, errorMsg = thread:create( 30, sleeping, "sleeper_h" )
    dead_h, error_msg = thread:create( 30, dead, "dummy_h" )

    -- Create the driver thread. This executes all of the unit tests
    local unitTest1_h, errorMsg = thread:create( 50, unitTest1, "unitTest1_h" )
    assert( unitTest1_h, errorMsg )

    while not DONE do
        thread:yield()
        local signal, _, results = thread:getSignal()
        if signal == SIG_TASK_COMPLETE then
            thread:yield()
            for _, entry in ipairs(results) do
                local str = string.format("%s: %s\n%s\n", entry[1], entry[2], entry[3])
                post:message( str )
            end    
            DONE = true
        end
    end
    thread:sendSignal( dummy_h, SIG_TERMINATE)
    thread:wakeup( sleeper_h)
end

local function startSuite()
    thread:disableDebugging()

    -- this thread is the control thread.
    main_h, errorMsg = thread:create( 30, main )
    assert( main_h, errorMsg )
end

startSuite()