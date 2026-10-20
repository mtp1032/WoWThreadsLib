--=================================================================================
-- Filename: TestThreadCreation.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
ns.TestCreation = ns.TestCreation or {}

local test      = ns.TestCreation
local global    = ns.Globals
local post      = ns.PostMessages
local utils     = ns.UtilsLib

local L = ns.Locales

local gitVersion = global:getLibInfo()
local thread = LibStub("WoWThreadsLib", gitVersion )
if not thread then
    error("WoWThreads library not found.")
end

local SIG_HAS_PAYLOAD  = thread.SIG_HAS_PAYLOAD
local SIG_SEND_PAYLOAD = thread.SEND_DATA
local SIG_BEGIN        = thread.SIG_BEGIN
local SIG_HALT         = thread.SIG_HALT
local SIG_COMPLETED    = thread.SIG_COMPLETED
local SIG_SUCCESS      = thread.SIG_SUCCESS
local SIG_FAILURE      = thread.SIG_FAILURE
local SIG_IS_READY     = thread.SIG_IS_READY
local SIG_CALLBACK     = thread.SIG_CALLBACK
local SIG_THREAD_DEAD  = thread.SIG_THREAD_DEAD
local SIG_ALERT        = thread.SIG_ALERT
local SIG_WAKEUP       = thread.SIG_WAKEUP
local SIG_TERMINATE    = thread.SIG_TERMINATE
local SIG_NONE_PENDING = thread.SIG_NONE_PENDING

local main_H = nil
local result = nil
local threadMetrics = {}

local function signalHelper( sigEntry )
    return sigEntry[1], sigEntry[2], sigEntry[3]
end
local function formatMetrics( tbl )
    -- the elements of a thread's metrics table
    -- tbl.threadId 	= thread_h[TH_UNIQUE_ID]
    -- tbl.Lifetime 	= thread_h[TH_TIME_COMPLETED] - thread_h[TH_TIME_CREATED]
    -- tbl.actualTicks	= thread_h[TH_ELAPSED_TICKS]
    -- tbl.totalTicks 	= thread_h[TH_YIELD_TICKS]
    -- tbl.resumptions 	= thread_h[TH_RESUMPTIONS]
    local tickInterval = 1/framerate
    
    local threadId = tbl.threadId
    local actualTime = tbl.Lifetime
    local yieldTime = tbl.yieldTicks * tickInterval
    local congestion = yieldTime/actualTime * 100
    local resumptions = tbl.resumptions
    local elapsedTicks = tbl.elapsedTicks

end
local function dummy()
    thread:yield()
    thread:sendSignal( main_h, SIG_COMPLETED )
    thread:yield()
end
local function createThreadErrors()
    -- wrong type ticks
    local test1_h, errorMsg = thread:create( "badTicks", fooBar )
    if not test1_h then post:message( errorMsg) end

    -- nil ticks
    local test2_h, errorMsg = thread:create( nil, fooBar )
    if not test2_h then post:message( errorMsg) end

    -- nil function
    local test4_h, errorMsg = thread:create( 30, nil )
    if not test4_h then post:message( errorMsg) end

    -- function not declared
    local test5_h, errorMsg = thread:create( 30, fooBar )
    if not test5_h then post:message( errorMsg) end

    -- wrong type function
    local test6_h, errorMsg = thread:create( 30, "fooBar" )
    if not thread_h then post:message( errorMsg) end

    local test6_h, errorMsg = thread:create( 30, dummy )
    if not test6_h then post:message( errorMsg) end
    
    thread:sendSignal( main_h, SIG_COMPLETED )
end
local function xpcallTest()
    for i = 1, 10 do
        thread:yield()
    end
    print("*** DONE ***")
end
--====================================================================
-- this is the thread that creates the wrapper that executes the
-- tests, collect runtime performance into from the completed threads,
-- then remove the cleanup completed threads when the system.
--====================================================================
local function main( ... )
    local DONE = false
    local sigEntry = nil

    
    -- TEST 1: tests for argument passing error from thread:create().
    -- local thread_h, errorMsg = thread:create( 30, createThreadErrors )
    -- assert( thread_h ~= nil, errorMsg )

    -- TEST 2: exercises context switching and xpcall
    local threadHandles = {}
    for i = 1, 5 do
        local ticks = math.random( 10, 30)
        threadHandles[i], errorMsg = thread:create( ticks, xpcallTest )
        assert( threadHandles[i] ~= nil, errorMsg )
    end

    local thread_h, errorMsg = thread:create( 30, createThreadErrors )
    assert( thread_h ~= nil, errorMsg )

    -- the only job main_h does is to remove threads as they complete
    -- and collect their runtime information (stats)
    if 1 < 2 then return end
    while not DONE do
        thread:yield()

        local sigEntry, errorMsg = thread:getSignal()
        assert( sigEntry, errorMsg )

        local signal, sender_h, payLoad = signalHelper( sigEntry )

        if signal == SIG_COMPLETED then

            -- Here is the structure of a thread's metrics table
            -- metrics.threadId 		= thread_h[TH_UNIQUE_ID]
            -- metrics.Lifetime 		= thread_h[TH_TIME_COMPLETED] - thread_h[TH_TIME_CREATED]
            -- metrics.elapsedTicks	= thread_h[TH_ELAPSED_TICKS]
            -- metrics.yieldTicks 	= thread_h[TH_YIELD_TICKS]
            -- metrics.resumptions 	= thread_h[TH_RESUMPTIONS]

            local tbl, errorMsg = thread:getMetrics( sender_h )
            if not threadMetrics then
                post:message( errorMsg )
                utils:dbgPrefix()
            else
                post:message( string.format( "\n\nThread[%d]\n", tbl[1] ))
                utils:dbgPrefix()
            end
        end
        if signal == SIG_TERMINATE then DONE = true end
    end
    post:message("*********** TESTS COMPLETE ***********")
end
local errorMsg = nil
main_H, errorMsg = thread:create( 30, main ) 
if not main_H then post:message( string.format("[141]FAIL - %s\n", errorMsg ))  end

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

