 
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
    printDebug("Spawning event!")
    if event == nil then
        printDebug("(event.startEvent) event is nil!")
        return false
    end
    
    if event.currentSpawned > event.limit then
        printDebug("(event.startEvent) Limit reached for this event. This should not be happening!", true, -1)
        return false
    end

    missionVehicles = {}
    trackedVehicle = nil

    addon_index = server.getAddonIndex()
    location_index = server.getLocationIndex(addon_index, event.missionLocation)
    location_data, is_success = server.getLocationData(addon_index, location_index)
    
    if location_index == 4294967295 then
        printDebug("ERR: Failed to get location index! \n  addon_index: "..tostring(addon_index).."\n  name: "..event.missionLocation.."\n  location_index: "..tostring(location_index))
        printDebug("This may be because the location name is incorrect.")
        return false
    end

    if is_success == false then
        printDebug("ERR: Failed to get location data!\n  addon_index: "..tostring(addon_index).."\n  location_index: "..tostring(location_index))
        return false
    end
    
    tileMatrix = server.getTileTransform(matrix.translation(0,0,0), location_data.tile)

    for i = 0, location_data.component_count - 1 do
        printDebug("Location data component "..i.." of "..location_data.component_count)
        vehicleData = server.getLocationComponentData(addon_index, location_index, i)
        table.insert(missionVehicles, vehicleData)
        tags = vehicleData.tags
        for x in pairs(tags) do
            tag = tags[x]
            if tag == "track" then
                printDebug("Found tracked vehicle!")
                trackedVehicle = vehicleData
            end
        end
    end
    
    for i in pairs(missionVehicles) do
        vehicleData = missionVehicles[i] ---@type SWAddonComponentData
        
        transform = matrix.multiply(tileMatrix, vehicleData.transform)
        vehicleID = server.spawnAddonVehicle(transform, addon_index, vehicleData.id)
        server.setVehicleShowOnMap(vehicleID, true)
        mp = matrix.position(transform)
        printDebug("Spawned vehicle "..vehicleData.id.." at x"..tostring(mp[1])..", y"..tostring(mp[2])..", z"..tostring(mp[3]))
    end
    --location_index, is_success = server.spawnNamedAddonLocation(event.missionLocation)
    --locationData = server.getLocationData(addon_index, location_index)
    --server.getLocationComponentData(addon_index, location_index, )
    

    printDebug("Spawned event "..event.missionLocation)
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

