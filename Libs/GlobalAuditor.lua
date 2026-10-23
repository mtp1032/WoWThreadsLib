--=================================================================================
-- Filename: GlobalAuditor.lua
-- Author: Michael Peterson
-- Date: October, 2026
--=================================================================================

local ADDON_NAME, ns = ...

ns.GlobalAuditor = ns.GlobalAuditor or {}

local global = ns.GlobalAuditor
local post = ns.PostMessages

-- Private snapshot storage
local globalsSnapshot = nil

------------------------------------------------------------
-- Capture the current global namespace
------------------------------------------------------------
function global:snapshotGlobals()

    globalsSnapshot = {}

    local count = 0

    for name, value in pairs(_G) do

        globalsSnapshot[name] = value
        count = count + 1

    end

    post:message(
        string.format(
            "Global snapshot created: %d variables recorded.\n",
            count
        )
    )

end

------------------------------------------------------------
-- Compare current globals against the snapshot
------------------------------------------------------------
function global:checkGlobals()

    if not globalsSnapshot then
        post:message(
            "No snapshot exists. Use /globals snapshot first.\n"
        )
        return
    end

    local newGlobals = {}
    local modifiedGlobals = {}
    local deletedGlobals = {}

    --------------------------------------------------------
    -- Find new and modified globals
    --------------------------------------------------------
    for name, value in pairs(_G) do

        if globalsSnapshot[name] == nil then

            table.insert(
                newGlobals,
                string.format(
                    "%s (%s)",
                    tostring(name),
                    type(value)
                )
            )

        elseif globalsSnapshot[name] ~= value then

            table.insert(
                modifiedGlobals,
                string.format(
                    "%s (%s)",
                    tostring(name),
                    type(value)
                )
            )

        end

    end

    --------------------------------------------------------
    -- Find deleted globals
    --------------------------------------------------------
    for name, value in pairs(globalsSnapshot) do

        if rawget(_G, name) == nil then

            table.insert(
                deletedGlobals,
                string.format(
                    "%s (%s)",
                    tostring(name),
                    type(value)
                )
            )

        end

    end

    --------------------------------------------------------
    -- Sort results alphabetically
    --------------------------------------------------------
    table.sort(newGlobals)
    table.sort(modifiedGlobals)
    table.sort(deletedGlobals)

    --------------------------------------------------------
    -- Print audit results
    --------------------------------------------------------
    post:message("\nGLOBAL NAMESPACE AUDIT\n")
    post:message("==========================\n")

    -- New globals
    post:message("\nNEW GLOBALS\n")

    if #newGlobals == 0 then

        post:message("   None\n")

    else

        for _, entry in ipairs(newGlobals) do
            post:message("   " .. entry .. "\n")
        end

    end

    -- Modified globals
    post:message("\nMODIFIED GLOBALS\n")

    if #modifiedGlobals == 0 then

        post:message("   None\n")

    else

        for _, entry in ipairs(modifiedGlobals) do
            post:message("   " .. entry .. "\n")
        end

    end

    -- Deleted globals
    post:message("\nDELETED GLOBALS\n")

    if #deletedGlobals == 0 then

        post:message("   None\n")

    else

        for _, entry in ipairs(deletedGlobals) do
            post:message("   " .. entry .. "\n")
        end

    end

    --------------------------------------------------------
    -- Print summary
    --------------------------------------------------------
    post:message("\n==========================\n")

    post:message(
        string.format(
            "New: %d  Modified: %d  Deleted: %d\n",
            #newGlobals,
            #modifiedGlobals,
            #deletedGlobals
        )
    )

end

------------------------------------------------------------
-- List globals matching a specified prefix
------------------------------------------------------------
function global:listGlobals(prefix)

    if not prefix or prefix == "" then
        post:message("Usage: /globals list <prefix>\n")
        return
    end

    local matches = {}

    for name, value in pairs(_G) do

        if type(name) == "string"
            and name:sub(1, #prefix) == prefix then

            table.insert(
                matches,
                string.format(
                    "%s (%s)",
                    name,
                    type(value)
                )
            )

        end

    end

    table.sort(matches)

    post:message(
        "\nGlobals beginning with: " .. prefix .. "\n"
    )

    for _, entry in ipairs(matches) do
        post:message("   " .. entry .. "\n")
    end

    post:message(
        string.format(
            "Total matching globals: %d\n",
            #matches
        )
    )

end

------------------------------------------------------------
-- Slash command registration
------------------------------------------------------------
SLASH_GLOBAL_AUDITOR1 = "/globals"

SlashCmdList["GLOBAL_AUDITOR"] = function(msg)

    local command, argument =
        msg:match("^%s*(%S+)%s*(.-)%s*$")

    command = command and command:lower() or ""

    if command == "snapshot" then

        global:snapshotGlobals()

    elseif command == "check" then

        global:checkGlobals()

    elseif command == "list" then

        global:listGlobals(argument)

    else

        post:message("\nGlobal Namespace Auditor\n")
        post:message("==========================\n")
        post:message("/globals snapshot\n")
        post:message("/globals check\n")
        post:message("/globals list <prefix>\n")

    end

end