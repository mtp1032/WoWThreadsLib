--=================================================================================
-- Filename: ReportResults.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.ReportResults = ns.ReportResults or {}

local core      = ns.Core
local post      = ns.PostMessages
local utils     = ns.UtilsLib
local report    = ns.ReportResults
local L         = ns.Locales

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

function report:getReporterHandle()
    local reporter_h = nil
    local errorMsg = nil

    if not reporter_h then
        reporter_h, errorMsg = thread:create( 50, reportData )
        assert( reporter_h, errorMsg )
    end
    return reporter_h
end


-- NOTE: the framework tests for failed outcomes. Therefore, a failed
-- unit tests is a successful outcome. Also, the 5th element of the test
-- string (testResultStr), is the error message returned by pcall. Since
-- error messages do not appear on successful tests, their result string
-- only 4 elements. 
--      "%s|%s|%s|%s" - 3 elements if test failed successfully
--      "%s|%s|%s" - 3 elements if passed (no error message) 

local function formatTestResult( testResult )
    local t = {parseTestResult( testResult )}

    local formattedStr = string.format("%s,%s,%s,%s\n",t[1], t[2], t[3], t[4], t[5] )
    return formattedStr
end

local function reportData()
    local DONE = false

    -- wait for test results
    while not DONE do
        local sigEntry, errorMsg = thread:getSignal()
        assert( sigEntry, errorMsg )
        local signal, sender_h, testInfo = signalHelper( sigEntry )

        if signal == SIG_CONDITION_MET then
            if testInfo then                
                table.insert( testResults, testInfo )
                post:message( testInfo )
            end

        end

        if signal == SIG_TERMINATE then return end
        thread:yield()
    end
end

ns.ReportResults.loaded = true

