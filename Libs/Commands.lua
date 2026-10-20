ADDON_NAME, ns = ...

ns.Commands     = ns.Commands or {}

local test      = ns.TestCreation
local global    = ns.Globals
local post      = ns.PostMessages
local sig       = ns.SignalQueue
local utils     = ns.UtilsLib

local L = ns.Locales

-- Import the WoWThreadsLib stuff
local gitVersion = global:getLibInfo()
local thread = LibStub("WoWThreadsLib", gitVersion )
if not thread then
    error("WoWThreads library not found.")
end
