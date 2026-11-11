--=================================================================================
-- Filename: ThreadErrors.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.ThreadErrors   = ns.ThreadErrors or {}
local ThreadErrors    = ns.ThreadErrors
local core              = ns.Core
local utils             = ns.UtilsLib
local post              = ns.PostMessages
local L                 = ns.Locales.L
local collect           = ns.CollectResults


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

local unitTests_h = nil
local unitTest1_h = nil

-- local testResults = {
--     {1, 2, "buckle my shoe"},
--     {3, 4, "shut the door"}, 
--     {5, 6, "pick up sticks"},
--     {7, 8, "don't be late."},
--     {9, 10, "the big fat hen."}
-- }
local testResults = {}

local function unitTest1()
    local tbl = nil
    local var = tbl[1]

local function unitTest2()
    local wasSent, errorMsg = thread:create( "tics", unitTest1 )
    assert( wasSent, errorMsg )
end
end
local function unitTest3()
    local wasSent, errorMsg = thread:create( 50, func )
    assert( wasSend, errorMsg )
end
local function unitTest4()
    local wasSent, errorMsg = thread:sendSignal( unitTests_h, 0 )
    assert(wasSend, errorMsg )
end
local function unitTest5()
    local signal = SIG_NONE_PENDING + 1
    local wasSent, errorMsg = thread:sendSignal( unitTests_h, signal  )
    assert(wasSend, errorMsg )
end
local function unitTest6()
    local signal = nil
    local wasSent, errorMsg = thread:sendSignal( unitTests_h, signal )
    assert(wasSend, errorMsg )
end
local function unitTest7( ... )
    local param = ...
    if param == "Hello World" then
        error( "passArgs Succeeded.")
    end
end
local function unitTest8( parent_h)
    -- test that parent_h is the parent of this thread.
end

local function unitTests(...)
    local DONE = false
    collector_h = ...
    local testRecord = {}

    while not DONE do
        thread:yield()
--==============================================================================
--                          UNIT TEST 1
--==============================================================================
        local succeeded, testResult = pcall(unitTest1)
        if not succeeded then
            local result = "PASS" 
            local unitTestName = "unitTest1()"
            local testDescr = "Test for Lua errors"
            local testResult = utils:strip( testResult )
            local title = string.format("%s: %s", unitTestName, result )
            local descr = string.format("%s", testDescr )
            table.insert( testResults, {title, descr, testResult})            
        end

        --==============================================================================
        --                          UNIT TEST 2
        --==============================================================================
        local succeeded, testResult = pcall(unitTest2)
        if not succeeded then
            local result = "PASS"
            local unitTestName = "unitTest2()"
            local testDescr = "Test for invalid Parameter Type"
            local testResult = utils:strip( testResult )
            local title = string.format("%s: %s", unitTestName, result )
            local descr = string.format("%s", testDescr )
            table.insert( testResults, {title, descr, testResult})            
        end

        --==============================================================================
        --                          UNIT TEST 3
        --==============================================================================
        local succeeded, testResult = pcall(unitTest3)
        if not succeeded then
            local result = "PASS"
            local unitTestName = "unitTest3()"
            local testDescr = "Test for use of SIG_NON_PENDING"
            local testResult = utils:strip( testResult )
            local title = string.format("%s: %s", unitTestName, result )
            local descr = string.format("%s", testDescr )
            table.insert( testResults, {title, descr, testResult})            
        end

        --==============================================================================
        --                          UNIT TEST 4
        --==============================================================================
        local succeeded, testResult = pcall(unitTest4)
        if not succeeded then
            local result = "PASS"
            local unitTestName = "unitTest4()"
            local testDescr = "Test for invalid signal: Too low, out of range"
            local testResult = utils:strip( testResult )
            local title = string.format("%s: %s", unitTestName, result )
            local descr = string.format("%s", testDescr )
            table.insert( testResults, {title, descr, testResult})            
        end

        --==============================================================================
        --                          UNIT TEST 5
        --==============================================================================
        local succeeded, testResult = pcall(unitTest5)
        if not succeeded then
            local result = "PASS"
            local unitTestName = "unitTest5()"
            local testDescr = "Test for invalid signal: Too high, out of range"
            local testResult = utils:strip( testResult )
            local title = string.format("%s: %s", unitTestName, result )
            local descr = string.format("%s", testDescr )
            table.insert( testResults, {title, descr, testResult})            
        end

        --==============================================================================
        --                          UNIT TEST 6
        --==============================================================================
        local succeeded, testResult = pcall(unitTest6)
        if not succeeded then
            local result = "PASS"
            local unitTestName = "unitTest6()"
            local testDescr = "Test for nil signal"
            local testResult = utils:strip( testResult )
            local title = string.format("%s: %s", unitTestName, result )
            local descr = string.format("%s", testDescr )
            table.insert( testResults, {title, descr, testResult})            
        end


        DONE = true 
    end
    local wasSent, errorMsg = thread:sendSignal( collector_h, SIG_COMPLETE, testResults )
    assert( wasSent, errorMsg )
end

-- creates the two tests that will execute tests of sending and receiving signals with and without payloads
local function startTest()
    local errorMsg = nil

    thread:disableDebugging()

    local collector_h = collect:getCollectorHandle()
    unitTests_h, errorMsg = thread:create(30, unitTests, collector_h )
    assert( unitTests_h, errorMsg )
end

function ThreadErrors:start()
    startTest()
end
startTest()