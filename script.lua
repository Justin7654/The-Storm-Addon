---@diagnostic disable: undefined-doc-param
-- Author: Justin
-- GitHub: <GithubLink>
-- Workshop: <WorkshopLink>
time = { -- the time unit in ticks, irl time, not in game
	second = 60,
	minute = 3600,
	hour = 216000,
	day = 5184000
}

g_savedata = {
    tick_counter = 1,
    debug = false,
    cooldown = 0,
    settings = {
        HELL_MODE = property.checkbox("Hell Mode", false),  --Makes storms completly break the game but looks cool
        VOLCANOS = property.checkbox("Volcanos More Active During Storm", true),
        POWER_FAILURES = property.checkbox("Random temporary vehicle power failures", true),
        DYNAMIC_MUSIC = property.checkbox("Dynamic Music Mood", true), 
        COOLDOWN_TIME = property.slider("Cooldown (minutes)", 5, 60, 1, 30)*time.minute, --The cooldown between storms
        START_CHANCE = property.slider("Storm Chance Per minute (%)", 0, 100, 5, 10),  --The chance every 60s that a storm can start
        MIN_LENGTH = property.slider("Min storm length (minutes)", 5, 60, 5, 5)*time.minute, --Min length a storm can last
        MAX_LENGTH = property.slider("Max storm length (minutes)", 5, 60, 5, 15)*time.minute, -- Max length that a storm can last
        WIND_LENGTH = property.slider("Storm start/stop time (seconds)", 30, 240, 15, 120)*time.second, --Windown/Windup length for storms
        RAIN_AMOUNT = property.slider("Storm Rain Amount (%)", 50, 100, 10, 100)/100, --The peak rain intensity of a storm
        WIND_AMOUNT = property.slider("Storm Wind Amount (%)", 50, 150, 10, 120)/100, --The peak wind intensity of a storm
        FOG_AMOUNT = property.slider("Storm Fog Amount (%)", 50, 100, 10, 80)/100, --The peak fog intensity of a storm
        POWER_FAILURE_CHANCE = property.slider("Power Failure Chance (% every Second)", 0.5, 10, 0.5, 1), --The chance that a vehicle will fail during a storm
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
    powerFailures = {
        
    },
    playerVehicles = {

    },
    playerMoodStates = {

    } 
}


function onCreate(is_world_create)
    if g_savedata.settings.MIN_LENGTH > g_savedata.settings.MAX_LENGTH then g_savedata.settings.MIN_LENGTH = g_savedata.settings.MAX_LENGTH end
    if g_savedata.settings.VOLCANOS == nil then g_savedata.settings.VOLCANOS = true end

    --Check for events
    date = server.getDateValue()
end

function onTick(game_ticks)
    g_savedata.tick_counter = g_savedata.tick_counter + 1
    tickStorm()
    tickPowerFailures()
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
                    --printDebug("Failed random storm spawn, retrying in 1 minute.", true)
                end
            end

        else
            g_savedata.cooldown = g_savedata.cooldown - 1;
        end
    end

    --Do stuff with the storm based on stage
    if g_savedata.storm.active == false then return end
    if not isTickID(0,3) then return end

    settings = g_savedata.settings
    storm = g_savedata.storm
    stage = storm.stage

    if isTickID(0,60) then server.setGameSetting("override_weather", true) end

    if (stage == "windUp") then
        startValue = storm.windStart; --The start value
        tweenPosition = g_savedata.tick_counter - storm["tweenStart"]--The current position in the tween
        tweenTime = g_savedata.settings.WIND_LENGTH; --The time in ticks that the tween will last
        
        hostPos = server.getPlayerPos(0)
        currentWeather = sampleWeather(hostPos)--server.getWeather(hostPos); --Gets the weather at the hosts location

        fogValue = tween(currentWeather.fog, settings.FOG_AMOUNT, tweenPosition, tweenTime)
        windValue = tween(currentWeather.wind, settings.WIND_AMOUNT, tweenPosition, tweenTime)
        rainValue = tween(currentWeather.rain, settings.RAIN_AMOUNT, tweenPosition, tweenTime)


        printDebug("Tween Position: "..tostring(tweenPosition).."/"..tostring(g_savedata.settings.WIND_LENGTH), true)
        printDebug("Fog val: ".. tostring(fogValue), true)
        printDebug("Wind val: "..tostring(windValue), true)
        printDebug("Rain val: "..tostring(rainValue), true)

        server.setWeather(fogValue, rainValue, windValue)

        if(g_savedata.tick_counter>=(storm["tweenStart"]+g_savedata.settings.WIND_LENGTH))then
            --End tween
            storm.stage = "full"
            storm["endTime"] = g_savedata.tick_counter + randomRange(settings.MIN_LENGTH, settings.MAX_LENGTH)
            printDebug("Complete wind up. Storm will end at tick "..tostring(storm["endTime"]),true)
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
                        success = server.spawnVolcano(volcanoPos)
                    end

                    ::continue::
                end
            end
        end

        --Random vehicle power failures
        if g_savedata.settings.POWER_FAILURES then
            for _, vehicle in pairs(g_savedata.playerVehicles) do
                if randomRange(0,100)<tonumber(g_savedata.settings.POWER_FAILURE_CHANCE) then goto continue end
                if server.getVehicleSimulating(vehicle.id) == false then goto continue end
                --Check to see if its already failed
                for _, failure in pairs(g_savedata.powerFailures) do
                    if failure.vehicleID == vehicle.id then goto continue end
                end
                
                --Fail the vehicle
                length = randomRange(5,180)*time.second
                printDebug("Failing vehicle with id "..tostring(vehicle.id).." for "..tostring(length).." ticks", true)
                is_success = failVehiclePower(vehicle.id, length)

                ::continue::
            end
        end


    elseif (stage == "windDown") then
        startValue = storm.windStart; --The start value
        tweenPosition = g_savedata.tick_counter - storm["tweenStart"]--The current position in the tween
        tweenTime = g_savedata.settings.WIND_LENGTH; --The time in ticks that the tween will last
        
        hostPos = server.getPlayerPos(0);
        --currentWeather = server.getWeather(hostPos); --Gets the weather at the hosts location
        startWeather = g_savedata.storm["startConditions"]
        sample = sampleWeather(hostPos)
        endWeather = sampleWeather(hostPos)
        
        fogValue = tween(startWeather.fog, sample.fog, tweenPosition, tweenTime)
        windValue = tween(startWeather.wind, sample.wind, tweenPosition, tweenTime)
        rainValue = tween(startWeather.rain, sample.rain, tweenPosition, tweenTime)


        --printDebug("Tween Position: "..tostring(tweenPosition), true)
        printDebug("Tween Position: "..tostring(tweenPosition).."/"..tostring(g_savedata.settings.WIND_LENGTH), true)
        printDebug("Fog val: ".. tostring(fogValue), true)
        printDebug("Wind val: "..tostring(windValue), true)
        printDebug("Rain val: "..tostring(rainValue), true)

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

function tickPowerFailures()
    if not isTickID(0,5) then return end
    for i, failure in pairs(g_savedata.powerFailures) do
        if failure.expire <= g_savedata.tick_counter then
            printDebug("Recovered vehicle with id "..tostring(failure.vehicleID).." from power failure", true)
            for _, battery in pairs(failure.originalStates) do
                server.setVehicleBattery(failure.vehicleID, battery.pos.x, battery.pos.y, battery.pos.z , battery.charge)
            end
            table.remove(g_savedata.powerFailures, i)
        end
    end
end

--- Handles music mood, high music mood if not at in a shelter/owned tile during a storm and low mood if in a shelter/owned tile
function tickMusic()
    if not isTickID(0,30) or g_savedata.storm.active == false then return end
    if g_savedata.settings.DYNAMIC_MUSIC ~= true or g_savedata.settings.DYNAMIC_MUSIC ~= "true" then return end --Both string and bool to support command changing it
    
    shelterTag = "shelter" --The tag used to mark shelters
    for _, player in pairs(server.getPlayers()) do
        playerPos = server.getPlayerPos(player.id) 
        isOwned = server.getTilePurchased(playerPos)
        isShelter = server.isInZone(playerPos, shelterTag)
        if isOwned or isShelter then
            if g_savedata.playerMoodStates[player.id] ~= 1 then printDebug(player.name.." audio set to mood_high") end
            server.setAudioMood(player.id, 1)
            g_savedata.playerMoodStates[player.id] = 1
        else
            if g_savedata.playerMoodStates[player.id] ~= 3 then printDebug(player.name.." audio set to mood_low") end
            server.setAudioMood(player.id, 3)
            g_savedata.playerMoodStates[player.id] = 3
        end
    end   

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
    printDebug("Command Entered: "..full_message..". From peer ".. tostring(peer_id), false, -1)

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
            g_savedata.settings[arg[1]] = arg[2]
            printDebug('Updated setting "'..arg[1]..'" value to "'..arg[2]..'" successfully!', false, peer_id)
        end
    elseif(command == "sample") then
        sampleWeather(server.getPlayerPos(peer_id))
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
    elseif(command == "sudo") then
        name = arg[1]
        message = ""
        for i = 2, #arg do
            message = message..arg[i].." "
        end
        if name == nil or message == nil then
            printDebug("Invalid parameters! Usage: ?storm sudo <name> <message>", false, peer_id)
            return
        end
        server.announce(name, message, -1)
    else
        printDebug("Invalid command! Commands are: start, end, debug, setting\nAdvanced Debug Commands: sample, panic, vehicles, fail", false, peer_id);
    end
end

--- Starts the storm
function startStorm()
    printDebug("(startStorm) called", true)
    server.notify(-1, "Broadcast", "A storm is on the horizon.", 4)
    g_savedata.storm.active = true
    g_savedata.storm.stage = "windUp"
    g_savedata.storm["tweenStart"] = g_savedata.tick_counter
    server.setAudioMood(-1, 3) --Sets to high, naturally decreases over time (According to game)
    setupStartingConditions()
end

--- Ends the storm (if theres one active)
function endStorm()
    printDebug("(endStorm) called", true)
    if storm.active == false then return end
    server.notify(-1, "Broadcast", "The storm seems to be clearing.", 4)
    storm = g_savedata.storm
    storm.stage = "windDown";
    g_savedata.storm["tweenStart"] = g_savedata.tick_counter
    setupStartingConditions()
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
--- @param vehicle number The vehicle to fail
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

    printDebug("Sampled weather:\nWind: ".. tostring(sample.wind).. "\nRain: ".. tostring(sample.rain).. "\nFog: ".. tostring(sample.fog), true, -1)
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

--- Generates a random number between the given ranges
--- @param min number the min number
--- @param max number the max number
--- @return number randomNumber the random number generated
function randomRange(min, max)
    math.randomseed(server.getTimeMillisec())
    return math.random(math.floor(min), math.ceil(max))
end

--- Prints a message to the chat
--- @param message string The message to send
--- @param requiresDebug nil If false, the message will be sent even if debug isnt enabled
--- @param peer_id nil Not required, for if you want to send it to a specific player
function printDebug(message, requiresDebug, peer_id)
    if requiresDebug == nil then requiresDebug = true end
    if((requiresDebug and g_savedata.debug) or requiresDebug == false) then
        if type(message) == "table" then message = stringFromTable(message) end
        server.announce("The Storm", message, peer_id or -1)
    end
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