util = {}

function util.hasTag(tags, tag)
    for i in pairs(tags) do
        if tags[i] == tag then
            return true
        end
    end
    return false
end