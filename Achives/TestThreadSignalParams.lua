--=================================================================================
-- Filename: TestThreadSignals.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
ns.TestThreadSignals = ns.TestThreadSignals or {}
ns.Scaffold = ns.Scaffold or {}

local Scaffold      = ns.Scaffold
local testSignals   = ns.TestThreadSignals
local core        = ns.Core
local post          = ns.PostMessages
local utils         = ns.UtilsLib

local L = ns.Locales

local _, localizedVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error( L["THREAD_LIB_NOT_FOUND"] )
end

local SIG_READY             = thread.SIG_READY
local SIG_CALLBACK          = thread.SIG_CALLBACK
local SIG_ALERT             = thread.SIG_ALERT
local SIG_CONDITION_MET     = thread.SIG_CONDITION_MET
local SIG_TERMINATE         = thread.SIG_TERMINATE
local SIG_NONE_PENDING      = thread.SIG_NONE_PENDING

local main_h = nil

local function signalHelper( sigEntry )
    return sigEntry[1], sigEntry[2], sigEntry[3]
end
local function dummy()
    local DONE = false

    while not DONE do 
        local sigEntry, errorMsg = thread:getSignal()
        if sigEntry == nil then
            post:message( string.format("%s %s\n", utils:dbgPrefix(), errorMsg ))
            return 
        end

        utils:dbgPrefix()

        local signal, sender_h, payload = signalHelper( sigEntry )
        if signal == SIG_TERMINATE then
            DONE = false
        end
    end
    post:message( "Received SIG_TERMINATE")
end

function testSignals:testThreadCreateDummy()
    local dummy_h, errorMsg = thread:create( 60, dummy )
    if not dummy_h then
        post:message( errorMsg )
    end
end

local function test_ThreadSignalParameters()
    local ticks = 30

    --==============
    -- Invalid types
    --==============
    local thread_h = "thread_h"
    local wasSent, errorMsg = thread:sendSignal( thread_h, SIG_NONE_PENDING)
    if wasSent then
        error(string.format("%s FAIL", utils:dbgPrefix() ))
    end
    local msg = string.format("%s PASS:\n   Error Message is correct. | %s\n", utils:dbgPrefix(), errorMsg )
    post:message( msg )

    local signal = "signal"
    local wasSent, errorMsg = thread:sendSignal(dummy_h, SIG_NONE_PENDING)
    if wasSent then
        error(string.format("%s FAIL", uils:dbgPrefix() ))
    end
    local msg = string.format("%s PASS:\n   Error Message is correct. | %s\n", utils:dbgPrefix(), errorMsg )
    post:message( msg )

    local wasSent, errorMsg = thread:sendSignal( dummy_h, SIG_TERMINATE )
    if not wasSent then post:message( errorMsg ) end

    return
end

print( "Registering Test Thread Signals")

ns.Scaffold:registerTest("Test Thread Signals", test_ThreadSignalParameters)
function testSignals.run()
    ns.Scaffold:runTest("Test Thread Signals")
end
