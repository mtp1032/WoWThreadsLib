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
local SIG_READY           = thread.SIG_READY
local SIG_START           = thread.SIG_START
local SIG_STOP            = thread.SIG_STOP 
local SIG_TASK_COMPLETE   = thread.SIG_TASK_COMPLETE
local SIG_ALERT           = thread.SIG_ALERT
local SIG_CONDITION_MET   = thread.SIG_CONDITION_MET
local SIG_TERMINATE       = thread.SIG_TERMINATE
local SIG_NONE_PENDING    = thread.SIG_NONE_PENDING

local function displayResults( testTitle, testResults )

    post:message( string.format("===============================\n") )
    post:message( string.format("           %s\n", testTitle ))
    post:message( string.format("===============================\n"))

    for i = 1, #testResults do
        local rec = testResults[i]
        post:message( string.format("%s: %s\n%s\n", rec[1], rec[2], rec[3] ))
    end
    post:message( string.format("\n"))
end

local function collectData()
    local DONE = false

    -- wait for test results
    while not DONE do
        local DONE = false

        while not DONE do
            thread:yield()
            
            local signal, sender_h, testTitle, testResults = thread:getSignal()
            if signal == SIG_TASK_COMPLETE then
                displayResults( testTitle, testResults)
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

