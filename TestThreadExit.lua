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
local SIG_TERMINATE     = thread.SIG_TERMINATE
local SIG_NONE_PENDING  = thread.SIG_NONE_PENDING
 
-- namespace shorcuts
local thexit    = ns.TestThreadExit
local utils     = ns.UtilsLib
local collect   = ns.CollectResults
local post      = ns.PostMessages
local L         = ns.Locales

local testOne_h = nil
local testWrapper_h = nil
-- Unit Tests
local function threadExitOne()
    local DONE = false
    local sigEntry = nil
    local errorMsg = nil
    local signal = nil

    local threadId, errorMsg = thread:getId()
    assert(threadId, errorMsg )

    while not DONE do
        thread:yield()
        sigEntry, errorMsg = thread:getSignal()
        assert( sigEntry, errorMessage )
        local signal = utils:signalHelper( sigEntry )

        if signal == SIG_TERMINATE then
            thread:exit( "Hello World", "Goodbye", "good riddance")
            assert( false, "SHOULD NOT BE HERE!")
        end
    end
end

local function testWrapper()
    local DONE = false
    local wasSent = nil
    local errorMsg = nil
    local sigEntry = nil


    while not DONE do
        wasSent, errorMsg = thread:sendSignal( testOne_h, SIG_TERMINATE )
        assert( wasSent, errorMsg )
        thread:yield()
        
        -- get the data from the terminated testOne_h
        local exitData = {thread:getExitData( testOne_h )}
        assert( exitData, "thread:getExitData() failed")
        post:message( string.format("thread:getExitData() - %s, %s, %s\n", exitData[1], exitData[2], exitData[3]))
    end
end
local function main()
    testWrapper_h, errorMsg = thread:create(50, testWrapper)
    assert( testWrapper_h, errorMsg )

    testOne_h, errorMsg = thread:create(30, threadExitOne )
    assert( testOne_h, errorMsg )

end
main()