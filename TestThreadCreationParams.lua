--=================================================================================
-- Filename: TestThreadCreation.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
ns.TestThreadCreation = ns.TestThreadCreation or {}
ns.Scaffold = ns.Scaffold or {}

local Scaffold  = ns.Scaffold
local test      = ns.TestThreadCreation
local core    = ns.Core
local post      = ns.PostMessages
local utils     = ns.UtilsLib

local L = ns.Locales

local _, localizedVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error( L["THREAD_LIB_NOT_FOUND"] )
end

-- Of the 14 signals, we're only using SIG_TERMINATE
local SIG_TERMINATE    = thread.SIG_TERMINATE

local function signalHelper( sigEntry )
    return sigEntry[1], sigEntry[2], sigEntry[3]
end
local function dummy()
    -- do nothing because in this module the dummy thread
    -- is never created. 
end
local function wrapTestThreadParams()
    local ticks = 30

    --===================
    -- Test For Invalid types
    --===================
    local test_h, errorMsg = thread:create("ticks", dummy)
    if test_h ~= nil then
        error(string.format("%s FAIL", uils:dbgPrefix() ))
    end

    thread:yield()

    local msg = string.format("%s PASS:\n   Error Message is correct. | %s\n", utils:dbgPrefix(), errorMsg )
    post:message( msg )

    thread:yield()

    local test_h, errorMsg = thread:create(ticks, "dummy")
    if test_h ~= nil then
        error(string.format("%s FAIL", uils:dbgPrefix() ))
    end
    local msg = string.format("%s PASS:\n   Error Message is correct. | %s\n", utils:dbgPrefix(), errorMsg )
    post:message( msg )

    post:message( string.format("Thread wrapTestThreadParams() completed."))
end

function ns.TestThreadCreation.run()
    ns.Scaffold:runTest("Test Thread Creation Params")
end

utils:dbgPrint( "Registering Test Thread Creation Params")
ns.Scaffold:registerTest("Test Thread Creation Params", wrapTestThreadParams)
