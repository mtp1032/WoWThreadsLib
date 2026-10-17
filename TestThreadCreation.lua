--=================================================================================
-- Filename: TestThreadCreation.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
TestCreate = TestCreate or {}

local thread = LibStub("WoWThreadsLib", "0.1.0")
if not thread then
    error("WoWThreads library not found.")
end

local SIG_HAS_PAYLOAD  = thread.SIG_HAS_PAYLOAD
local SIG_SEND_PAYLOAD = thread.SEND_DATA
local SIG_BEGIN        = thread.SIG_BEGIN
local SIG_HALT         = thread.SIG_HALT
local SIG_IS_COMPLETE  = thread.SIG_IS_COMPLETE
local SIG_SUCCESS      = thread.SIG_SUCCESS
local SIG_FAILURE      = thread.SIG_FAILURE
local SIG_IS_READY     = thread.SIG_IS_READY
local SIG_CALLBACK     = thread.SIG_CALLBACK
local SIG_THREAD_DEAD  = thread.SIG_THREAD_DEAD
local SIG_ALERT        = thread.SIG_ALERT
local SIG_WAKEUP       = thread.SIG_WAKEUP
local SIG_TERMINATE    = thread.SIG_TERMINATE
local SIG_NONE_PENDING = thread.SIG_NONE_PENDING
