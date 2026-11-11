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

local main_h = nil
local sender_h = nil
local receiver_h = nil
-- Unit Tests

-- send a 
local function sender()
    local DONE = false
    while not DONE do
        thread:yield()
        local signal, sender_h, errorMsg, sigData = thread:getSignal()
        assert( signal, errorMsg )

        if signal == SIG_TERMINATE then
            thread:exit("Goodbye from sender")
        end
    end
end
-- Receives the SIG_TERMINATE signal from sender and then sends a SIG_COMPLETE signal to main_h.
local function receiver()
    local DONE = false
    while not DONE do
        thread:yield()
        local signal, sender_h,errorMsg, sigData = thread:getSignal()
        assert( signal, errorMsg )

        if signal == SIG_TERMINATE then
            local wasSent, errorMsg = thread:sendSignal(main_h, SIG_COMPLETE, sender_h)
            assert( wasSent, errorMsg )
            thread:exit("Goodbye from receiver")
        end
        DONE = true

    end

end

-- creates the two tests that will execute the sender function and then terminate it
local function main()
    local DONE = false

    sender_h, errorMsg = thread:create(50, sender )
    assert( testExitOne_h, errorMsg )

    receiver_h, errorMsg = thread:create(50, receiver )
    assert( receiver_h, errorMsg )

    while not DONE do
        thread:yield()
        signal, errorMsg, sigData = thread:getSignal()
        assert( signal, errorMessage )

        if signal == SIG_TERMINATE then
            DONE = true
        end
    end
end
local function startTest()
    local errorMsg = nil

    main_h, errorMsg = thread:create(50, main )
    assert( main_h, errorMsg )

end

startTest()