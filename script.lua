--- 1010: bad arg #1 to 'random' (interval is empty)
---@diagnostic disable: undefined-doc-param
-- Author: Justin
-- GitHub: <GithubLink>
-- Workshop: <WorkshopLink>

--Libraries
require("libs.enum")
require("libs.event")

---@class WorldEvent
---@field missionLocation string The name of the mission location in the addon editor
---@field mapLabelType integer The type of map label to use. See enum.MAP_LABEL.LABEL_TYPES
---@field mapLabelName string The text under the map label
---@field limit integer The maximum amount of this event at a single time. If nil, it will be unlimited
---@field weight integer The weight of the event. The higher the weight, the more likely it is to be chosen

---@class WorldEventData
---@field trackedVehicle SWAddonComponentData The tracked vehicle
---@field missionVehicles SWAddonComponentData[] The vehicles in the event
---@field mapLabelId integer The id of the map label for the tracked vehicle

time = {
	second = 60,
	minute = 3600,
	hour = 216000,
	day = 5184000
}

g_savedata = {
    tick_counter = 1,
    powerFailureLoopSmoothing = 1,
    debug = false,
    superDebug = false,
    cooldown = 0,
    settings = {
        VOLCANOS = property.checkbox("Volcanos More Active During Storm", true),
        POWER_FAILURES = property.checkbox("Power Failures (Vehicles can temporarly lose power)", true),
        DYNAMIC_MUSIC = property.checkbox("Dynamic Music", true),
        COOLDOWN_TIME = property.slider("Cooldown (minutes)", 5, 60, 1, 30)*time.minute, --The cooldown between storms
        START_CHANCE = property.slider("Storm Chance per minute (%)", 0, 100, 5, 5),  --The chance every 60s that a storm can start
        MIN_LENGTH = property.slider("Min storm length (minutes)", 5, 60, 5, 5)*time.minute, --Min length a storm can last
        MAX_LENGTH = property.slider("Max storm length (minutes)", 5, 60, 5, 15)*time.minute, -- Max length that a storm can last
        WIND_LENGTH = property.slider("Storm start/stop time (seconds)", 30, 240, 15, 120)*time.second, --Windown/Windup length for storms
        RAIN_AMOUNT = property.slider("Storm Rain Amount (%)", 50, 100, 10, 100)/100, --The peak rain intensity of a storm
        WIND_AMOUNT = property.slider("Storm Wind Amount (%)", 50, 150, 10, 120)/100, --The peak wind intensity of a storm
        FOG_AMOUNT = property.slider("Storm Fog Amount (%)", 50, 100, 10, 80)/100, --The peak fog intensity of a storm
        POWER_FAILURE_CHANCE = property.slider("Power failure chance every second (%)", 1,5, 0.1, 1), --The chance that a vehicle will fail during a storm
        BYPASS_SEASONAL_EVENTS = false, ---Changable in settings, for debugging purposes
    },
    storm = {
        ["active"] = false,
        ["stage"] = nil, --What stage the storm is at [nil,"windUp", "full","windDown"]
        ["tweenStart"] = nil, --The tick at which the tween started
        ["tweenPosition"] = nil, --What position out of the WIND_LENGTH setting its currently at. Only used when the storm is winding up or down.
        ["endTime"] = nil, --Tick at which the storm will end
        ["startConditions"] = {
            rain = nil,
            wind = nil,
            fog = nil,
        },
    },
    worldEvents = {
        {
            missionLocation = "KEY LIGHTHOUSE OB",
            mapLabelType = enum.MAP_LABEL.LABEL_TYPES.CROSS,
            mapLabelName = "Track blockage",
            limit = 1,
            weight = 1,
        },
        {
            missionLocation = "TRACK STRAIGHT FORK LEFT ROT_2",
            mapLabelType = enum.MAP_LABEL.LABEL_TYPES.CROSS,
            mapLabelName = "Track blockage",
            limit = 1,
            weight = 1,
        }
    },
    worldEventData = {
        ---Table with the key being the mission location name
        ---Inside each key is a array of data for each event
    },
    powerFailures = {},
    playerVehicles = {},
    playerMoodStates = {},
}

