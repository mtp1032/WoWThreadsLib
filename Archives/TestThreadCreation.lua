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
local global    = ns.Core
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

local main_h = nil

local function signalHelper( sigEntry )
    return sigEntry[1], sigEntry[2], sigEntry[3]
end
local function dummy()
    -- do nothing
end
local function wrapTestThreadParams()
    local ticks = 30

    --==============
    -- Invalid types
    --==============
    local test_h, errorMsg = thread:create("ticks", dummy)
    if test_h ~= nil then
        error(string.format("%s FAIL", uils:dbgPrefix() ))
    end
    local msg = string.format("%s PASS:\n   Error Message is correct. | %s\n", utils:dbgPrefix(), errorMsg )
    post:message( msg )

    local test_h, errorMsg = thread:create(ticks, "dummy")
    if test_h ~= nil then
        error(string.format("%s FAIL", uils:dbgPrefix() ))
    end
    local msg = string.format("%s PASS:\n   Error Message is correct. | %s\n", utils:dbgPrefix(), errorMsg )
    post:message( msg )

    -- terminate the main wrapper
    local wasSent, errorMsg = thread:sendSignal(main_h, SIG_TERMINATE)
    if not wasSent then error(errorMsg) end
    return
end

print( "Registering Test Thread Creation Params")
ns.Scaffold:registerTest("Test Thread Creation Params", wrapTestThreadParams)
function ns.TestThreadCreation.run()
    ns.Scaffold:runTest("Test Thread Creation Params")
end
