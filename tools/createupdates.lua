#!/usr/bin/env lua
--[[

 This tool generates update archives and a matching resources.xml file
 based on the git client-data repository.

 This script must be run from the client-data repository.

 It expects 'git' and 'adler32' to be available in the path.

 Configuration happens through the following environment variables:

 CLIENT_UPDATES_DIR    (example: /home/user/public_html/updates)

--]]

local function checkenv(varname)
    local value = os.getenv(varname)
    if not value then
        print(varname .. ' not set')
        os.exit(1)
    end
    return value
end

local CLIENT_UPDATES_DIR = checkenv('CLIENT_UPDATES_DIR')


local function trim(s)
    s = string.gsub(s, '^%s+', '')      -- strip preceding whitespace
    s = string.gsub(s, '%s+$', '')      -- strip trailing whitespace
    return s
end

local function capture(command)
    local f = assert(io.popen(command, 'r'))
    local s = assert(f:read('*a'))
    f:close()
    return trim(s)
end

local function execute(command)
    local result = assert(os.execute(command))
    if result ~= 0 then
        print("Error executing:")
        print(" " .. command)
        os.exit(1)
    end
end

local function git(subcommand)
    return 'git' .. ' ' .. subcommand
end

local function adler32(file)
    return string.sub(capture('adler32 ' .. file), -8)
end

local function last_revision(paths, cd)
    if cd then
        return capture('cd ' .. paths .. ';' .. git('log -1 --pretty=format:%h'))
    else
        return capture(git('log -1 --pretty=format:%h -- ' .. paths))
    end
end

local function exists(filename)
    local file = io.open(filename, "r")
    if file then
        io.close(file)
        return true
    end
    return false
end


local packages = {
    {
        name = "definitions",
        paths = {
            "avatars.xml",
            "badges.xml",
            "charcreation.xml",
            "deadmessages.xml",
            "ea-skills.xml",
            "effects.xml",
            "emotes.xml",
            "equipmentslots.xml",
            "equipmentwindow.xml",
            "hair.xml",
            "itemcolors.xml",
            "itemfields.xml",
            "items.xml",
            "maps.xml",
            "mods.xml",
            "monsters.xml",
            "npcdialogs.xml",
            "npcs.xml",
            "paths.xml",
            "pets.xml",
            "quests.xml",
            "quests",
            "settings.xml",
            "skills.xml",
            "sounds.xml",
            "stats.xml",
            "status-effects.xml",
            "units.xml",
            "weapons.xml",
        },
    },
    { name = "music", type = "music", required = "no", paths = { "music" }, cd = true, },
    { name = "sound", paths = { "sfx" }, },
    { name = "maps", paths = { "maps" }, },
    {
        name = "graphics",
        paths = {
            --"automapping",
            --"icons",
            --"graphics/items",
            --"minimaps",
            --"graphics/particles",
            --"graphics/sprites",
            "tilesets",
            "graphics",
        },
    },
}

local resources_lines = {
    '<?xml version="1.0"?>',
    '<updates>',
}

for i=1,#packages do
    local package = packages[i]
    local paths = table.concat(package.paths, ' ')
    local revision = last_revision(paths, package.cd)
    local filename = package.name .. "-" .. revision .. ".zip"
    local fullname = capture('readlink -f ' .. CLIENT_UPDATES_DIR .. '/' .. filename)

    if exists(fullname) then
        print("Skipping " .. filename .. " (already exists)")
    else
        print("Creating " .. filename)
        if package.cd then
            execute('cd ' .. paths .. ';' .. git('archive HEAD --prefix=' .. paths .. '/ --output=' .. fullname))
        else
            execute(git('archive HEAD --output=' .. fullname .. ' ' .. paths))
        end
    end

    local type = package.type or "data"
    local hash = adler32(fullname)
    local line = ' <update type="' .. type .. '"'
    if package.required == "no" then
        line = line .. ' required="no"'
    end
    line = line .. ' file="' .. filename .. '"'
    line = line .. ' hash="' .. hash .. '" '
    if package.description then
        line = line .. ' description="' .. package.description .. '"'
    end
    line = line .. '/>'
    table.insert(resources_lines, line)
end

table.insert(resources_lines, '</updates>')

print("Writing resources.xml")
local file = io.open(CLIENT_UPDATES_DIR .. "/resources.xml", "w")
file:write(table.concat(resources_lines, '\n') .. '\n')
file:close()
