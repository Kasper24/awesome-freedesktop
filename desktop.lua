
--[[
                                                        
     Awesome-Freedesktop                                
     Freedesktop.org compliant desktop entries and menu 
                                                        
     Desktop section                                    
                                                        
     Licensed under GNU General Public License v2       
      * (c) 2016,      Luke Bonham                      
      * (c) 2009-2015, Antonio Terceiro                 
                                                        
--]]

local awful  = require("awful")
local theme  = require("beautiful")
local utils  = require("menubar.utils")
local wibox  = require("wibox")

local capi   = { screen = screen }
local ipairs = ipairs
local mouse  = mouse
local os     = os
local string = { format = string.format }
local table  = table

local desktop = {
    baseicons = {
        [1] = {
            label = "This PC",
            icon  = "computer",
            onclick = "computer://"
        },
        [2] = {
            label = "Home",
            icon  = "user-home",
            onclick = os.getenv("HOME")
        },
        [3] = {
            label = "Trash",
            icon  = "user-trash",
            onclick = "trash://"
        }
    },
    iconsize   = { width = 48,  height = 48 },
    labelsize  = { width = 140, height = 20 },
    margin     = { x = 20, y = 20 },
}

local mime_types = {}
local desktop_current_pos = {}

local function pipelines(...)
    local f = assert(io.popen(...))
    return function () -- iterator
        local data = f:read()
        if data == nil then f:close() end
        return data
    end
end

function desktop.add_icon(args, label, icon, onclick)
    local s = args.screen

    if not desktop_current_pos[s] then
        desktop_current_pos[s] = { x = (capi.screen[s].geometry.x + args.iconsize.width + args.margin.x), y = 40 }
    end

    local totheight = (icon and args.iconsize.height or 0) + (label and args.labelsize.height or 0)
    if totheight == 0 then return end

    if desktop_current_pos[s].y + totheight > capi.screen[s].geometry.height - 40 then
        desktop_current_pos[s].x = desktop_current_pos[s].x + args.labelsize.width + args.iconsize.width + args.margin.x
        desktop_current_pos[s].y = 40
    end

    local common = { screen = s, bg = "#00000000", visible = true, type = "desktop" }

    if icon then
        icon = awful.widget.button({ image = icon })
        icon:buttons(awful.button({ }, 1, nil, onclick))
        common.width = args.iconsize.width
        common.height = args.iconsize.height
        common.x = desktop_current_pos[s].x
        common.y = desktop_current_pos[s].y
        icon_container = wibox(common)
        icon_container:set_widget(icon)
        desktop_current_pos[s].y = desktop_current_pos[s].y + args.iconsize.height + 5
    end

    if label then
        caption = wibox.widget.textbox()
        caption:fit(args.labelsize.width, args.labelsize.height)
        caption:set_align("center")
        caption:set_ellipsize("middle")
        caption:set_text(label)
        caption:buttons(awful.button({ }, 1, onclick))
        common.width = args.labelsize.width
        common.height = args.labelsize.height
        common.x = desktop_current_pos[s].x - (args.labelsize.width/2) + args.iconsize.width/2
        common.y = desktop_current_pos[s].y
        caption_container = wibox(common)
        caption_container:set_widget(caption)
    end

    desktop_current_pos[s].y = desktop_current_pos[s].y + args.labelsize.height + args.margin.y
end

function desktop.add_base_icons(args)
    for _,base in ipairs(args.baseicons) do
        desktop.add_icon(args, base.label, utils.lookup_icon(base.icon), function()
            awful.util.spawn(string.format("%s '%s'", args.open_width, base.onclick))
        end)
    end
end

function desktop.lookup_file_icon(filename)
    -- load system MIME types
    if #mime_types == 0 then
        for line in io.lines("/etc/mime.types") do
            if not line:find("^#") then
                local parsed = {}
                for w in line:gmatch("[^%s]+") do
                    table.insert(parsed, w)
                end
                if #parsed > 1 then
                    for i = 2, #parsed do
                        mime_types[parsed[i]] = parsed[1]:gsub("/", "-")
                    end
                end
            end
        end
    end

    local extension = filename:match("%a+$")
    local mime = mime_types[extension] or ""
    local mime_family = mime:match("^%a+") or ""

    local possible_filenames = {
        mime, "gnome-mime-" .. mime,
        mime_family, "gnome-mime-" .. mime_family,
        extension
    }

    for i, filename in ipairs(possible_filenames) do
        local icon = utils.lookup_icon(filename)
        if icon then return icon end
    end

    -- if we don"t find ad icon, then pretend is a plain text file
    return utils.lookup_icon("text-x-generic")
end

function desktop.parse_dirs_and_files(dir)
    local files = {}
    local paths = pipelines('find '..dir..' -maxdepth 1 -type d | tail -1')
    for path in paths do
        if path:match("[^/]+$") then
            local file = {}
            file.filename = path:match("[^/]+$")
            file.path = path
            file.show = true
            file.icon = utils.lookup_icon("folder")
            table.insert(files, file)
        end
    end
    local paths = pipelines('find '..dir..' -maxdepth 1 -type f')
    for path in paths do
        if not path:find("%.desktop$") then
            local file = {}
            file.filename = path:match("[^/]+$")
            file.path = path
            file.show = true
            file.icon = desktop.lookup_file_icon(file.filename)
            table.insert(files, file)
        end
    end
    return files
end

function desktop.add_dirs_and_files_icons(args)
    for _, file in ipairs(desktop.parse_dirs_and_files(args.dir)) do
        if file.show then
            local label = args.showlabels and file.filename or nil
            local onclick = function () awful.util.spawn(string.format("%s '%s'", args.open_with, file.path)) end
            desktop.add_icon(args, label, file.icon, onclick)
        end
    end
end

function desktop.add_icons(args)
    args            = args or {}
    args.screen     = args.screen or mouse.screen
    args.dir        = args.dir or os.getenv("HOME") .. "/Desktop"
    args.showlabels = args.showlabel or true
    args.open_with  = args.open_with or "xdg_open"
    args.baseicons  = args.baseicons or desktop.baseicons
    args.iconsize   = args.iconsize or desktop.iconsize
    args.labelsize  = args.labelsize or desktop.labelsize
    args.margin     = args.margin or desktop.margin

    if not theme.icon_theme then
        theme.icon_theme = args.icon_theme or "Adwaita"
    end

    desktop.add_base_icons(args)
    desktop.add_dirs_and_files_icons(args)
end

return desktop