-- Author: Justin Olsen
-- GitHub: https://github.com/Justin7654/sw_the_storm
-- Workshop: <WorkshopLink>
--
-- Developed & Minimized using LifeBoatAPI - Stormworks Lua plugin for VSCode
-- https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey
-- Minimized Size: 1536 (1883 with comment) chars


 
-- Author: Justin Olsen
-- GitHub: https://github.com/Justin7654/sw_the_storm
-- Workshop: <WorkshopLink>
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey


event = {}

---Loads a given event
---@param event WorldEvent The event to load
function event.startEvent(event)
    if event == nil then
        printDebug("(event.startEvent) event is nil!")
        return false
    end
    ---
end

---Ends a given event
function event.endEvent(event)
    
end

---Returns a random weighted event that is currently available
--- @param seed nil The seed to use for the random number generator. If nil, the current seed will be used
function event.getRandomEvent(seed)
    if seed then math.randomseed(seed, server.getTimeMillisec()) end
    options = g_savedata.worldEvents
    totalWeight = 0
    for i, event in ipairs(options) do
        totalWeight = totalWeight + event.weight
    end
    random = math.random(0, totalWeight)
    for i, event in ipairs(options) do
        random = random - event.weight
        if random <= 0 then
            return event
        end
    end
    printDebug("(event.getRandomEvent) WARNING: FAILED TO GET RANDOM EVENT!\nSeed: "..seed.."\nTotal Weight: "..totalWeight.."\nRandom: "..random.."\nOptions: "..#options, true, -1)
    return nil
end

