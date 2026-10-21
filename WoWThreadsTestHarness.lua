--=================================================================================
-- WoWThreads Test Harness
--=================================================================================

local ADDON_NAME, ns = ...

local Scaffold = ns.Scaffold
local global = ns.Globals

local _, localizedVersion = global:getLibInfo()
local thread = LibStub("WoWThreadsLib", localizedVersion )
if not thread then
    error("WoWThreads library not found.")
end

local main_h = nil

-- Helper to unpack signal entries
local function signalHelper(sigEntry)
    if not sigEntry then return nil end
    return sigEntry[1], sigEntry[2], sigEntry[3]
end

--=================================================================================
-- Master test runner thread
--=================================================================================
local function masterTestThread()
    -- Print header
    print(" ")
    print("======================================")
    print("      WoWThreads Automated Tests       ")
    print("======================================")
    print(" ")

    -- Run each registered test
    for _, t in ipairs(Scaffold.tests) do
        print("Running test:", t.name)

        -- Create a thread for the test function
        local test_h, err = thread:create(30, t.fn)
        if not test_h then
            Scaffold:reportFail(t.name, err)
            -- Continue to next test
        else
            -- Wait for SIG_TERMINATE from the test
            local done = false
            while not done do
                thread:yield()
                local sigEntry = thread:getSignal()
                local sig = signalHelper(sigEntry)

                if sig == thread.SIG_TERMINATE then
                    done = true
                end
            end

            -- If the test function threw an error, Scaffold:reportFail()
            -- If it printed PASS, Scaffold:reportPass()
            -- The test function itself is responsible for calling error() on failure
        end
    end

    -- Print summary
    Scaffold:printSummary()
end

--=================================================================================
-- Create master thread
--=================================================================================
main_h = thread:create(30, masterTestThread)
if not main_h then
    error("Failed to create master test thread.")
end

--=================================================================================
-- Event handling (same as your scaffold)
--=================================================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

local function OnEvent(self, event, ...)
    local addonName = select(1, ...)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        eventFrame:UnregisterEvent("ADDON_LOADED")
        thread:libInit()
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
