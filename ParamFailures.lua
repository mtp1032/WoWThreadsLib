--=================================================================================
-- Filename: ParamFailures.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.ParamFailures    = ns.ParamFailures or {}
local ParamFailures = ns.ParamFailures
local core          = ns.Core
local L             = ns.Locales.L

local _, localizedVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error( L["THREAD_LIB_NOT_FOUND"] ) 
end
 
local SIG_START         = thread.SIG_START
local SIG_COMPLETE      = thread.SIG_COMPLETE
local SIG_NONE_PENDING  = thread.SIG_NONE_PENDING
 
-- namespace shorcuts
local utils     = ns.UtilsLib
local post      = ns.PostMessages
local params    = ns.ParamFailures
local L         = ns.Locales

-- local thread handles
local collector_h = nil 
local unitTests_h = nil -- to be wired in later
local dummy_h = nil
local main_h = nil
local mainErrorMsg = nil
local testResults = {}

-- Unit Tests
local function dummy()
    return 
end

-- generate lua error
local function unitTestOne()
    local sigEntry = nil
    local signal = sigEntry[1] -- index a nil value
    return
end
-- not a function (nil)
local function unitTestTwo()
    local dummy_h, errorMsg = thread:create( 50, nil )
    if not dummy_h then error( errorMsg ) end

end
-- invalid type for tics
local function unitTestThree()
    local dummy_h, errorMsg = thread:create( "50", dummy )
    if not dummy_h then error( errorMsg ) end
end

-- Executes unitTestOne() through unitTestSeven()
local function main()
    local errorMsg = nil
    local COMPLETE = false
    local wasSent = false

    collector_h = collect:getCollectorHandle()
    while not COMPLETE do
        thread:yield()
        if unitTests_h == nil then
            unitTests_h, errorMsg = thread:create(50, unitTests)
            assert( unitTests_h, errorMsg )
        end

        thread:yield()

        if not wasSet then
            local errorMsg = nil
            wasSent, errorMsg = thread:sendSignal(unitTests_h, SIG_START)
            if not wasSent then
                error( string.format("%s main() - failed to send SIG_START to unitTests(): %s\n", utils:dbgPrefix(), errorMsg ) )
            end
            wasSent = true
        end

        -- wait for signal from unitTests() to indicate completion
        local signal = nil
        local signal, sender_h, arg1 = thread:getSignal()
        assert( signal, errorMsg )

        if signal == SIG_COMPLETE then
            post:message( string.format("%s main() - rec'd SIG_COMPLETE from unitTests()\n", utils:dbgPrefix() ) )
            COMPLETE = true
            thread:exit( "main() received SIG_COMPLETE. Exiting." )
        end
    end
end

function ParamFailures:startTests()
    thread:disableDebugging()
    main_h, mainErrorMsg = thread:create( 50, main )
    if not main_h then error( mainErrorMsg ) end
end
