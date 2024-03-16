-- Author: Justin Olsen
-- GitHub: https://github.com/Justin7654/sw_the_storm
-- Workshop: <WorkshopLink>
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

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