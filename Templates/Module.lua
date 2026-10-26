--=================================================================================
-- Filename: Template.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
ns.Template   = ns.Template or {}

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
 
-- thread handles
local boss_h    = nil
local worker_h  = nil
local collector_h = nil  -- to be wired in later

local function signalHelper(sigEntry)
    return sigEntry[1], sigEntry[2], sigEntry[3]
end

-- Unit Tests
local function unitTestOne()
    -- code to be tested
end
local function unitTestTwo()
end
local function unitTestThree()
end

-- this is the worker's function. The function forms the
-- worker thread's action routine and contains the unit tests
-- to be execute.
local function workerFunction()
    local DONE = false
    local wasSent = nil
    local errorMsg = nil
    local testResults = {}

    -- Tell control thread (manager_h, controller_h, boss_h, etc.,)
    wasSent, errorMsg = thread:sendSignal(boss_h, SIG_READY)
    assert(wasSent, errorMsg)

    while not DONE do

        -- Wait for work or termination
        thread:yield()

        local sigEntry, errorMsg = thread:getSignal()
        assert(sigEntry, errorMsg)
        local signal, sender_h, testResults = signalHelper( sigEntry )

        if signal == SIG_TERMINATE then return end
        --========================================================
        --                  UNIT TESTS
        --========================================================
        if signal == SIG_START then 
            -- 1. Unit Test
            local testWasSuccessful, strMsg = pcall( unitTestOne )
            if not testWasSuccessful then
                local testName = "unitTestOne()"
                local result = "PASS"
        
                local formattedStr = string.format( "%s %s.\nSTACK TRACE: %s).\n", testName, result, testResult)
                wasSent, errorMsg = thread:sendSignal( collector_h, SIG_CONDITION_MET, testResult )
                assert( wasSent, errorMsg )
            end

            -- 2. Unit Test
            local testWasSuccessful, strMsg = pcall( unitTestTwo )
            if not testWasSuccessful then
                local testName = "unitTestOne()"
                local result = "PASS"
        
                local formattedStr = string.format( "%s %s.\nSTACK TRACE: %s).\n", testName, result, testResult)
                wasSent, errorMsg = thread:sendSignal( collector_h, SIG_CONDITION_MET, testResult )
                assert( wasSent, errorMsg )
            end

            -- 3. Unit Test
            local testWasSuccessful, strMsg = pcall( unitTestThree )
            if not testWasSuccessful then
                local testName = "unitTestOne()"
                local result = "PASS"
        
                local formattedStr = string.format( "%s %s.\nSTACK TRACE: %s).\n", testName, result, testResult)
                wasSent, errorMsg = thread:sendSignal( collector_h, SIG_CONDITION_MET, testResult )
                assert( wasSent, errorMsg )
            end
        end
    end
end
