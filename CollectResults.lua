--=================================================================================
-- Filename: CollectResults.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.CollectResults = ns.CollectResults or {}

local core      = ns.Core
local post      = ns.PostMessages
local utils     = ns.UtilsLib
local collect    = ns.CollectResults
local L         = ns.Locales.L

local _, localizedVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error( L["THREAD_LIB_NOT_FOUND"] )
end

local SIG_START             = thread.SIG_START
local SIG_COMPLETE          = thread.SIG_COMPLETE
local SIG_TERMINATE         = thread.SIG_TERMINATE

local function displayResults( testResults )

    post:message( string.format("==========================\n") )
    post:message( string.format("           TEST RESULTS\n"))
    post:message( string.format("==========================\n"))

    for i = 1, #testResults do
        local rec = testResults[i]
        post:message( string.format("%s: %s\n%s\n\n", rec[1], rec[2], rec[3] ))
    end
end

local function collectData()
    local DONE = false

    -- wait for test results
    while not DONE do
        local DONE = false

        while not DONE do
            thread:yield()
            
            local signal, sender_h, testResults = thread:getSignal()
            if signal == SIG_COMPLETE then
                displayResults( testResults)
                DONE = true
            end
            if signal == SIG_TERMINATE then
                return 
            end
        end
    end
end

function collect:getCollectorHandle()
    local collector_h = nil
    local errorMsg = nil

    if not collector_h then
    collector_h, errorMsg = thread:create( 50, collectData )
        assert( collector_h, errorMsg )
    end
    return collector_h, errorMsg
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

local function OnEvent(self, event, ...)
    if event == "ADDON_LOADED" and ADDON_NAME =="WoWThreadsLib" then
		DEFAULT_CHAT_FRAME:AddMessage( L["ADDON_LOADED_MSG"], 0,1,1 )
        eventFrame:UnregisterEvent("ADDON_LOADED")
    end

    if event == "PLAYER_LOGIN" then
        local n = thread:mgmtBootstrap()
        eventFrame:UnregisterEvent("PLAYER_LOGIN")
    end
end
eventFrame:SetScript("OnEvent", OnEvent)

ns.CollectResults.loaded = true

