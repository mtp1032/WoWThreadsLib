--=================================================================================
-- Filename: SignalPayloads.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.SignalPayloads   = ns.SignalPayloads or {}
local SignalPayloads    = ns.SignalPayloads
local core              = ns.Core
local utils             = ns.UtilsLib
local post              = ns.PostMessages
local L                 = ns.Locales.L

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
 
-- namespace shorcuts
local post      = ns.PostMessages
local collect   = ns.CollectResults
local L         = ns.Locales

local main_h = nil
local sender_h = nil
local collector_h = nil
local test1_h = nil
-- Unit Tests

-- local testResults = {
--     {1, 2, "buckle my shoe"},
--     {3, 4, "shut the door"}, 
--     {5, 6, "pick up sTICS"},
--     {7, 8, "don't be late."}
-- }
local function runTest1()

    thread:yield()

    local wasSent, errorMsg = thread:sendSignal(main_h, SIG_COMPLETE, testResults )
    assert( wasSent, errorMsg )
    post:message( string.format("Test1 completed.\n") )
end

-- creates the two tests that will execute tests of sending and receiving signals with and without payloads
local function main()
    local DONE = false
    collector_h, errorMsg = collect:getCollectorHandle()

    local test1_h, errorMsg = thread:create( 20, runTest1 )
    assert( test1_h, errorMsg )
    while not DONE do
        -- utils:dbgPrint()
        thread:yield()
        local signal, sender_h, testResults = thread:getSignal()
        assert( signal, errorMessage )

        for i = 1, #testResults do
            local rec = testResults[i]
            print( rec[1],rec[2],rec[3],rec[4])
        end
        if signal == SIG_COMPLETE then
            wasSent, errorMsg = thread:sendSignal(collector_h, SIG_COMPLETE, testResults )
            assert( wasSent, errorMsg )
            DONE = true
        end
    end
end
local function startTest()
    local errorMsg = nil

    thread:enableDebugging()

    main_h, errorMsg = thread:create(50, main )
    assert( main_h, errorMsg )
    post:message( string.format("SignalPayloads.lua: main thread created\n"))
end

function SignalPayloads:startTest()
    startTest()
end

startTest()