--=================================================================================
-- WoWThreads Test Scaffold
--=================================================================================

local ADDON_NAME, ns = ...

ns.Scaffold = ns.Scaffold or {}
local Scaffold = ns.Scaffold
local global = ns.Globals
local L = ns.Locales

local _, localizedVersion = global:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error("WoWThreads library not found.")
end

-- Internal storage for registered tests
local tests = {}
Scaffold.tests = tests

local results = {
    passed = 0,
    failed = 0,
    groups = {}
}

--=================================================================================
-- Register a test
--=================================================================================
function Scaffold:registerTest(name, fn)
    tests[#tests + 1] = { name = name, fn = fn }
end

--=================================================================================
-- Optional grouping (cosmetic)
--=================================================================================
function Scaffold:beginGroup(name)
    print(" ")
    print("=== BEGIN TEST GROUP:", name, "===")
    print(" ")
    results.groups[#results.groups + 1] = { name = name }
end

function Scaffold:endGroup(name)
    print(" ")
    print("=== END TEST GROUP:", name, "===")
    print(" ")
end

--=================================================================================
-- PASS / FAIL reporting
--=================================================================================
function Scaffold:reportPass(name)
    results.passed = results.passed + 1
    print("|cff00ff00PASS|r", name)
end

function Scaffold:reportFail(name, msg)
    results.failed = results.failed + 1
    print("|cffff0000FAIL|r", name, msg)
end

--=================================================================================
-- Run all registered tests (synchronous mode)
--=================================================================================
function Scaffold:runAllTests()
    print(" ")
    print("======================================")
    print("      WoWThreads Automated Tests       ")
    print("======================================")
    print(" ")

    for _, t in ipairs(tests) do
        local passed, msg = pcall(t.fn)
        if passed then
            Scaffold:reportPass(t.name)
        else
            Scaffold:reportFail(t.name, msg)
        end
    end

    Scaffold:printSummary()
end

--=================================================================================
-- Summary
--=================================================================================
function Scaffold:printSummary()
    print(" ")
    print("======================================")
    print("            TEST SUMMARY              ")
    print("======================================")
    print("Passed:", results.passed)
    print("Failed:", results.failed)
    print("Total:", results.passed + results.failed)
    print("======================================")
    print(" ")
end

--=================================================================================
-- Event handling
--=================================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

local function OnEvent(self, event, ...)
    local addonName = select(1, ...)
    if event == "ADDON_LOADED" and addonName == "WoWThreadsLib" then
        eventFrame:UnregisterEvent("ADDON_LOADED")
        thread:libInit()
        DEFAULT_CHAT_FRAME:AddMessage(L["ADDON_LOADED_MSG"], 0.0, 1.0, 0)
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
