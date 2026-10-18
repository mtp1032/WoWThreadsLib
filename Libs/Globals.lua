---------------------------------------------------------
-- Filename: Globals.lua
-- Author: Michael Peterson
-- Date: October, 2026

local ADDON_NAME, ns = ...

ns.Globals = ns.Globals or {}
local global = ns.Globals

   
-----------------------------------------------------------------
-- Private functions
-----------------------------------------------------------------

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
   
-----------------------------------------------------------------
-- Private functions
-----------------------------------------------------------------

local function getExpansionName()
    local expansionName = "Wow: Forever - Beta"
    
    local expansionLevel = GetExpansionLevel()
    if expansionLevel == 0 then
        return expansionName
    end
    return EXPANSION_NAMES[expansionLevel]
        or select(4, GetBuildInfo())
end

-- retrieves the gitversion from the .toc and the expansion name.
-- returns: gitversion, addonName = global:getAddonInfo()
function global:getAddonInfo()
    local majorVersion = C_AddOns.GetAddOnMetadata(ADDON_NAME, "X-MAJOR") or "0"
    local minorVersion = C_AddOns.GetAddOnMetadata(ADDON_NAME, "X-MINOR") or "0"
    local patchVersion = C_AddOns.GetAddOnMetadata(ADDON_NAME, "X-PATCH") or "0"

    local gitVersion = string.format( "%s.%s.%s", majorVersion, minorVersion, patchVersion )
    local expansionName = getExpansionName()
    return gitVersion, expansionName
end
