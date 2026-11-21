---------------------------------------------------------
-- Filename: Core.lua
-- Author: Michael Peterson
-- Date: October, 2026

local ADDON_NAME, ns = ...

ns.Core = ns.Core or {}
local core = ns.Core

local MAJOR = 0
local MINOR = 9
local PATCH = 3
local gitVersion = MAJOR * 10000 + MINOR * 100 + PATCH
local localizedVersion = string.format("%d.%d.%d", MAJOR, MINOR, PATCH)  
-----------------------------------------------------------------
-- Private functions
-----------------------------------------------------------------
local function getExpansionName()
    -- Check for Forever / Classic level explicitly if desired, 
    -- or let it resolve through the dynamic lookup table.
    local expansionLevel = GetExpansionLevel()
    
    if expansionLevel == 0 then
        -- Custom override or localized string for Forever
        return "Wow: Forever"
    end

    -- Dynamically fetch localized expansion name from global strings 
    -- e.g., EXPANSION_NAME0, EXPANSION_NAME1, etc.
    local globalName = _G["EXPANSION_NAME" .. expansionLevel]
    if globalName then
        return globalName
    end

    -- Fallback chain
    local fallbackName = select(4, GetBuildInfo())
    return fallbackName
end


-- returns: gitversion, addonName = core:getAddonInfo()
function core:getLibInfo()
    local expansionName = getExpansionName()
    return gitVersion, localizedVersion, expansionName
end

ns.Core.loaded = true

