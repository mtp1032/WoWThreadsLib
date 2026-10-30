--=================================================================================
-- Filename: ParamFailures.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.ParamFailures    = ns.ParamFailures or {}
local core          = ns.Core
local L             = ns.Locales.L

local _, localizedVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error( L["THREAD_LIB_NOT_FOUND"] )
end
 
local SIG_READY         = thread.SIG_READY
local SIG_START         = thread.SIG_START
local SIG_COMPLETE      = thread.SIG_COMPLETE
local SIG_ALERT         = thread.SIG_ALERT
local SIG_CONDITION_MET = thread.SIG_CONDITION_MET
local SIG_CREATE_THREAD = thread.SIG_CREATE_THREAD
local SIG_TERMINATE     = thread.SIG_TERMINATE
local SIG_NONE_PENDING  = thread.SIG_NONE_PENDING
 
-- namespace shorcuts
local utils     = ns.UtilsLib
local collect   = ns.CollectResults
local post      = ns.PostMessages
local params    = ns.ParamFailures
local L         = ns.Locales

-- local thread handles
local collector_h = collect:getCollectorHandle() -- to be wired in later

-- Unit Tests

local function unitTestOne()
    local sigEntry = nil
    local signal = sigEntry[1] -- index a nil value
    return
end
local function unitTestTwo()
    local dummy_h, errorMsg = thread:create( 50, invalidSignal)
    if not dummy_h then error( errorMsg ) end

end
local function unitTestThree() -- Invalid parameter type
    local dummy_h, errorMsg = thread:create( "50", invalidSignal)
    if not dummy_h then error( errorMsg ) end
end
local function testWrapper()
    local DONE = false
    local wasSent = nil
    local errorMsg = nil
    local tableTestResults = {}

    while not DONE do
        local succeeded = nil

        -- Wait for work or termination
        thread:yield()

        local sigEntry, errorMsg = thread:getSignal()
        assert(sigEntry, errorMsg)

        local signal, sender_h, payload = utils:signalHelper( sigEntry )
        if signal == SIG_TERMINATE then 
            thread:exit( "Hello world")
        end

        --========================================================
        --                  UNIT TEST 1
        --========================================================    
        if signal == SIG_START then
        
            local succeeded, testResult = pcall( unitTestOne )
            if not succeeded then
                local testName = "Detected attempt to index a nil value"
                local result = "PASS"
                local infoStr = string.format( "[%s]: %s\nSTACK - %s)\n", result, testName, utils:strip(testResult) )
                table.insert( tableTestResults, infoStr )
            end

            --====================================================================
            --                      UNIT TEST 2
            --====================================================================            local succeeded, testResult = pcall( unitTesTwo )
            local succeeded, testResult = pcall( unitTestTwo )
            if not succeeded then
                local testName = "thread:create() - Detected invalid thread function"
                local result = "PASS"
        
                local infoStr = string.format( "[%s]: %s\nSTACK - %s)\n", result, testName, utils:strip(testResult) )
                table.insert( tableTestResults, infoStr )
            end

            --====================================================================
            --                      UNIT TEST 3
            --====================================================================
            local succeeded, testResult = pcall( unitTestThree )
            if not succeeded then
                local testName = "thread:create() - Detected invalid 'tic'"
                local result = "PASS"
        
                local infoStr = string.format( "[%s]: %s\nSTACK - %s)\n", result, testName, utils:strip(testResult) )
                table.insert( tableTestResults, infoStr )
            end
        end -- if SIG_START
        DONE = true
    end
    utils:dbgPrint( tostring( #tableTestResults ))
    wasSent, errorMsg = thread:sendSignal( collector_h, SIG_COMPLETE, tableTestResults )
    table.insert( tableTestResults, infoStr )
    assert( wasSent, errorMsg )
end
local function main()
    testWrapper_h, errorMsg = thread:create(50, testWrapper)
    assert( testWrapper_h, errorMsg )

    local wasSent, errorMsg = thread:sendSignal(testWrapper_h, SIG_START)
    assert(wasSent, errorMsg)
end
main()

