--=================================================================================
-- Filename: TestThreadCreation.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
TestCreate = TestCreate or {}

local global = ns.Globals
local post = ns.PostMessages
local L = ns.Locales

local gitVersion = global:getAddonInfo()
local thread = LibStub("WoWThreadsLib", gitVersion )
if not thread then
    error("WoWThreads library not found.")
end

local SIG_TERMINATE    = thread.SIG_TERMINATE

local master_h = nil
local result = nil

local function helper( sigEntry )
    return sigEntry[1], sigEntry[2], sigEntry[3]
end
local function masterThread( ... )
    local DONE = false
    local iterationCount = 1

    while not DONE do
        thread:yield()
        local sigEntry, result = thread:getSignal()
        local signal, sender_h, sigData = helper( sigEntry )

        -- if this signal is from the game client the second element of
        -- sigEntry table will be nil. Let's check that that's the case:
        if sender_h == nil then
            post:message( string.format("%s\n", "sender_h is the game client (WoW.exe)."))
        end

        -- This thread, master_h, will continue to spin in this loop
        -- until it gets the SIG_TERMINATE signal.
        -- However, we have a fallback. A counter.
        iterationCount = iterationCount + 1
        if iterationCount == 3 then 
            DONE = true 
        end
        if signal == SIG_TERMINATE then
            DONE = true 
        end
    end
    post:message( string.format("%s\n", "master thread (master_h) is exiting."))
end

-- these two creation attempts will fail with an appropriate
-- error message, i.e., the parameter types are wrong.
master_h, result = thread:create( "30", masterThread ) 
if not master_h then post:message( string.format("FAIL\n"))  end

master_h, result = thread:create( 30, "masterThread" ) 
if not master_h then post:message( string.format("FAIL\n"))  end

-- this one should work, so we assert that it will
master_h, result = thread:create( 30, masterThread ) 
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

