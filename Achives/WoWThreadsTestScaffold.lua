--=================================================================================
-- Filename: WoWThreadsTestScaffold.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================

local ADDON_NAME, ns = ...

ns.Scaffold     = ns.Scaffold or {}
local Scaffold  = ns.Scaffold
local core    = ns.Core
local post      = ns.PostMessages
local utils     = ns.UtilsLib
local L =       ns.Locales

local _, localizedVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error( L["THREAD_LIB_NOT_FOUND"] )
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
-- Run a single test by name
--=================================================================================
function Scaffold:runTest(name)
    -- Find the test entry
    local entry = nil
    for _, t in ipairs(tests) do
        if t.name == name then
            entry = t
            break
        end
    end

    if not entry then
        error("Test '" .. tostring(name) .. "' not found.")
    end

    -- Run the test
    local ok, msg = pcall(entry.fn)
    if ok then
        Scaffold:reportPass(entry.name)
    else
        Scaffold:reportFail(entry.name, msg)
    end

    -- Print summary after running a single test
    Scaffold:printSummary()
end

--=================================================================================
-- Optional grouping (cosmetic)
--=================================================================================
function Scaffold:beginGroup(name)
    post:message("\n")
    post:message(string.format("=== BEGIN TEST GROUP: %s\n", name ))
    post:message("\n")
    results.groups[#results.groups + 1] = { name = name }
end

function Scaffold:endGroup(name)
    post:message("\n")
    post:message(string.format("=== END TEST GROUP: %s\n" ))
    post:message("\n")
end

--=================================================================================
-- PASS / FAIL reporting
--=================================================================================
function Scaffold:reportPass(name)
    results.passed = results.passed + 1
    post:message(string.format("%s\n", name))
end

function Scaffold:reportFail(name, msg)
    results.failed = results.failed + 1
    post:message(string.format("%s %s\n", name, msg))
end

--=================================================================================
-- Run all registered tests (synchronous mode)
--=================================================================================
function Scaffold:runAllTests()
    post:message("\n")
    post:message(string.format("======================================\n"))
    post:message(string.format("      WoWThreads Automated Tests      \n"))
    post:message(string.format("======================================\n"))
    post:message("\n")

    for _, t in ipairs(tests) do
        local ok, msg = pcall(t.fn)
        if ok then
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
    post:message("\n")
    post:message(string.format("======================================\n"))
    post:message(string.format("            TEST SUMMARY              \n"))
    post:message(string.format("======================================\n"))
    post:message(string.format("Passed %d\n", results.passed))
    post:message(string.format("Failed %d\n", results.failed))
    post:message(string.format("Total: Passed %d, Failed %d\n", results.passed + results.failed))
    post:message(string.format("======================================\n"))
    post:message("\n")
end
