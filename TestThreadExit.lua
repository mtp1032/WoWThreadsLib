--=================================================================================
-- Filename: TestThreadExit.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.TestThreadExit    = ns.TestThreadExit or {}
local core          = ns.Core
local utils         = ns.UtilsLib
local L             = ns.Locales.L

local _, localizedVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error( L["THREAD_LIB_NOT_FOUND"] )
end
 
local SIG_START         = thread.SIG_START
local SIG_COMPLETE      = thread.SIG_COMPLETE
local SIG_TERMINATE     = thread.SIG_TERMINATE
 
-- namespace shorcuts
local thexit    = ns.TestThreadExit
local utils     = ns.UtilsLib
local collect   = ns.CollectResults
local post      = ns.PostMessages
local L         = ns.Locales

-- local thread handles
local collector_h = collect:getCollectorHandle() -- to be wired in later
    local str = string.format("%s collector_h %d", utils:dbgPrefix(), #collector_h)
    DEFAULT_CHAT_FRAME:AddMessage( str, 0,1,1)

local dummy_h = nil
-- Unit Tests
local function threadExitOne()
    local DONE = false
    local sigEntry = nil
    local errorMsg = nil
    local signal = nil

    while not DONE do
        thread:yield()

        sigEntry, errorMsg = thread:getSignal()
        assert( sigEntry, errorMessage )
        local signal = signalHelper( sigEntry )

        if signal == SIG_TERMINATE then
            local wasSent, errorMsg = thread:sendSignal( wrapper_h, SIG_COMPLETE )
            assert( wasSent, errorMsg )

            thread:exit( "Hello World")
            utils:dbgPrint( "Should not be here.")
        end
    end
end

local function testWrapper()
    local DONE = false
    local wasSent = nil
    local errorMsg = nil
    local sigEntry = nil

    local dummy_h, errorMsg = thread:create(50, threadExitOne )
    assert( dummy_h, errorMsg )

    thread:yield()

    wasSent, errorMsg = thread:sendSignal( dummy_h, SIG_START )
    assert( wasSent, errorMsg )

    while not DONE do
        sigEntry, errorMsg = thread:getSignal()
        assert( sigEntry, errorMsg)

        signal = signalHelper( sigEntry )

        if signal == SIG_COMPLETE then
            local data, errorMsg = thread:getExitData( dummy_h )
            utils:dbgPrint( data )
            DONE = true
        end
    end
end
local function main()
    wrapper_h, errorMsg = thread:create(50, testWrapper)
    local str = string.format("%s wrapper_h %d", utils:dbgPrefix(), #wrapper_h)
    DEFAULT_CHAT_FRAME:AddMessage( str, 0,1,1)

    assert( wrapper_h, errorMsg )

    local wasSent, errorMsg = thread:sendSignal(wrapper_h, SIG_START)
    local str = string.format("%s %d", utils:dbgPrefix(), #wrapper_h)
    DEFAULT_CHAT_FRAME:AddMessage( str, 0,1,1)

    assert(wasSent, errorMsg)
end
main()

