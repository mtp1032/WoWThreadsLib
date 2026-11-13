--=================================================================================
-- Filename: SleepAwake.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.SleepAwake   = ns.SleepAwake or {}
local SleepAwake    = ns.SleepAwake
local core              = ns.Core
local utils             = ns.UtilsLib
local post              = ns.PostMessages
local L                 = ns.Locales.L


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

local sleeper_h     = nil
local wakeup_h      = nil

-- create the thread sleep()
local function sleeping()
    local DONE = false
    

    local threadId = thread:getId()
    utils:dbgPrint("Thread Id", threadId, "is now sleeping.")

    local success, errorMsg = thread:sleep()
    assert( success, errorMsg )

    -- the sleeping thread is here because it was
    -- awakend.
    utils:dbgPrint("Sleeper", threadId, "has awakened")
    while not DONE do
        utils:dbgPrint()
        thread:yield()
        utils:dbgPrint()
        local signal, sender_h = thread:getSignal()
        utils:dbgPrint()
        if signal == SIG_TERMINATE then
        utils:dbgPrint()
            post:message(string.format("The sleeper received SIG_TERMINATE.\n"))
        utils:dbgPrint()
            return 
        end
        utils:dbgPrint()
    end
    utils:dbgPrint()
end

local function wakeupSleeper()
    local DONE = false
    local threadId = thread:getId()
    utils:dbgPrint( "Wakeup Id", threadId )

    while not DONE do
        utils:dbgPrint( "Calling thread:wakeup()")
        local success, errorMsg = thread:wakeup( sleeper_h )
        utils:dbgPrint( tostring(success), tostring(errorMsg) )
        assert( success, errorMsg )
        utils:dbgPrint()
        thread:yield()
        DONE = true 
    end
    utils:dbgPrint("Thread Id", threadId, "called thread:wakeup().")

    DONE = false
    while not DONE do
        utils:dbgPrint()
        local wasSent, errorMsg = thread:sendSignal( sleeper_h, SIG_TERMINATE )
        utils:dbgPrint( tostring( wasSent))
        assert( wasSent, errorMsg )
        utils:dbgPrint("Thread Id", threadId, "issued SIG_TERMINATE.")

        thread:yield()
        DONE = true
    end
end

-- creates the two tests that will execute tests of sending and receiving signals with and without payloads
local function startTest()
    local errorMsg = nil

    thread:enableDebugging()

    sleeper_h, errorMsg = thread:create(30, sleeping )
    assert( sleeper_h, errorMsg )

    wakeup_h, errorMsg = thread:create(50, wakeupSleeper )
    assert( wakeup_h, errorMsg )
end

function SleepAwake:start()
    startTest()
end
startTest()