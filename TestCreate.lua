--=================================================================================
-- Filename: TestCreate.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
ns.TestCreate   = ns.TestCreate or {}

local test      = ns.TestCreate
local core      = ns.Core
local utils     = ns.UtilsLib
local collect   = ns.CollectResults
local post      = ns.PostMessages

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

local boss_h    = nil
local worker_h  = nil
local collector_h = nil  -- to be wired in later

local function signalHelper(sigEntry)
    return sigEntry[1], sigEntry[2], sigEntry[3]
end

-- a simulated unit test
local function unitTestOne()
    local sigEntry = nil
    local signal = signalHelper( sigEntry )
    return true
end

-- this is the worker's function and its purpose is to execute
-- the unit tests. In this case, there is just one unit test.
local function workerFunction()
    local DONE = false
    local wasSent = nil
    local errorMsg = nil
    local testResult = nil
    local collector_h = collect:getCollectorHandle()

    -- Tell boss we’re ready
    wasSent, errorMsg = thread:sendSignal(boss_h, SIG_READY)
    assert(wasSent, errorMsg)

    while not DONE do

        -- Wait for work or termination
        thread:yield()

        local sigEntry, errorMsg = thread:getSignal()
        assert(sigEntry, errorMsg)
        local signal, sender_h, testResults = signalHelper( sigEntry )
        -- execute all the unit tests, in this case there is only one
        if signal == SIG_START then 
            local testResult = nil

            local sigName, errorMsg = thread:getSignalName( signal )
            assert( sigName, errorMsg )
            assert( sigName == "SIG_START", "signal is not SIGNAL_START")

            utils:dbgPrint( "received", sigName )
            -- success for this test is for the unitTestOne() to fail. In other words,
            -- we take a failed result to be a success.
            local testWasSuccessful, testResult = pcall( unitTestOne )
            if not testWasSuccessful then
                -- Example: PASS: unitTestOne() detected the Lua error (@TestCreate.lua:70).
                local testName = "unitTestOne()"
                local result = "PASS"
        
                local testResult = string.format( "%s %s.\nSTACK TRACE: %s).\n", testName, result, testResult)
                wasSent, errorMsg = thread:sendSignal( collector_h, SIG_CONDITION_MET, testResult )
                assert( wasSent, errorMsg )
            end
            -- Notify boss this job is complete.
            local wasSent, errorMsg = thread:sendSignal(boss_h, SIG_COMPLETE)
            assert(wasSent, errorMsg )

            DONE = true     -- because we only had one test to execute
        end
    end
end

local function boss()
    local DONE = false
    local sigEntry = nil
    local errorMsg = nil
    local wasSent = nil

    worker_h, err = thread:create(50, workerFunction)
    assert(worker_h, err)

    while not DONE do
        -- wait for a worker's SIG_READY signal
        thread:yield()
        local sigEntry, errorMsg = thread:getSignal()
        assert(sigEntry, errorMsg)

        local signal, sender_h = signalHelper(sigEntry)

        if signal == SIG_READY then
            local wasSent, errorMsg = thread:sendSignal(worker_h, SIG_START)
            assert(wasSent, errorMsg)
        elseif signal == SIG_COMPLETE then
            -- since there is only one test, we will terminate the worker and exit the loop.
            local wasSent, errorMsg = thread:sendSignal(worker_h, SIG_TERMINATE)
            if not wasSent then
                error( errorMsg )
            end
            DONE = true
        end
    end
end

