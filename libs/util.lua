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