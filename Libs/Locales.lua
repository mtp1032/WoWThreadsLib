--=================================================================================
-- Filename: Locales.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.Locales = ns.Locales or {}
ns.Core = ns.Core or {}
local core = ns.Core

-- =====================================================================
--                      LOCALIZATION
-- =====================================================================
local L = setmetatable({}, { __index = function(t, k) 
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })
ns.Locales.L = L
local L = ns.Locales.L

local _, localizedVersion, expansionName = core:getLibInfo()
local LOCALE = GetLocale()
if LOCALE == "enUS" then
    L["VERSION"]          = localizedVersion
    L["EXPANSION_NAME"]   = expansionName
    L["ADDON_LOADED_MSG"] = string.format( "%s v%s, (%s)", ADDON_NAME, L["VERSION"],L["EXPANSION_NAME"] )
	
    -- Thread Errors                          Thread-specific messages
	L["INVALID_TYPE"]				= "Uknown or unexpected data type. "
    L["PARAMETER_NIL"]  		    = "Function Parameter nil. "
	L["INVALID_OPERATION"]			= "Operation not permitted. "
    L["NOT_A_THREAD"]               = "Caller is not a thread. "
	L["THREAD_HANDLE_NIL"] 		    = "Thread handle was nil. "
	L["THREAD_COROUTINE_NIL"]       = "Thread's coroutine is nil. "
	L["THREAD_HANDLE_MALFORMED"]	                = "Malformed thread handle."
    L["THREAD_NOT_COMPLETED"]       = "Thread has not yet completed. "
    L["THREAD_NOT_FOUND"]           = "Thread handle not found. "
    L["THREAD_LIB_NOT_FOUND"]       = "WoW Threads Library not found. "
    L["THREAD_IS_DEAD"]             = "It's dead, Jim. "
    L["THREAD_IS_SLEEPING"]         = "Thread is sleeping and cannont be signaled. "
    L["SLEEP_TABLE_EMPTY"]          = "Sleep table is empty. "

    -- Signal failures
	L["SIGNAL_OUT_OF_RANGE"]	    = "Signal is out of range. "
    L["SIGNAL_UKNOWN"]              = "Signal does not match WoWThread's signals."
    L["SIGNAL_IS_NIL"]	            = "Signal is nil. "
    L["SIGNAL_INVALID_TYPE"]        = "Signal type is invalid. "
    L["SIG_NONE_PENDING"]           = "SIG_NONE_PENDING can not be used. "
end
