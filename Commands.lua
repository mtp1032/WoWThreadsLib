--=================================================================================
-- Filename: Commands.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
ns.Commands = ns.Commands or {}

-- local core = ns.Core
local post  = ns.PostMessages
local TestSignals = ns.TestSignalOne
-- local utils = ns.UtilsLib
-- local L     = ns.Locales.L

local Commands = {}

local TEST_SUITES =
{
    ParamFailures   = ParamFailures,
    -- SignalPayloads = SignalPayloads,
    -- ThreadSemantics = ThreadTerminations,
}

local function printHelp()

    post:message( string.format("/wowtest <suite>\n"))
    post:message( string.format("/wowtest all\n"))
    post:message( string.format("\n"))
    post:message( string.format("Available suites:\n"))

    for suiteName in pairs(TEST_SUITES) do
        post:message( string.format("  %s\n", suiteName))
    end
end

function Commands:run(msg)

    local suiteName = strtrim(msg or "")

    if suiteName == "" then
        printHelp()
        return
    end

    if suiteName == "all" then

        for _, suite in pairs(TEST_SUITES) do
            suite:startTests()
        end

        return
    end

    local suite = TEST_SUITES[suiteName]

    if not suite then
        post:message(string.format(
            "Unknown test suite '%s'\n",
            suiteName
        ))
        printHelp()
        return
    end

    suite:startTests()
end

SLASH_WOWTHREADTEST1 = "/wowtest"

SlashCmdList["WOWTHREADTEST"] =
    function(msg)
        Commands:run(msg)
    end

return Commands