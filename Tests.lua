--=================================================================================
-- Filename: Tests.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

-- Unified test registry
ns.Tests = ns.Tests or {}
local utils = ns.UtilsLib

-- Register test modules if they exist
-- (This allows you to add modules gradually without breaking Commands.lua)

if ns.TestThreadCreation then
    ns.Tests.creation = ns.TestThreadCreation
end

if ns.TestThreadSignals then
    ns.Tests.signals = ns.TestThreadSignals
end

if ns.Scaffold then
    ns.Tests.scaffold = ns.Scaffold
end

if ns.TestBroadcast then
    ns.Tests.broadcast = ns.TestBroadcast
end

if ns.TestLifecycle then
    ns.Tests.lifecycle = ns.TestLifecycle
end

-- Optional: a convenience function to list available tests
ns.Tests.list = function()
    post:message(string.format("Available WoWThreadsLib tests:\n"))
    for name, mod in pairs(ns.Tests) do
        if type(mod) == "table" then
            post:message(string.format("  - " .. name))
        end
    end
end