settingConversionData = {
    VOLCANOS = "bool",
    POWER_FAILURES = "bool",
    DYNAMIC_MUSIC = "bool",
    COOLDOWN_TIME = "number",
    START_CHANCE = "number",
    MIN_LENGTH = "number",
    MAX_LENGTH = "number",
    WIND_LENGTH = "number",
    RAIN_AMOUNT = "number",
    WIND_AMOUNT = "number",
    FOG_AMOUNT = "number",
    POWER_FAILURE_CHANCE = "number",
    BYPASS_SEASONAL_EVENTS = "bool",
}

enum = {    
    SEASONAL_EVENTS = {
        NONE = 0,
        HALLOWEEN = 1,
        CHRISTMAS = 2,
    },
    NOTIFICATION_TYPES = {
        NEW_MISSION = 0,
        NEW_MISSION_CRITICAL = 1,
        FAILED_MISSION = 2,
        FAILED_MISSION_CRITICAL = 3,
        COMPLETE_MISSION = 4,
        NETWORK_CONNECT = 5,
        NETWORK_DISCONNECT = 6,
        NETWORK_INFO = 7,
        CHAT_MESSAGE = 8,
        NETWORK_INFO_CRITICAL = 9,
    },
    MAP_OBJECT = {
        POSITION_TYPES = {
            FIXED = 0,
            VEHICLE = 1,
            OBJECT = 2,
        },
        MARKER_TYPES = {
            DELIVERY_TARGET = 0,
            SURVIVOR = 1,
            OBJECT = 2,
            WAYPOINT = 3,
            TUTORIAL = 4,
            FIRE = 5,
            SHARK = 6,
            ICE = 7,
            SEARCH_RADIUS = 8,
            FLAG_1 = 9,
            FLAG_2 = 10,
            HOUSE = 11,
            CAR = 12,
            PLANE = 13,
            TANK = 14,
            HELI = 15,
            SHIP = 16,
            BOAT = 17,
            ATTACK = 18,
            DEFEND = 19,
        },
    },
    MAP_LABEL = {
        LABEL_TYPES = {
            NONE = 0,
            CROSS = 1,
            WRECKAGE = 2,
            TERMINAL = 3,
            MILITARY = 4,
            HERITAGE = 5,
            RIG = 6,
            INDUSTRIAL = 7,
            HOSPITAL = 8,
            SCIENCE = 9,
            AIRPORT = 10,
            COASTGUARD = 11,
            LIGHTHOUSE = 12,
            FUEL = 13,
            FUEL_SELL = 14,
        },
    },
    FLUID_TYPE = {
        FRESH_WATER = 0,
        DIESEL = 1,
        JET_FUEL = 2,
        AIR = 3,
        EXHAUST = 4,
        OIL = 5,
        SEA_WATER = 6,
        STEAM = 7,
        SLURRY = 8,
        SATURATED_SLURRY = 9,
    },
}

function onCreate(is_world_create)
    if g_savedata.settings.MIN_LENGTH > g_savedata.settings.MAX_LENGTH then g_savedata.settings.MIN_LENGTH = g_savedata.settings.MAX_LENGTH end
    if g_savedata.settings.VOLCANOS == nil then g_savedata.settings.VOLCANOS = true end

    if is_world_create then event.validateEvents() end

    --Standardized Discovery Message
    server.command(([[AddonDiscoveryAPI discovery "%s" --category:"Gameplay" --version:"%s"]]):format("The Storm", "1.0"))
end

function onTick(game_ticks)
    g_savedata.tick_counter = g_savedata.tick_counter + 1
    tickStorm()
    tickPowerFailures()
    tickMusic()
    tickEvent()
    tickHorror()
end
  
