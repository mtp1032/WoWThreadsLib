---------------------------------------------------------
-- Filename: Core.lua
-- Author: Michael Peterson
-- Date: October, 2026

local ADDON_NAME, ns = ...

ns.Core = ns.Core or {}
local core = ns.Core

local MAJOR = 0
local MINOR = 1
local PATCH = 3
local gitVersion = MAJOR * 10000 + MINOR * 100 + PATCH
local localizedVersion = string.format("%d.%d.%d", MAJOR, MINOR, PATCH)  
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
-- returns: numericVersion, localizedVersion, expansionName
local function getExpansionName()
    local expansionName = "Wow: Forever - Beta"
    
    local expansionLevel = GetExpansionLevel()
    if expansionLevel == 0 then
        return expansionName
    end
    local fallbackName = select(4, GetBuildInfo())
    return EXPANSION_NAMES[expansionLevel] or fallbackName
end

-- returns: gitversion, addonName = core:getAddonInfo()
function core:getLibInfo()
    local expansionName = getExpansionName()
    return gitVersion, localizedVersion, expansionName
end

ns.Core.loaded = true

