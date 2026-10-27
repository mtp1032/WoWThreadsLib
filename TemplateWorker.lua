--=================================================================================
-- Filename: Template.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
ns.TemplateWorker   = ns.TemplateWorker or {}
local template  = ns.TemplateWorker
local core      = ns.Core
local utils     = ns.UtilsLib
local collect   = ns.CollectResults
local post      = ns.PostMessages
local L         = ns.Locales.L

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


-- thread handles
local collector_h = collect:getCollectorHandle() -- to be wired in later

local function signalHelper(sigEntry)
    return sigEntry[1], sigEntry[2], sigEntry[3]
end

-- Unit Tests
local function unitTestOne()
    local sigEntry = nil
    local signal = sigEntry[1] -- index a nil value
    return
end
local function unitTestTwo()
    local dummy_h, errorMsg = thread:create( 50, "signalHelper")
    if not dummy_h then error( errorMsg ) end

end
local function unitTestThree() -- Invalid parameter type
    local dummy_h, errorMsg = thread:create( "50", signalHelper)
    if not dummy_h then error( errorMsg ) end
end

-- this is the worker's function. The function forms the
-- worker thread's action routine and contains the unit tests
-- to be execute.
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

        local signal, sender_h, payload = signalHelper( sigEntry )
        if signal == SIG_TERMINATE then return end

        if signal == SIG_START then 
        --========================================================
        --                  UNIT TEST 1
        --========================================================
            local succeeded, testResult = pcall( unitTestOne )
            if not succeeded then
                local testName = "Detected attempt to index a nil value"
                local result = "PASS"
        
                local infoStr = string.format( "[%s]: %s\nSTACK - %s)\n", result, testName, testResult )
                table.insert( tableTestResults, infoStr )
                utils:dbgPrint( tostring( #tableTestResults))
            end

            --====================================================================
            --                      UNIT TEST 2
            --====================================================================            local succeeded, testResult = pcall( unitTesTwo )
            local succeeded, testResult = pcall( unitTestTwo )
            if not succeeded then
                local testName = "thread:create() - Detected invalid thread function"
                local result = "PASS"
        
                local infoStr = string.format( "[%s]: %s\nSTACK - %s)\n", result, testName, testResult )
                table.insert( tableTestResults, infoStr )
                utils:dbgPrint( tostring( #tableTestResults))
            end

            --====================================================================
            --                      UNIT TEST 3
            --====================================================================
            local succeeded, testResult = pcall( unitTestThree )
            if not succeeded then
                local testName = "thread:create() - Detected invalid 'tic'"
                local result = "PASS"
        
                local infoStr = string.format( "[%s]: %s\nSTACK - %s)\n", result, testName, testResult )
                table.insert( tableTestResults, infoStr )
            end

            wasSent, errorMsg = thread:sendSignal( collector_h, SIG_COMPLETE, tableTestResults )
            assert( wasSent, errorMsg )
            DONE = true
        end
    end
end
local function main()
    local testWrapper_h, errorMsg = thread:create(50, testWrapper)
    assert( testWrapper_h, errorMsg )
    local wasSent, errorMsg = thread:sendSignal(testWrapper_h, SIG_START)
    assert(wasSent, errorMsg)
end

main()
