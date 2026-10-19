--=================================================================================
-- Filename: TestThreadCreation.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
TestCreate = TestCreate or {}

local global = ns.Globals
local post = ns.PostMessages
local utils = ns.UtilsLib
local L = ns.Locales

local gitVersion = global:getAddonInfo()
local thread = LibStub("WoWThreadsLib", gitVersion )
if not thread then
    error("WoWThreads library not found.")
end

local SIG_TERMINATE    = thread.SIG_TERMINATE

local master_h = nil
local result = nil

local function signalHelper( sigEntry )
    return sigEntry[1], sigEntry[2], sigEntry[3]
end

local function createThreadErrors()
    -- wrong type ticks
    local thread_h, errorMsg = thread:create( "badTicks", fooBar )
    if not thread_h then post:message( errorMsg) end

    -- nil ticks
    local thread_h, errorMsg = thread:create( nil, fooBar )
    if not thread_h then post:message( errorMsg) end

    -- nil function
    local thread_h, errorMsg = thread:create( 30, nil )
    if not thread_h then post:message( errorMsg) end

    -- function not declared
    local thread_h, errorMsg = thread:create( 30, fooBar )
    if not thread_h then post:message( errorMsg) end

    -- wrong type function
    local thread_h, errorMsg = thread:create( 30, "fooBar" )
    if not thread_h then post:message( errorMsg) end
end
local function testMaster( ... )
    local thread_h, errorMsg = thread:create( 30, createThreadErrors )
    assert( thread_h ~= nil, errorMsg )
end
master_h, result = thread:create( 30, testMaster ) 
if not master_h then post:message( string.format("FAIL\n"))  end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("PLAYER_LOGIN")

local function OnEvent(self, event, ...)
    local ADDON_NAME = select(1, ...)
    if event == "ADDON_LOADED" and ADDON_NAME == "WoWThreadsLib" then
		DEFAULT_CHAT_FRAME:AddMessage(L["ADDON_LOADED_MSG"])
        eventFrame:UnregisterEvent( "ADDON_LOADED" )
        thread:libInit() -- Assuming this is defined elsewhere
    end
end
eventFrame:SetScript("OnEvent", OnEvent)

