--=================================================================================
-- Filename: Commands.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.Commands = ns.Commands or {}
local core  = ns.Core
local post  = ns.PostMessages
local sig   = ns.SignalQueue
local utils = ns.UtilsLib
local L     = ns.Locales 

-- Import WoWThreadsLib
local gitVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", gitVersion)
if not thread then
    error( L["THREAD_LIB_NOT_FOUND"] )
end

-- tests to be run below here
-- 
---------------------------------------------------------
-- Slash Command Handler
---------------------------------------------------------
local controller_h = nil
local function getCommand(msg)
    
    msg = msg:lower():trim()
    
    if msg == "" then
        dispatch["help"]()
        return
    end

    local fn = dispatch[msg]
    if fn then
        fn()
    else
        post:message("Unknown command: " .. msg)
        dispatch["help"]()
    end
end

---------------------------------------------------------
-- Register Slash Commands
---------------------------------------------------------
SLASH_TEST_WOWTHREADS_LIB1 = "/wlt"
SLASH_TEST_WOWTHREADS_LIB2 = "/wowlibtest"

SlashCmdList["WOWTHREADS_LIB"] = getCommand
