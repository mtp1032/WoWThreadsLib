--=================================================================================
-- Filename: SuiteEvents.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.SuiteEvents    = ns.SuiteEvents or {}

-- if not ns.CollectResults.loaded then
--     print( "CollectResults.lua not loaded!")
--     return
-- end

local events  = ns.SuiteEvents
local collect = ns.CollectResults
local core  = ns.Core
local utils = ns.UtilsLib
local post  = ns.PostMessages
local L     = ns.Locales.L

local _, localizedVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error( L["THREAD_LIB_NOT_FOUND"] )
end
 
local SIG_READY           = thread.SIG_READY
local SIG_START           = thread.SIG_START
local SIG_STOP            = thread.SIG_STOP
local SIG_TASK_COMPLETE   = thread.SIG_TASK_COMPLETE
local SIG_ALERT           = thread.SIG_ALERT
local SIG_CONDITION_MET   = thread.SIG_CONDITION_MET
local SIG_TERMINATE       = thread.SIG_TERMINATE
local SIG_NONE_PENDING    = thread.SIG_NONE_PENDING

local main_h = nil
local sleeper_h = nil

local function sleeper(... )
    local DONE = false
    local sleeping = false

    local _, sleeperId = thread:getSelf()

    while not DONE do
        local asleep = false
        sleeping, errorMsg = thread:sleep()
        assert( sleeping == false, "Failed assertion. sleeper_h should be awake.")
        DONE = true

        if not sleeping then 

            -- if we're here it's because main_h
            -- issued a thread:wakeup( sleeper_h) call.
            post:message( string.format("%s has awoken.\n", "sleeper_h" ))
            local wasSent, errorMsg = thread:sendSignal( main_h, SIG_TERMINATE )
            assert( wasSemt, errorMsg )
        end
    end
end
local function main (...)
    local DONE = false
    local errorMsg = nil
    local sleeping = nil

    sleeper_h, errorMsg = thread:create( 30, sleeper )
    assert( sleeper_h, errorMsg )
    thread:yield() -- give the sleeper some time to get a nice snooze

    while not DONE do
        sleeping, errorMsg = thread:isSleeping( sleeper_h )
        assert( sleeping, errorMsg )

        -- wait 2 seconds then wake the thread.
        if sleeping then
            local start = debugprofilestop()
            thread:delay( 180 )
            local elapsed = debugprofilestop() - start
            local sleeping, errorMsg = thread:wakeup( sleeper_h )
            assert( sleeping, errorMsg)
        end
            
        if signal == SIG_TERMINATE then 
            return 
        end
    end
end

local function startSuiteEvents()

    main_h, errorMsg = thread:create( 30, main )
    assert( main_h, errorMsg )

end

startSuiteEvents()