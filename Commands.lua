--=================================================================================
-- Filename: Commands.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.Commands     = ns.Commands or {}
local testHarness = ns.WoWThreadsTestHarness
local testSignals   = ns.TestThreadSignals
local global    = ns.Core
local post      = ns.PostMessages
local sig       = ns.SignalQueue
local utils     = ns.UtilsLib
local L         = ns.Locales 

-- Import WoWThreadsLib
local gitVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", gitVersion)
if not thread then
    error( L["THREAD_LIB_NOT_FOUND"] )
end

---------------------------------------------------------
-- Command Dispatch Table
---------------------------------------------------------
local dispatch = {
    ["test1"] = function()
        post:message("Running test1...\n")
        if ns.Tests.creation and ns.Tests.creation.run then
            ns.Tests.creation.run()
        else
            post:message("Test 'creation' is not available.\n")
        end
    end,
    ["signals"] = function()
        testSignals:testThreadCreateDummy()
        post:message("Running Test Thread Signals...\n")
        if ns.Tests.signals and ns.Tests.signals.run then
            ns.Tests.signals.run()
        else
            post:message("Test Thread Signals not available.\n")
        end
    end,

    ["broadcast"] = function()
        post:message("Running broadcast storm test...\n")
        if ns.Tests.broadcast and ns.Tests.broadcast.run then
            ns.Tests.broadcast.run()
        else
            post:message("Test 'broadcast' is not available.\n")
        end
    end,

    ["lifecycle"] = function()
        post:message("Running lifecycle test...\n")
        if ns.Tests.lifecycle and ns.Tests.lifecycle.run then
            ns.Tests.lifecycle.run()
        else
            post:message("Test 'lifecycle' is not available.\n")
        end
    end,

    ["help"] = function()
        post:message("WoWThreadsLib Commands:\n")
        post:message("  /wt test1       - Run creation test\n")
        post:message("  /wt signals     - Run signals test\n")

        post:message("  /wt broadcast   - Run broadcast storm test\n")
        post:message("  /wt lifecycle   - Run lifecycle test\n")
        post:message("  /wt help        - Show this help\n")
    end,
}

---------------------------------------------------------
-- Slash Command Handler
---------------------------------------------------------
local master_h = nil
local function handleCommand(msg)
    -- local errorMsg = nil
    -- utils:dbgPrefix()

    -- local threadLibStarted = thread:libInit()
    -- while not threadLibStarted do
    --     threadLibStarted = thread:libInit()
    -- end
    -- post:message( string.format("\n*** Lib Is Initialized? %s ***\n\n ", tostring( threadLibStarted )))
    -- master_h, errorMsg = testHarness:createMasterThread()
    -- if master_h == nil then
    --     post:message( "ERROR: Failed to create thread.")
    --     error( "ERROR: Failed to create thread." )
    -- end
    
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
SLASH_WOWTHREADS1 = "/wt"
SLASH_WOWTHREADS2 = "/wthreads"

SlashCmdList["WOWTHREADS"] = handleCommand
