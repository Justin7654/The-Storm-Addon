 
-- Author: Justin Olsen
-- GitHub: https://github.com/Justin7654/sw_the_storm
-- Workshop: <WorkshopLink>
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey
util = {}

function util.hasTag(tags, tag)
    for i in pairs(tags) do
        if tags[i] == tag then
            return true
        end
    end
    return false
end


event = {}

---Loads a given event
--@param event WorldEvent The event to load
---@return WorldEventData|false EventData Data related to the event
function event.startEvent(event)
    printDebug("Spawning event!")
    if event == nil then
        printDebug("(event.startEvent) event is nil!")
        return false
    end

    -- Spawn the event
    missionVehicleData = {}
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
        table.insert(missionVehicleData, vehicleData)
        tags = vehicleData.tags
        if util.hasTag(tags, "track") then
            printDebug("Found tracked vehicle!")
            trackedVehicle = vehicleData
        end
    end
    
    for i in pairs(missionVehicleData) do
        vehicleData = missionVehicleData[i] ---@type SWAddonComponentData
        
        transform = matrix.multiply(tileMatrix, vehicleData.transform)
        vehicleID = server.spawnAddonVehicle(transform, addon_index, vehicleData.id)
        table.insert(missionVehicles, vehicleID)
        printDebug("Spawned vehicle with id "..vehicleID)

        --Spawn the event label on the vehicle if it is the tracked vehicle
        if trackedVehicle == vehicleData then
            printDebug("Spawning label on tracked vehicle!", true, -1)
            x, y, z = matrix.position(transform)
            ---@diagnostic disable-next-line: param-type-mismatch
            server.addMapLabel(-1, server.getMapID(), event.mapLabelType, event.mapLabelName, x, z)
        end
    end
    
    --Add to event data
    if g_savedata.worldEventData == nil then g_savedata.worldEventData = {} end
    if g_savedata.worldEventData[event.missionLocation] == nil then g_savedata.worldEventData[event.missionLocation] = {} end

    table.insert(g_savedata.worldEventData[event.missionLocation], {missionVehicles = missionVehicles, trackedVehicle = trackedVehicle, mapLabelId = trackedVehicle.id})

    printDebug("Spawned event "..event.missionLocation)

    return g_savedata.worldEventData[event.missionLocation]
end

---@param is_instant boolean Weather or not to instantly despawn the vehicles. If false, they will be despawned when the player is not nearby
function event.cleanEvents(is_instant)
    activeEvents = {} ---Table containing all active events
    --Collect
    printDebug("(events.cleanEvents) Collecting...")
    for i in pairs(g_savedata.worldEventData) do
        eventType = g_savedata.worldEventData[i]
        for j in pairs(eventType) do
            theEvent = eventType[j]
            if theEvent ~= nil then
                table.insert(activeEvents, theEvent)
            end
        end
    end

    printDebug("(events.cleanEvents) Found "..#activeEvents.." events")
    --Clean
    printDebug("(events.cleanEvents) Cleaning...")
    for i in pairs(activeEvents) do
        currentEvent = activeEvents[i] ---@type WorldEventData
        vehicles = currentEvent.missionVehicles
        for i in pairs(vehicles) do
            vehicleID = vehicles[i] ---@type SWAddonComponentData
            if vehicleID == nil then goto continue end
            --Delete the vehicle
            ---@diagnostic disable-next-line: param-type-mismatch
            is_success = server.despawnVehicle(vehicleID, is_instant)
            if is_success == false then
                printDebug("(events.cleanEvents) ERR: Failed to despawn vehicle with id "..tostring(vehicleID).."!")
            else
                printDebug("(events.cleanEvents) Despawned vehicle with id "..tostring(vehicleID))
            end
            ::continue::
        end
        --Delete the map label
        if currentEvent.mapLabelId ~= nil then
            is_success = server.removeMapLabel(-1, currentEvent.mapLabelId)
            if is_success == false then
                printDebug("(events.cleanEvents) ERR: Failed to remove map label with id "..tostring(currentEvent.mapLabelId).."!")
            else
                printDebug("(events.cleanEvents) Removed map label with id "..tostring(currentEvent.mapLabelId))
            end
        end
    end
    g_savedata.worldEventData = {}
    return true
end

---@param event WorldEvent The event to check
---@return boolean Whether or not the event is currently available
function event.getAvaibility(event)
    if event.missionLocation == nil then
        printDebug("(event.getAvaibility) event.missionLocation is nil!")
        return false
    end
    --Find the max
    max = nil
    for i =1, #g_savedata.worldEvents do
        if g_savedata.worldEvents[i].missionLocation == event.missionLocation then
            max = g_savedata.worldEvents[i].max
        end
    end

    if max == nil then
        printDebug("event.getAbaibility) Unable to find event with the same missionLocation name! missionLocation: "..event.missionLocation)
        return false
    end
    --Check if we have reached the max

    currentNumber = #(g_savedata.worldEvents[event.missionLocation])
    return max > currentNumber
end

---Returns a random weighted event that is currently available
--- @param seed nil The seed to use for the random number generator. If nil, the current seed will be used
--- @return WorldEvent|nil EventData The event that was chosen
function event.getRandomEvent(seed)
    math.randomseed(seed or 0, server.getTimeMillisec())
    options = g_savedata.worldEvents
    totalWeight = 0
    for i, event in ipairs(options) do
        totalWeight = totalWeight + event.weight
    end
    random = math.random(0, totalWeight)
    for i in ipairs(options) do
        event = options[i]
        random = random - event.weight
        if random <= 0 then
            isAvailable = event.getAvaibility(event)
            if isAvailable then
                return event
            else
                return event.getRandomEvent((seed+1) or 1)
            end
        end
    end
    --printDebug("(event.getRandomEvent) WARNING: FAILED TO GET RANDOM EVENT!\nSeed: "..seed.."\nTotal Weight: "..totalWeight.."\nRandom: "..random.."\nOptions: "..#options, true, -1)
    return nil
end

