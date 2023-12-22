-- Author: Justin Olsen
-- GitHub: https://github.com/Justin7654/sw_the_storm
-- Workshop: <WorkshopLink>
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 170 (515 with comment) chars


 
util = {}

function util.hasTag(tags, tag)
    for i in pairs(tags) do
        if tags[i] == tag then
            return true
        end
    end
    return false
end

