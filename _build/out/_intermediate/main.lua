
-- Author: Justin
-- GitHub: <GithubLink>
-- Workshop: <WorkshopLink>
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey
-- g_savedata table that persists between game sessions
test = "NO"

g_savedata = {
    cooldown = 0;
  }
  
  COOLDOWN_TIME = property.slider("Cooldown (minutes)", 5, 60, 1, 30)*60
  
  function start_storm()
  
  end
  
  function endStorm()
  
  end
  
  -- Tick function that will be executed every logic tick
  function onTick(game_ticks)
      if cooldown==0 then
        
      else
        cooldown = cooldown - 1;
      end
  end
  
  function onCustomCommand(full_message, user_peer_id, is_admin, is_auth, command, one, two, three, four, five)
  
      if (command == "?start_storm") then
          server.announce("[Server]", "world")
      elseif (command == "?end_storm") then
      
      end
  end