--=================================================================================
-- Filename: TestSignalsOne.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.TestSignalsOne   = ns.TestSignalsOne or {}
local core          = ns.Core
local utils         = ns.UtilsLib
local L             = ns.Locales.L

local _, localizedVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error( L["THREAD_LIB_NOT_FOUND"] )
end
 
local SIG_READY             = thread.SIG_READY
local SIG_START             = thread.SIG_START
local SIG_COMPLETE          = thread.SIG_COMPLETE
local SIG_ALERT             = thread.SIG_ALERT
local SIG_CONDITION_MET     = thread.SIG_CONDITION_MET
local SIG_CREATE_THREAD     = thread.SIG_CREATE_THREAD
local SIG_TERMINATE         = thread.SIG_TERMINATE
 
-- namespace shorcuts
local post      = ns.PostMessages
local L         = ns.Locales

local main_h = nil
local receiver_h = nil
-- Unit Tests

-- send a 
local function receiver()
    local DONE = false
    -- utils:dbgPrint()

    while not DONE do
        thread:yield() 
        local signal, sender_h, signalName, greeting = thread:getSignal()
        if signal == SIG_START then
   
            -- post:message( string.format("SIG_START Payload: %s, %s\n", signalName, greeting))
            -- utils:dbgPrint( #main_h )
            local wasSent, errorMsg = thread:sendSignal( main_h, SIG_TERMINATE )
            if not wasSent then
                utils:dbgPrint( errorMsg )
                return
            end
            utils:dbgPrint("receiver: normal completion")
            DONE = true
        end
    end
end

local function main() 
    local DONE = false
    while not DONE do
        thread:yield()
        local wasSent, errorMsg = thread:sendSignal( receiver_h, SIG_START, "SIG_START", "Hello World" )
        if not wasSent then
            utils:dbgPrint( errorMsg )
            return
        end

        local signal, errorMsg = thread:getSignal()
        if signal == SIG_TERMINATE then
            utils:dbgPrint("main: normal completion")
            DONE = true
        end
    end
    -- post:message( string.format("main_h complete.\n"))
end


thread:enableDebugging()
main_h, errorMsg = thread:create( 60, main )
-- utils:dbgPrint( #main_h )
assert( main_h, errorMsg )
-- post:message( string.format("%s Created main() thread\n", utils:dbgPrefix() ))

receiver_h, errorMsg = thread:create(20, receiver )
-- utils:dbgPrint( #receiver_h )
assert( receiver_h, errorMsg )
-- post:message( string.format("%s Created receiver thread\n", utils:dbgPrefix() ))
