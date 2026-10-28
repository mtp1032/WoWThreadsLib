--=================================================================================
-- Filename: Commands.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.Commands = ns.Commands or {}
local params = ns.ParamFailures
local core  = ns.Core
local post  = ns.PostMessages
local sig   = ns.SignalQueue
local utils = ns.UtilsLib
local L     = ns.Locales

-- Import WoWThreadsLib
local gitVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", gitVersion)
if not thread then
    error(L["THREAD_LIB_NOT_FOUND"])
end

---------------------------------------------------------------------
-- Command dispatch table
-- Add new test commands here as you build more test modules.
---------------------------------------------------------------------
local dispatch = {
    ["main"] = function()
        -- Example: run the ParamFailures test module
        -- This assumes ns.ParamFailures.main exists and starts a test thread.
        if ns.ParamFailures and ns.ParamFailures.main then
            ns.ParamFailures.main()
        else
            post:message("ParamFailures.main() not found")
        end
    end,

    ["ping"] = function()
        post:message("WoWThreadsLib test command interface is alive.")
    end,

    ["help"] = function()
        post:message("WoWThreadsLib Test Commands:")
        post:message("  /wuts main   - run main ParamFailures tests")
        post:message("  /wuts ping   - simple connectivity test")
        post:message("  /wuts help   - show this help")
    end,
}

---------------------------------------------------------------------
-- Command handler
---------------------------------------------------------------------
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
        post:message("Unknown test command: " .. msg)
        dispatch["help"]()
    end
end

---------------------------------------------------------------------
-- Register Slash Commands
---------------------------------------------------------------------
SLASH_TEST_WOWTHREADS_LIB1 = "/wuts"
SLASH_TEST_WOWTHREADS_LIB2 = "/wowunittests"
SlashCmdList["WOWTHREADS_LIB"] = getCommand
