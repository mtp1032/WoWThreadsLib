--=================================================================================
-- Filename: WoWThreadsTestHarness.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...

ns.WoWThreadsTestHarness = ns.WoWThreadsTestHarness or {}

local testHarness   = ns.WoWThreadsTestHarness
local Scaffold      = ns.Scaffold
local core        = ns.Core
local utils         = ns.UtilsLib
local post          = ns.PostMessages

local _, localizedVersion = core:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error(L["THREAD_LIB_NOT_FOUND"])
end

local SIG_TERMINATE = thread.SIG_TERMINATE

-- Helper to unpack signal entries
local function signalHelper(sigEntry)
    if not sigEntry then return nil end
    return sigEntry[1], sigEntry[2], sigEntry[3]
end

--=================================================================================
-- The wrapper
--=================================================================================
local function wrapThreadCreationParams()
    -- Print header
    post:message(string.format("======================================\n"))
    post:message(string.format("      WoWThreads Automated Tests      \n"))
    post:message(string.format("======================================\n"))

    local wapper_h, errorMsg = thread:getSelf()
    -- Run each registered test. In this initial
    -- version, the wrapper only runs 3 thread creates.
    for _, t in ipairs(Scaffold.tests) do
        print("Running test:", t.name)

        -- Create a thread for the test function
        local test_h, err = thread:create(30, t.fn)
        if not test_h then
            Scaffold:reportFail(t.name, err)
            -- Continue to next test
        else
            -- Wait for SIG_TERMINATE from the master
            local done = false
            while not done do
                thread:yield()
                local sigEntry = thread:getSignal()
                local sig = signalHelper(sigEntry)

                if sig == thread.SIG_TERMINATE then
                    done = true
                end
            end
        end
    end

    -- Print summary
    Scaffold:printSummary()
end
--===========================================================
-- Master Thread: runs ONE wrapper (wrapThreadCreationParams)
--===========================================================

---------------------------------------------------------------
-- Master Thread: runs ONE wrapper (wrapThreadCreationParams)
---------------------------------------------------------------
local function masterThread()

    -- Print header
    post:message("======================================")
    post:message("      WoWThreads Automated Tests      ")
    post:message("======================================")

    -----------------------------------------------------------
    -- 1. Create a thread for the wrapper
    -----------------------------------------------------------
    post:message("Running test: Thread Creation Params")

    wrapper_h, err = thread:create(30, wrapThreadCreationParams)
    if not wrapper_h then
        Scaffold:reportFail("Thread Creation Params", err)
        Scaffold:printSummary()
        thread:sendSignal(thread.SIG_TERMINATE)   -- terminate master
        return
    end

    -----------------------------------------------------------
    -- 2. Wait for SIG_COMPLETE from the wrapper
    -----------------------------------------------------------
    local done = false
    while not done do
        thread:yield()  -- allow scheduler to run wrapper

        local sigEntry = thread:getSignal()
        if sigEntry then
            local sig = sigEntry[1]
            if sig == thread.SIG_COMPLETE then
                done = true
            end
        end
    end

    -----------------------------------------------------------
    -- 3. Print summary
    -----------------------------------------------------------
    Scaffold:printSummary()

end

local function createMasterThread()
    local errorMsg = nil
    local DONE = false

    if master_h == nil then
        master_h, errorMsg = thread:create(30, masterThread )
        if master_h == nil then
            local errorMsg = "ERROR: Failed to create master thread,"
            return nil, errorMsg
        end
    end
end

--===========================================================
-- Delayed initialization: run testHarness only after scaffold
--===========================================================

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")

frame:SetScript("OnEvent", function(_, addonName)
    if addonName == ADDON_NAME then
        while not thread:mgmtBootstrap() do
            thread:mgmtBootstrap()
        end
        print( "WoWThreadsLib started")
        -- -- Now safe to register tests and create testHarness threads
        -- if ns.Scaffold and ns.Scaffold.registerHarness then
        --     ns.Scaffold:registerHarness()
        -- end
    end
end)

frame:SetScript("OnEvent", OnEvent)
