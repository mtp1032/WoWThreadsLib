--=================================================================================
-- Filename: TestSignalsOne.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
--============= PASSES TESTS =================
local ADDON_NAME, ns = ...

ns.TestSignalsOne   = ns.TestSignalsOne or {}
TestSignals         = ns.TestSignalsOne
local post          = ns.PostMessages
local core          = ns.Core
local utils         = ns.UtilsLib
local L             = ns.Locales.L

if not ns.CollectResults.loaded then
    utils:dbgPrint( "Failed to load CollectResults.lua")
    return 
end

local _, localizedVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error( L["THREAD_LIB_NOT_FOUND"] )
end
 
local SIG_READY           = thread.SIG_READY
local SIG_START           = thread.SIG_START
local SIG_STOP            = thread.SIG_STOP
local SIG_COMPLETE        = thread.SIG_COMPLETE
local SIG_ALERT           = thread.SIG_ALERT
local SIG_CONDITION_MET   = thread.SIG_CONDITION_MET
local SIG_TERMINATE       = thread.SIG_TERMINATE
local SIG_NONE_PENDING    = thread.SIG_NONE_PENDING
 
-- namespace shorcuts
local post      = ns.PostMessages
local collect   = ns.CollectResults
local L         = ns.Locales.L

local main_h = nil
local collector_h = nil
local runTests_h = nil
local testResults = {}

-- unit tests
local function runTest1()
    return {1, 2, "buckle my shoe"}
end
local function runTest2()
    return {3, 4, "shut the door"}
end
local function runTest3()
    return {5, 6, "pick up sticks"}
end
local function runTest4()
    return {7, 8, "don't be late."}
end

local function stringFormatter( prefix, str )
    str = string.format("%s %s\n", prefix, str )
    return str 
end
-- this function executes the unit tests
local function runTests()
    local DONE = false

    post:message( stringFormatter( utils:dbgPrefix(), "Entered runTests"))

    while not DONE do 
        local signal, sender_h = thread:getSignal()
        if signal == SIG_START then
            thread:yield()
            table.insert( testResults, runTest1() )
            table.insert( testResults,  runTest2() )
            table.insert( testResults,  runTest3() )
            table.insert( testResults,  runTest4() )
            DONE = true
        end
    end

    local wasSent, errorMsg = thread:sendSignal( main_h, SIG_COMPLETE, testResults )
    assert( wasSent, errorMsg )
    post:message( stringFormatter(utils:dbgPreface(), "runTests: normal completion"))
end

local function main()
    local DONE = false
    local errorMsg = nil

    -- create the test runner thread, runTests_h
    runTests_h, errorMsg = thread:create( 20, runTests )
    if not runTests_h then
        post:message( string.format("%s %s\n", utils:dbgPrefix(), errorMsg))
        return
    end
    post:message( string.format("%s %s\n", utils:dbgPrefix(), "Created runTest_h"))
    local wasSent, errorMsg = thread:sendSignal( runTests_h, SIG_START )
    if not wasSent then
        post:message( string.format("%s %s\n", utils:dbgPrefix(), errorMsg ))
        return
    end
    post:message( string.format("%s main sent SIG_START to receiver\n", utils:dbgPrefix() ))

    -- wait for the runner thread to signal that it has competed the tests
    while not DONE do
        thread:yield()
        local signal = nil
        local tests = nil

        signal, sender_h, tests = thread:getSignal()

        -- the runner thread has completed the tests. The results are in
        -- the tests table returned by the previouis getSignal(). Send the
        -- resuts to the collector (collector_h)
        if signal == SIG_COMPLETE then
            post:message(string.format("%s Received SIG_COMPLETE.\n", utils:dbgPrefix() ))
            wasSent, errorMsg = thread:sendSignal(collector_h, SIG_COMPLETE, tests )
            assert( wasSent, errorMsg )
            DONE = true 
        end
    end
end

local function startTest()
    local errorMsg = nil
    thread:enableDebugging()

    main_h, errorMsg = thread:create(50, main )
    assert( main_h, errorMsg )

    collector_h = collect:getCollectorHandle()
end

function TestSignals:startTest()
    startTest()
end
startTest()