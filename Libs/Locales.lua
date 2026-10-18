--=================================================================================
-- Filename: Locales.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.Locales = ns.Locales or {}
ns.Globals = ns.Globals or {}
local global = ns.Globals

-- =====================================================================
--                      LOCALIZATION
-- =====================================================================
local L = setmetatable({}, { __index = function(t, k) 
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })
ns.Locales.L = L
local L = ns.Locales

local gitVersion, expansionName = global:getAddonInfo()
local LOCALE = GetLocale()
if LOCALE == "enUS" then
    L["VERSION"]          = gitVersion
    L["EXPANSION_NAME"]   = expansionName
    L["ADDON_LOADED_MSG"] = string.format( "%s v%s, %s.", ADDON_NAME, L["VERSION"],L["EXPANSION_NAME"] )
	--                          Thread-specific messages
	L["INVALID_TYPE"]				= "Uknown or unexpected data type "
    L["PARAMETER_NIL"]  			= "Function Parameter nil "
	L["INVALID_OPERATION"]			= "Operation not permitted "
	L["THREAD_HANDLE_NIL"] 		    = "Thread handle nil "
	L["THREAD_NO_COROUTINE"]        = "Ill-formed thread handle. Does not reference a coroutine "
    L["THREAD_INVALID_CONTEXT"]     = "Function failed because caller is the WoW client (WoW.exe) "
	L["THREAD_HANDLE_ILL_FORMED"]	= "Ill-formed thread handle. Check table size. "
    L["THREAD_NOT_COMPLETED"]       = "Thread has not yet completed. "

	L["THREAD_COROUTINE_DEAD"]      = "Invalid handle. Thread has completed or failed. "
    L["THREAD_NOT_FOUND"]           = "Thread not found. "

    -- Signal failure
	L["SIGNAL_OUT_OF_RANGE"]	    = "Signal is out of range "
    L["SIGNAL_IS_NIL"]	            = "Signal is nil "
    L["SIGNAL_INVALID_TYPE"]        = "Signal type is invalid. Should be 'number' "
    L["SIGNAL_INVALID_OPERATION"]   = "SIG_NONE_PENDING can not be sent "
end
