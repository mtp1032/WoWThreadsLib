--=================================================================================
-- Filename: UtilsLib.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================
local ADDON_NAME, ns = ...
ns.UtilsLib = ns.UtilsLib or {}

local utils = ns.UtilsLib
local L = ns.Locales.L

local infoNotificationFrame = nil
local resultNotificationFrame = nil
local UNKNOWN_PREFIX = "[Unknown:0] "

--======================================================================
--                          DEBUG UTILITIES
-- =====================================================================
function utils:signalHelper(sigEntry)
    local sigData = sigEntry[3]

    if sigData and sigData.n > 0 then
        return sigEntry[1],
               sigEntry[2],
               unpack(sigData, 1, sigData.n)
    end

    return sigEntry[1],
           sigEntry[2]
end
function utils:strip(trace)
    trace = trace:gsub("^.*[/\\]", "")
    trace = trace:gsub("^(.-:%d+):%s*", "%1 - ")
    return trace
end
function utils:dbgPrefix(stackTrace)
    stackTrace = stackTrace or debugstack(2)

    local fileName, lineNumber =
        stackTrace:match("[\\/]([^\\/:]+):(%d+)")

    if not fileName then
        return UNKNOWN_PREFIX
    end

    return string.format("[%s:%s] ", fileName, lineNumber)
end
function utils:dbgPrint(...)
    local prefix = utils:dbgPrefix(debugstack(2))
    local args = { n = select("#", ...), ... }

    for i = 1, args.n do
        args[i] = tostring(args[i])
    end

    prefix = string.format("|cffff9900%s|r", prefix)

    print(prefix .. table.concat(args, " "))
end