--- Handles stuff like winding storms, random storms, ending storms, stuff like that
function tickStorm()
    --Start the storm randomly
    if g_savedata.storm.active == false then
        if (g_savedata.cooldown==0) then
            if (isTickID(0,time.minute)) then
                if(randomRange(0,100)<tonumber(g_savedata.settings.START_CHANCE)) then
                    startStorm()
                else
                    printDebug("Failed random storm spawn, retrying in 1 minute.", true)
                end
            end

        else
            g_savedata.cooldown = g_savedata.cooldown - 1;
        end
    end

    --Do stuff with the storm based on stage
    if g_savedata.storm.active == false then return end
    if not isTickID(0,2) then return end

    settings = g_savedata.settings
    storm = g_savedata.storm
    stage = storm.stage

    if isTickID(0,60) then
        state =  server.getGameSettings().override_weather
        if state == false then
            printDebug("Overide weather is required for the addon to function! To end the storm, type ?storm end in chat", false, -1)
            server.setGameSetting("override_weather", true)
        end
    end

    if (stage == "windUp") then
        startValue = storm.windStart; --The start value
        tweenPosition = g_savedata.tick_counter - storm["tweenStart"]--The current position in the tween
        tweenTime = g_savedata.settings.WIND_LENGTH; --The time in ticks that the tween will last
        
        hostPos = server.getPlayerPos(0)
        currentWeather = sampleWeather(hostPos)--server.getWeather(hostPos); --Gets the weather at the hosts location

        fogValue = tween(currentWeather.fog, settings.FOG_AMOUNT, tweenPosition, tweenTime)
        windValue = tween(currentWeather.wind, settings.WIND_AMOUNT, tweenPosition, tweenTime)
        rainValue = tween(currentWeather.rain, settings.RAIN_AMOUNT, tweenPosition, tweenTime)

        superDebug("Tween Position: "..tostring(tweenPosition).."/"..tostring(g_savedata.settings.WIND_LENGTH))
        superDebug("Fog val: ".. tostring(fogValue))
        superDebug("Wind val: "..tostring(windValue))
        superDebug("Rain val: "..tostring(rainValue))

        server.setWeather(fogValue, rainValue, windValue)

        if(g_savedata.tick_counter>=(storm["tweenStart"]+g_savedata.settings.WIND_LENGTH))then
            --End tween
            storm.stage = "full"
            storm["endTime"] = g_savedata.tick_counter + randomRange(settings.MIN_LENGTH, settings.MAX_LENGTH)
            printDebug("Complete wind up. Storm will end at tick "..tostring(storm["endTime"]),true)
            if isEvent(enum.SEASONAL_EVENTS.HALLOWEEN) then
                server.notify(-1, "Broadcast", "Something feels off about this once...", enum.NOTIFICATION_TYPES.CHAT_MESSAGE)
            end
        end
    elseif (stage == "full") then
        --Set weather back every 15 ticks to avoid tampering
        if isTickID(0,15) then server.setWeather(settings.FOG_AMOUNT,settings.RAIN_AMOUNT,settings.WIND_AMOUNT) end

        --End storm when needed
        if g_savedata.tick_counter >= g_savedata.storm["endTime"] then
            --Times up! End the storm
            endStorm()
        end

        if not isTickID(0,60) then return end
        --Everything below this runs once every second

        --Blow up volcanos near players
        if g_savedata.settings.VOLCANOS then
            players = server.getPlayers()
            volcanos = server.getVolcanos()
            for _, player in pairs(players) do
                for _, volcano in pairs(volcanos) do
                    if randomRange(0,100) ~= 0 then goto continue end
                    playerPos = server.getPlayerPos(player.id)
                    volcanoPos = matrix.translation(volcano.x, volcano.y, volcano.z)
                    distanceFrom = distance(playerPos, volcanoPos)
                    
                    if distanceFrom < 6000 then --No idea what the actual 
                        printDebug("Volcano triggered near "..server.getPlayerName(player.id)..", Watch out!", true, -1)
                        ---@diagnostic disable-next-line: missing-parameter
                        success = server.spawnVolcano(volcanoPos) --bug in lifeboat API, there is no 2nd parameter for magnitude
                    end

                    ::continue::
                end
            end
        end

        --Random vehicle power failures
        if g_savedata.settings.POWER_FAILURES and (#g_savedata.playerVehicles > 0) then
            --superDebug("Rolling vehicle ".. tostring(g_savedata.playerVehicles[g_savedata.powerFailureLoopSmoothing].id).. " for power failure")        
            if randomChance(g_savedata.settings.POWER_FAILURE_CHANCE, g_savedata.tick_counter) then
                vehicle = g_savedata.playerVehicles[g_savedata.powerFailureLoopSmoothing]
                if server.getVehicleSimulating(vehicle.id) == true then
                    --Check to see if its already failed
                    for _, failure in pairs(g_savedata.powerFailures) do
                        if failure.vehicleID == vehicle.id then
                            goto fail
                            break
                        end
                    end

                    --Fail the vehicle
                    if randomChance(70, 855+g_savedata.powerFailureLoopSmoothing) then
                        length = randomRange(3, 20)*time.second
                    else
                        printDebug("Uh oh! This blackout is going to last awhile...", true, -1)
                        length = randomRange(20,150)*time.second    
                    end
                    printDebug("Failing vehicle with id "..tostring(vehicle.id).." for "..tostring(length).." ticks ("..tostring(length/time.second).."s)", true)
                    is_success = failVehiclePower(vehicle.id, length)

                    ::fail::
                else
                    printDebug("Vehicle is not simulating, aborting.", true)
                end
            end
            g_savedata.powerFailureLoopSmoothing = g_savedata.powerFailureLoopSmoothing + 1
            if g_savedata.playerVehicles[g_savedata.powerFailureLoopSmoothing] == nil then g_savedata.powerFailureLoopSmoothing = 1 end
        end


    elseif (stage == "windDown") then
        startValue = storm.windStart; --The start value
        tweenPosition = g_savedata.tick_counter - storm["tweenStart"]--The current position in the tween
        tweenTime = g_savedata.settings.WIND_LENGTH; --The time in ticks that the tween will last
        
        hostPos = server.getPlayerPos(0);
        startWeather = g_savedata.storm["startConditions"]
        sample = sampleWeather(hostPos)
        
        fogValue = tween(startWeather.fog, sample.fog, tweenPosition, tweenTime)
        windValue = tween(startWeather.wind, sample.wind, tweenPosition, tweenTime)
        rainValue = tween(startWeather.rain, sample.rain, tweenPosition, tweenTime)

        --printDebug("Tween Position: "..tostring(tweenPosition), true)
        superDebug("Tween Position: "..tostring(tweenPosition).."/"..tostring(g_savedata.settings.WIND_LENGTH))
        superDebug("Fog val: ".. tostring(fogValue))
        superDebug("Wind val: "..tostring(windValue))
        superDebug("Rain val: "..tostring(rainValue))

        server.setWeather(fogValue, rainValue, windValue);

        if(g_savedata.tick_counter>=(storm["tweenStart"]+g_savedata.settings.WIND_LENGTH))then
            --End tween
            storm.stage = nil
            storm.active = false
            storm["endTime"] = g_savedata.tick_counter + randomRange(settings.MIN_LENGTH, settings.MAX_LENGTH)
            server.setGameSetting("override_weather", false)
            printDebug("Complete wind down.",true)
        end
    else
        printDebug("Invalid storm stage! ("..tostring(stage)..")", true)
    end
end

--- Handles ending power failures and returning vehicles to their original state
function tickPowerFailures()
    if not isTickID(0,5) then return end
    for i, failure in pairs(g_savedata.powerFailures) do
        --Check if the vehicle still exists
        is_simulating, is_success = server.getVehicleSimulating(failure.vehicleID)
        if is_success == false then
            printDebug("Removed vehicle with id "..tostring(failure.vehicleID).." from power table because it no longer exists", true)
            table.remove(g_savedata.powerFailures, i)
            goto continue;
        end
        if is_simulating == false then goto continue end --Wait for it to simulate again before setting it back to prevent issues

        --Check if its time for it to expire
        if failure.expire <= g_savedata.tick_counter then
            printDebug("Recovered vehicle with id "..tostring(failure.vehicleID).." from power failure", true)
            for _, battery in pairs(failure.originalStates) do
                superDebug("(tickPowerFailures) Recovering battery with name "..tostring(battery.name).. "to ".. tostring(battery.charge).."%")
                server.setVehicleBattery(failure.vehicleID, battery.pos.x, battery.pos.y, battery.pos.z , battery.charge)
            end
            table.remove(g_savedata.powerFailures, i)
        end
        ::continue::
    end
end

--- Handles music mood, high music mood if not at in a shelter/owned tile during a storm and low mood if in a shelter/owned tile
function tickMusic()
    if not isTickID(2,3*time.second) or g_savedata.storm.active == false then return end
    if g_savedata.settings.DYNAMIC_MUSIC ~= true and g_savedata.settings.DYNAMIC_MUSIC ~= "true" then return end --Both string and bool to support command changing it
    shelterTag = "shelter" --The tag used to mark shelters
    for _, player in pairs(server.getPlayers()) do
        playerPos = server.getPlayerPos(player.id) 
        isOwned = server.getTilePurchased(playerPos)
        isShelter = server.isInZone(playerPos, shelterTag)
        if isOwned or isShelter then
            if g_savedata.playerMoodStates[player.id] ~= 1 then printDebug(player.name.." audio set to mood_low", true) end
            server.setAudioMood(player.id, 2)
            g_savedata.playerMoodStates[player.id] = 1
        else
            if g_savedata.playerMoodStates[player.id] ~= 3 then printDebug(player.name.." audio set to mood_high", true) end
            server.setAudioMood(player.id, 4)
            g_savedata.playerMoodStates[player.id] = 4
        end
    end   

end

--- Active during the halloween event, and rarely during normal gameplay outside of it
function tickHorror()
    if not isTickID(1, 5*time.second) then return end
    if server.getSeasonalEvent() ~= enum.SEASONAL_EVENTS.HALLOWEEN and not g_savedata.settings.BYPASS_SEASONAL_EVENTS then return end
    --TODO: Think of stuff to do here
    --Power
end

function tickEvent()
    if not isTickID(4, 10*time.second) then return end
    --Large meteor shower   

end

function onVehicleDespawn(vehicle_id, peer_id)
    for i, item in pairs(g_savedata.playerVehicles) do
        if item.id == vehicle_id then
            table.remove(g_savedata.playerVehicles, i)
            printDebug("Removed vehicle with id "..tostring(item.id).." from player vehicles table", true, peer_id)
            break
        end
    end
end


function onVehicleSpawn(vehicle_id, peer_id)
    if peer_id == -1 then return end
    --Print the type of vehicle_id
    table.insert(g_savedata.playerVehicles, {id = vehicle_id, peer_id = peer_id})
    printDebug("Added vehicle with id "..tostring(vehicle_id).." to player vehicles table", true, peer_id)
end

function onCustomCommand(full_message, peer_id, is_admin, is_auth, prefix, command, ...)    
    if prefix ~= "?storm" or not is_admin then return end
    if peer_id ~= 0 then printDebug("Command Entered: "..full_message..". From peer ".. tostring(peer_id), false, 0) end

    local arg = table.pack(...)

    if (command == "start") then
        printDebug("Starting Storm", false,peer_id)
        startStorm()
    elseif (command == "end") then
        printDebug("Stopping storm", false, peer_id)
        endStorm()
    elseif(command == "debug") then
        g_savedata.debug = not g_savedata.debug
        printDebug("Toggled debug. New value: "..tostring(g_savedata.debug), false, peer_id)
    elseif(command == "superDebug") then
        if g_savedata.superDebug == nil then g_savedata.superDebug = false end
        g_savedata.superDebug = not g_savedata.superDebug
        printDebug("Toggled super debug. New value: "..tostring(g_savedata.superDebug), false, peer_id)
    elseif(command == "setting") then
        if(g_savedata.settings[arg[1]]==nil)then
            generatedString = ""
            for name, value in pairs(g_savedata.settings) do
                if(generatedString == "") then
                    generatedString = generatedString.. name
                else
                    generatedString = generatedString..", "..name
                end
            end
            printDebug("No setting with that name! Valid settings are: "..generatedString, false, peer_id)
            
        elseif arg[2] == nil then --Entered a valid setting name but didnt provide a value to set it to, return the settings current value
            printDebug('Current value for setting "'..arg[1]..'": '..g_savedata.settings[arg[1]], false, peer_id)
        else
            -- Convert the value to the correct type
            settingType = settingConversionData[arg[1]]
            if settingType == "bool" then
                arg[2] = arg[2].lower(arg[2])
                if arg[2] == "true" or arg[2] == "on" or arg[2] == "1" then
                    arg[2] = true
                elseif arg[2] == "false" or arg[2] == "off" or arg[2] == "0" then
                    arg[2] = false
                else
                    printDebug("Invalid value! Setting "..arg[1].." requires a boolean value (true/false)", false, peer_id)
                    return
                end
            else if settingType == "number" then
                arg[2] = tonumber(arg[2])
            end
            --Set the setting
            g_savedata.settings[arg[1]] = arg[2]
            printDebug('Updated setting "'..arg[1]..'" value to "'..arg[2]..'" successfully!', false, peer_id)
        end
    end
    elseif(command == "sample") then
        old = g_savedata.debug
        g_savedata.debug = true
        sampleWeather(server.getPlayerPos(peer_id))
        g_savedata.debug = old
    elseif(command == "panic") then
        storm = g_savedata.storm
        storm.active = false
        storm.stage = nil
        printDebug("Panic activated! Storm has been completly disabled, all normal wind down operations have not been called. Warning, this may cause bugs", false, -1)
    elseif(command == "vehicles") then
        for _, vehicle in pairs(g_savedata.playerVehicles) do
            printDebug("Vehicle ID: "..tostring(vehicle.id)..", Peer ID: "..tostring(vehicle.peer_id), false, peer_id)
        end

        if #g_savedata.playerVehicles == 0 then
            printDebug("No player vehicles found", false, peer_id)
        end
    elseif(command == "fail") then
        vehicle = tonumber(arg[1])
        length = tonumber(arg[2] or (60*time.second))*time.second
        for _, item in pairs(g_savedata.playerVehicles) do
            if item.id == vehicle then
                printDebug("Failing vehicle for "..tostring(length).." ticks!", false, peer_id)
                failVehiclePower(vehicle,length)
                return
            end
        end
        printDebug("Invalid vehicle id! ("..tostring(vehicle)..")", false, peer_id)
    elseif(command == "data") then
        if arg[1] ==  "true" then peer_id = -1 end
        printDebug("Data: "..stringFromTable(g_savedata), false, peer_id)        
    elseif(command == "validate") then
        for setting in pairs(g_savedata.settings) do
            printDebug("Validating... "..tostring(setting), false, peer_id)
            if g_savedata.settings[setting] == nil then
                print("Found issue with setting "..tostring(setting).."! Fixing...", false, peer_id)
                --Replace with its appropriate type
                correctType = settingConversionData[setting]
                if(correctType == "bool") then
                    printDebug("Defaulting to true", false, peer_id)
                    g_savedata.settings[setting] = true
                elseif(correctType == "number") then
                    printDebug("Defaulting to 0", false, peer_id)
                    g_savedata.settings[setting] = 0
                else
                    printDebug("Failed to fix! Invalid type!", false, peer_id)
                end
            end
        end
    elseif(command == "eventStart") then
        randomEvent = event.getRandomEvent(arg[1] or 0)
        if randomEvent ~= nil then
            printDebug("Spawning event!", false, peer_id)
            event.startEvent(randomEvent)
        else
            printDebug("All events in  use", false, peer_id)
        end
    elseif(command == "eventClean") then
        event.cleanEvents(true)
    elseif(command == "eventValidate") then
        event.validateEvents()
    else
        printDebug("Invalid command! Commands are: start, end, debug, setting\nAdvanced Debug Commands: superDebug, sample, panic, vehicles, fail, data", false, peer_id);
    end
end

--- Starts the storm
function startStorm()
    printDebug("(startStorm) called", true)
    season = server.getSeasonalEvent()
    if season == enum.SEASONAL_EVENTS.CHRISTMAS then
        server.notify(-1, "Broadcast", "A blizzard is on the horizon.", 4)
    elseif season == enum.SEASONAL_EVENTS.HALLOWEEN then
        server.notify(-1, "Broadcast", "Something is forming on the horizon...", 4)
    else
        server.notify(-1, "Broadcast", "A storm is on the horizon.", 4)
    end
    g_savedata.storm.active = true
    g_savedata.storm.stage = "windUp"
    g_savedata.storm["tweenStart"] = g_savedata.tick_counter
    server.setAudioMood(-1, 3) --Sets to high, naturally decreases over time (According to game)
    server.setGameSetting("override_weather", true)
    setupStartingConditions()
end

--- Ends the storm (if theres one active)
function endStorm()
    printDebug("(endStorm) called", true)
    if g_savedata.storm.active == false then return end
    season = server.getSeasonalEvent()
    if season == enum.SEASONAL_EVENTS.CHRISTMAS then
        server.notify(-1, "Broadcast", "The blizzard seems to be clearing.", 4)
    elseif season == enum.SEASONAL_EVENTS.HALLOWEEN then
        server.notify(-1, "Broadcast", "The storm seems to be clearing.", 4)
    else
        server.notify(-1, "Broadcast", "It seems to be clearing up...", 4)
    end
    storm = g_savedata.storm
    storm.stage = "windDown";
    g_savedata.storm["tweenStart"] = g_savedata.tick_counter
    ---End all current blackouts
    for _, failure in pairs(g_savedata.powerFailures) do
        failure.expire = g_savedata.tick_counter
    end

    setupStartingConditions()
    printDebug("event.cleanEvents type is "..type(event.cleanEvents), false, -1)
    printDebug(event.cleanEvents, false, -1)
    if event.cleanEvents then event.cleanEvents(true)
    else printDebug("WARNING: Failed to clean events! event.cleanEvents is nil", false, -1) end
end

--- Sets the starting conditions value
function setupStartingConditions()
    hostPos = server.getPlayerPos(0);
    weather = server.getWeather(hostPos)

    g_savedata.storm["startConditions"].fog = weather.fog
    g_savedata.storm["startConditions"].wind = weather.wind
    g_savedata.storm["startConditions"].rain = weather.rain
end

--- Fails a vehicles power temporary
--- @param length number The length in ticks to fail the vehicle for
function failVehiclePower(vehicle, length)
    length = length or (60*time.second)
    info = {
        vehicleID = vehicle,
        originalStates  = {},
        expire = g_savedata.tick_counter + length
    }
    vehicleData, is_success = server.getVehicleComponents(vehicle)
    if not is_success then
        printDebug("WARNING: Failed to get vehicle components for vehicle with id "..tostring(vehicle), true)
        return false
    end
    batteries = vehicleData.components.batteries

    for _, battery in pairs(batteries) do
        pos = battery.pos
        batteryData, success = server.getVehicleBattery(vehicle, pos.x, pos.y, pos.z)
        if success then 
            superDebug("(failVehiclePower) Saving battery data for battery with name "..tostring(battery.name))
            table.insert(info.originalStates, batteryData)
            server.setVehicleBattery(vehicle, pos.x, pos.y, pos.z, 0)
        else
            printDebug("WARNING: Failed to get battery data for battery with name "..tostring(battery.name).." on vehicle with id "..tostring(vehicle), true)
        end
    end
    table.insert(g_savedata.powerFailures, info)
    return true
end

--- Samples the weather
--- @param matrix SWMatrix The matrix/position of the sample point
--- @return SWWeather WeatherValue The weather at the specified point 
function sampleWeather(matrix)
    server.setGameSetting("override_weather", false)
    sample = server.getWeather(matrix)
    server.setGameSetting("override_weather", true)

    superDebug("Sampled weather:\nWind: ".. tostring(sample.wind).. "\nRain: ".. tostring(sample.rain).. "\nFog: ".. tostring(sample.fog), true, -1)
    return sample
end

--- Tweens a value, used by the storm windUp and windDown
--- @param startVal number The starting value
--- @param targetVal number the target value
--- @param position number the position of the tween in ticks
--- @param length number the total length of the tween
--- @return number newValue the value for the given position in the tween
function tween(startVal, targetVal, position, length)
    interpolationFactor = position / length;
    return startVal + (targetVal - startVal) * interpolationFactor;
end

--- @param percent number The percent chance that it will return true
--- @param seed number The seed to use for the random number generator
function randomChance(percent, seed)
    number = randomRange(0,99, seed)
    result = number < percent
    if result then superDebug("Random chance passed! "..tostring(number).." is less than "..tostring(percent)) end
    return result
end

--- Generates a random number between the given ranges
--- @param min number the min number
--- @param max number the max number
--- @return number randomNumber the random number generated
function randomRange(min, max, seed)
    --if seed then math.randomseed(server.getTimeMillisec(), seed or g_savedata.tick_counter) end
    return math.random(min, max)
end

--- Prints a message to the chat
--- @param message string The message to send
--- @param requiresDebug? boolean If false, the message will be sent even if debug isnt enabled
--- @param peer_id? integer Not required, for if you want to send it to a specific player
function printDebug(message, requiresDebug, peer_id)
    if requiresDebug == nil then requiresDebug = true end
    if((requiresDebug and g_savedata.debug) or requiresDebug == false) then
        if type(message) == "table" then
            message = stringFromTable(message)
        end
        server.announce("The Storm", message, peer_id or -1)
    end
end

function superDebug(message)
    if g_savedata.superDebug == true then
        printDebug(message, false, -1)
    end
end

---Checks if theres a seasonal event active
--- @param event integer the event you want to check
--- @return boolean isEvent if the event is the current event
function isEvent(event)
    return (server.getSeasonalEvent() == event) or g_savedata.settings.BYPASS_SEASONAL_EVENTS
end

--- Credit: Toastery (USE: Timing, Optimization)
--- @param id integer the tick you want to check that it is
--- @param rate integer the total amount of ticks, for example, a rate of 60 means it returns true once every second* (if the tps is not low)
--- @return boolean isTick if its the current tick that you requested
function isTickID(id, rate)
    return (g_savedata.tick_counter + id) % rate == 0
end




--- Credit: Toastery (USE: Distance checking)
---@param x1 number x coordinate of position 1
---@param x2 number x coordinate of position 2
---@param z1 number z coordinate of position 1
---@param z2 number z coordinate of position 2
---@param y1 number? y coordinate of position 1 (exclude for 2D distance, include for 3D distance)
---@param y2 number? y coordinate of position 2 (exclude for 2D distance, include for 3D distance)
---@return number distance the euclidean distance between position 1 and position 2
function euclideanDistance(...)
	local c = table.pack(...)

	local rx = c[1] - c[2]
	local rz = c[3] - c[4]

	if c.n == 4 then
		-- 2D distance
		return math.sqrt(rx*rx+rz*rz)
	end

	-- 3D distance
	local ry = c[5] - c[6]
	return math.sqrt(rx*rx+ry*ry+rz*rz)
end

--- Credit: Toastery (USE: Distance checking)
---@param matrix1 SWMatrix the first matrix
---@param matrix2 SWMatrix the second matrix
---@return number distance the xz distance between the two matrices
function distance(matrix1, matrix2) -- returns the euclidean distance between two matrixes, ignoring the y axis
	return euclideanDistance(matrix1[13], matrix2[13], matrix1[15], matrix2[15])
end

---@param x1 number x coordinate of position 1
---@param x2 number x coordinate of position 2
---@param z1 number z coordinate of position 1
---@param z2 number z coordinate of position 2
---@param y1 number? y coordinate of position 1 (exclude for 2D distance, include for 3D distance)
---@param y2 number? y coordinate of position 2 (exclude for 2D distance, include for 3D distance)
---@return number distance the euclidean distance between position 1 and position 2
function euclideanDistance(...)
	local c = table.pack(...)

	local rx = c[1] - c[2]
	local rz = c[3] - c[4]

	if c.n == 4 then
		-- 2D distance
		return math.sqrt(rx*rx+rz*rz)
	end

	-- 3D distance
	local ry = c[5] - c[6]
	return math.sqrt(rx*rx+ry*ry+rz*rz)
end

--- Credit: Toastery (USE: Debugging) (Helped me find the batterys-batteries typo that i debugged for an entire 2 hours)
--- Returns a string in a format that looks like how the table would be written.
---@param t table the table you want to turn into a string
---@return string str the table but in string form.
function stringFromTable(t)

	if type(t) ~= "table" then
		printDebug(("(string.fromTable) t is not a table! type of t: %s t: %s"):format(type(t), t), true, -1)
	end

	local function tableToString(T, S, ind)
		S = S or "{"
		ind = ind or "  "

		local table_length = #T
		local table_counter = 0

		for index, value in pairs(T) do

			table_counter = table_counter + 1
			if type(index) == "number" then
				S = ("%s\n%s[%s] = "):format(S, ind, tostring(index))
			elseif type(index) == "string" and tonumber(index) and isWhole(tonumber(index)) then
				S = ("%s\n%s\"%s\" = "):format(S, ind, index)
			else
				S = ("%s\n%s%s = "):format(S, ind, tostring(index))
			end

			if type(value) == "table" then
				S = ("%s{"):format(S)
				S = tableToString(value, S, ind.."  ")
			elseif type(value) == "string" then
				S = ("%s\"%s\""):format(S, tostring(value))
			else
				S = ("%s%s"):format(S, tostring(value))
			end

			S = ("%s%s"):format(S, table_counter == table_length and "" or ",")
		end

		S = ("%s\n%s}"):format(S, string.gsub(ind, "  ", "", 1))

		return S
	end

	return tableToString(t)
end

--- @return boolean is_whole returns true if x is whole, false if not, nil if x is nil
function isWhole(x) -- returns wether x is a whole number or not
	return math.type(x) == "integer"
end