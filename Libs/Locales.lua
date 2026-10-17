--=================================================================================
-- Filename: Locales.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.Locales = ns.Locales or {}
local Locales = ns.Locales

local EXPANSION_NAMES = {}
local function addExpansionName(expansionLevel, name)
    if expansionLevel ~= nil then
        EXPANSION_NAMES[expansionLevel] = name
    end
end

addExpansionName(LE_EXPANSION_CLASSIC, "Classic")
addExpansionName(LE_EXPANSION_BURNING_CRUSADE, "Burning Crusade")
addExpansionName(LE_EXPANSION_WRATH_OF_THE_LICH_KING, "Wrath of the Lich King")
addExpansionName(LE_EXPANSION_CATACLYSM, "Cataclysm")
addExpansionName(LE_EXPANSION_MISTS_OF_PANDARIA, "Mists of Pandaria")
addExpansionName(LE_EXPANSION_WARLORDS_OF_DRAENOR, "Warlords of Draenor")
addExpansionName(LE_EXPANSION_LEGION, "Legion")
addExpansionName(LE_EXPANSION_BATTLE_FOR_AZEROTH, "Battle for Azeroth")
addExpansionName(LE_EXPANSION_SHADOWLANDS, "Shadowlands")
addExpansionName(LE_EXPANSION_DRAGONFLIGHT, "Dragonflight")
addExpansionName(LE_EXPANSION_WAR_WITHIN, "The War Within")
addExpansionName(LE_EXPANSION_MIDNIGHT, "Midnight")

local function getExpansionName()
    local expansionName = "Wow: Forever - Beta"
    
    local expansionLevel = GetExpansionLevel()
    if expansionLevel == 0 then
        return expansionName
    end
    return EXPANSION_NAMES[expansionLevel]
        or select(4, GetBuildInfo())
end



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

local LOCALE = GetLocale()
if LOCALE == "enUS" then
    L["VERSION"]          = "0.1.0"
    L["EXPANSION_NAME"]   = getExpansionName()
    L["ADDON_LOADED_MSG"] = string.format(
        "%s v%s, %s.",
        ADDON_NAME,
        L["VERSION"],
        L["EXPANSION_NAME"] )
	--                          Thread-specific messages
	L["INVALID_TYPE"]				= "Uknown or unexpected data type "
    L["PARAMETER_NIL"]  			= "Function Parameter nil "
	L["INVALID_OPERATION"]			= "Operation not permitted "
	L["THREAD_HANDLE_NIL"] 		    = "Thread handle nil "
	L["THREAD_NO_COROUTINE"]        = "Ill-formed thread handle. Does not reference a coroutine "
    L["THREAD_INVALID_CONTEXT"]     = "Function failed because caller is the WoW client (WoW.exe) "
	L["THREAD_HANDLE_ILL_FORMED"]	= "Thread handle ill-formed. Check table size. "
    L["THREAD_NOT_COMPLETED"]       = "Thread has not yet completed. "

	L["THREAD_COROUTINE_DEAD"]      = "Invalid handle. Thread has completed or faulted. "
    L["THREAD_NOT_FOUND"]           = "Thread not found. "

    -- Signal failure
	L["SIGNAL_OUT_OF_RANGE"]	    = "Signal is out of range "
    L["SIGNAL_IS_NIL"]	            = "Signal is unknown or nil "
    L["SIGNAL_INVALID_TYPE"]        = "Signal type is invalid. Should be 'number' "
    L["SIGNAL_INVALID_OPERATION"]   = "SIG_NONE_PENDING can not be sent "
end
print( L["ADDON_LOADED_MSG"])
