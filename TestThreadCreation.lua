--=================================================================================
-- Filename: TestThreadCreation.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
ns.TestCreation = ns.TestCreation or {}
ns.Scaffold = ns.Scaffold or {}

local Scaffold  = ns.Scaffold
local test      = ns.TestCreation
local global    = ns.Globals
local post      = ns.PostMessages
local utils     = ns.UtilsLib

local L = ns.Locales

local _, localizedVersion = global:getLibInfo()
print( localizedVersion)
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error("WoWThreads library not found.")
end

local SIG_HAS_PAYLOAD  = thread.SIG_HAS_PAYLOAD
local SIG_SEND_PAYLOAD = thread.SEND_DATA
local SIG_BEGIN        = thread.SIG_BEGIN
local SIG_HALT         = thread.SIG_HALT
local SIG_COMPLETED    = thread.SIG_COMPLETED
local SIG_SUCCESS      = thread.SIG_SUCCESS
local SIG_FAILURE      = thread.SIG_FAILURE
local SIG_IS_READY     = thread.SIG_IS_READY
local SIG_CALLBACK     = thread.SIG_CALLBACK
local SIG_THREAD_DEAD  = thread.SIG_THREAD_DEAD
local SIG_ALERT        = thread.SIG_ALERT
local SIG_WAKEUP       = thread.SIG_WAKEUP
local SIG_TERMINATE    = thread.SIG_TERMINATE
local SIG_NONE_PENDING = thread.SIG_NONE_PENDING

local main_h = nil

local function signalHelper( sigEntry )
    return sigEntry[1], sigEntry[2], sigEntry[3]
end
local function dummy()
    -- do nothing
end
local function test_ThreadCreationParameters()
    -- wrong type test
    local ticks = "45" -- should be a number
    local test_h, errorMsg = thread:create(ticks, dummy)

    if test_h ~= nil then
        error("FAIL: thread:create(): Expect a nil handle when ticks is an invalid parameter.")
    end
    post:message( string.format("%s PASS: Expected and received a nil handle.", utils:dbgPrefix()))


    -- terminate the main wrapper
    local wasSent, err = thread:sendSignal(main_h, SIG_TERMINATE)
    if not wasSent then error(err) end
end
ns.Scaffold:registerTest("test invalid parameters", test_ThreadCreationParameters)
