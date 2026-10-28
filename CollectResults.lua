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

local SIG_READY             = thread.SIG_READY
local SIG_START             = thread.SIG_START
local SIG_COMPLETE          = thread.SIG_COMPLETE
local SIG_ALERT             = thread.SIG_ALERT
local SIG_CONDITION_MET     = thread.SIG_CONDITION_MET
local SIG_CREATE_THREAD     = thread.SIG_CREATE_THREAD
local SIG_TERMINATE         = thread.SIG_TERMINATE
local SIG_NONE_PENDING      = thread.SIG_NONE_PENDING

local function signalHelper(sigEntry)
    return sigEntry[1], sigEntry[2], sigEntry[3]
end

local testResults = {}

-- NOTE: the framework tests for failed outcomes. Therefore, a failed
-- unit tests is a successful outcome. Also, the 5th element of the test
-- string (testResultStr), is the error message returned by pcall. Since
-- error messages do not appear on successful tests, their result string
-- only 4 elements. 
--      "%s|%s|%s|%s" - 3 elements if test failed successfully
--      "%s|%s|%s" - 3 elements if passed (no error message) 
local function parseTestResult( testResultStr )

    -- Capture every chunk between pipe characters
    local fields = {}
    for field in str:gmatch("[^|]+") do
        table.insert(fields, field)
    end
    return fields[1], fields[2], fields[3], fields[4], fields[5]

end

local function formatTestResult( testResultStr )
    local t = {parseTestResult( testResultStr )}

    local formattedStr = string.format("%s,%s,%s,%s\n",t[1], t[2], t[3], t[4], t[5] )
    return formattedStr
end

local function collectData()
    local DONE = false

    -- wait for test results
    while not DONE do
        thread:yield()
        
        local sigEntry, errorMsg = thread:getSignal()
        assert( sigEntry, errorMsg )

        local signal, sender_h, resultsTable = signalHelper( sigEntry )
        if signal == SIG_COMPLETE then
            assert( resultsTable ~= nil, "resultsTable was nil")
            assert( type(resultsTable == "table", "INVALID DATA TYPE"))
            assert( #resultsTable == 3, "Expected 3 test string(s), got", tostring(#resultsTable))
        end
    
        if resultsTable then 
            for i = 1, #resultsTable do
                post:message( string.format("%s\n", resultsTable[i] ))
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
    return collector_h
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

local function OnEvent(self, event, ...)
    local ADDON_NAME = select(1, ...)
    local addonName = ADDON_NAME
    if event == "ADDON_LOADED" and ADDON_NAME == addonName then
		 print( L["ADDON_LOADED_MSG"] )
        eventFrame:UnregisterEvent("ADDON_LOADED")
        thread:mgmtBootstrap()
    end

    if event == "PLAYER_LOGIN" then
        local n = thread:mgmtBootstrap()
        eventFrame:UnregisterEvent("PLAYER_LOGIN")
    end
end
eventFrame:SetScript("OnEvent", OnEvent)

ns.CollectResults.loaded = true

