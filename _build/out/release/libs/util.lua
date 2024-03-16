-- Author: Justin Olsen
-- GitHub: https://github.com/Justin7654/sw_the_storm
-- Workshop: <WorkshopLink>
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 344 (689 with comment) chars


 
util = {}

---@param tags table The list of tags to search through
---@param tag string the tag to check for
---@return boolean isPresent Weather or not the tag is present in the list 
function util.hasTag(tags, tag)
    for i in pairs(tags) do
        if tags[i] == tag then
            return true
        end
    end
    return false
end

