function GameMode:OnScriptReload()
  print("Script Reload")

  -- SpawnTestBuildings()
  -- SpawnRandomBuilding()
  -- KillEverything()
  -- GameMode:StartRound()
  -- GameMode:EndRound(DOTA_TEAM_BADGUYS)
  -- GiveLumberToAllPlayers(2000)
  -- KillAllUnits()
  -- KillAllBuildings()
  -- GameMode:StartHeroSelection()
  -- SendGameStatsToServer()
end

function SpawnTestBuildings()
  -- Only call this on the first script_reload
  if GameRules.SpawnTestBuildings then
    -- return
  else
    GameRules.SpawnTestBuilding = true
  end

  local humanBuildings = {
    "barracks",
    "stronghold",
    "sniper_nest",
    "gunners_hall",
    "marksmens_encampment",
    "weapon_lab",
    "gryphon_rock",
    "chapel",
    "church",
    "hjordhejmen",
    "gjallarhorn",
    "artillery",
    "watch_tower",
    "heroic_shrine",
  }

  for _,building in pairs(humanBuildings) do
    local randomPosition = RandomPositionBetweenBounds(GameRules.rightBaseMinBounds, GameRules.rightBaseMaxBounds)

    BuildingHelper:PlaceBuilding(nil, building, randomPosition, 2, 2, 0, DOTA_TEAM_BADGUYS)
  end

end

function SpawnRandomBuilding()
  local humanBuildings = {
    "barracks",
    "stronghold",
    "sniper_nest",
    "gunners_hall",
    "marksmens_encampment",
    "weapon_lab",
    "gryphon_rock",
    "chapel",
    "church",
    "hjordhejmen",
    "gjallarhorn",
    "artillery",
    "watch_tower",
    "heroic_shrine",
  }

  local building = GetRandomTableElement(humanBuildings)
  local randomPosition = RandomPositionBetweenBounds(GameRules.rightBaseMinBounds, GameRules.rightBaseMaxBounds)

  BuildingHelper:PlaceBuilding(nil, building, randomPosition, 2, 2, 0, DOTA_TEAM_BADGUYS)
end

function KillAllUnits()
  for _,unit in pairs(FindAllUnits()) do
    if not IsCustomBuilding(unit) and not unit:IsHero() then
      unit:ForceKill(false)
    end
  end
end

function KillAllBuildings()
  for _,unit in pairs(FindAllUnits()) do
    if IsCustomBuilding(unit) and unit:GetUnitName() ~= "castle" then
      unit:ForceKill(false)
    end
  end
end

function KillEverything()
  for _,unit in pairs(FindAllUnits()) do
    if not unit:IsHero() and unit:GetUnitName() ~= "castle" then
      unit:ForceKill(false)
    end
  end
end

function GiveLumberToAllPlayers(value)
  for _,hero in pairs(HeroList:GetAllHeroes()) do
    hero:GiveLumber(value)
  end
end

function GameMode:GreedIsGood(playerID, value)
  value = tonumber(value) or 500
  for _,hero in pairs(HeroList:GetAllHeroes()) do
    if hero:IsAlive() then
      hero:GiveLumber(value)
      hero:ModifyCustomGold(value)
      -- hero:ModifyGold(value, false, DOTA_ModifyGold_CheatCommand)
    end
  end
end

function GameMode:LumberCheat(playerID, value)
  PlayerResource:GetSelectedHeroEntity(playerID):GiveLumber(tonumber(value) or 10000)
end

function GameMode:SetLumberCheat(playerID, value)
  PlayerResource:GetSelectedHeroEntity(playerID):SetLumber(tonumber(value) or 10000)
end

function GameMode:SetCheeseCheat(playerID, value)
  PlayerResource:GetSelectedHeroEntity(playerID):SetCheese(tonumber(value) or 100)
end

function GameMode:SpawnUnits(playerID, unitname, count)
  local position = Vector(0,0,0)
  local team = PlayerResource:GetTeam(playerID)

  count = tonumber(count) or 1

  if count < 0 then
    count = count * -1
    team = GetOpposingTeam(team)
  end

  for i=1,count do
    CreateUnitByName(unitname, position, true, nil, nil, team)
  end
end

function GameMode:LandUnits(playerID, unitname, count)
  local castlePosition
  if PlayerResource:GetTeam(playerID) == DOTA_TEAM_GOODGUYS then
    castlePosition = GameRules.rightCastlePosition
  else
    castlePosition = GameRules.leftCastlePosition
  end

  local team = PlayerResource:GetTeam(playerID)
  count = tonumber(count) or 1
  if count < 0 then
    count = count * -1
    team = GetOpposingTeam(team)
  end

  for i=1,count do
    CreateUnitByName(unitname, castlePosition, true, nil, nil, team)
  end
end

function GameMode:EncounterUnits(playerID, unitname1, unitname2, count1, count2)
  if unitname1 == nil and unitname2 == nil then return end
  if unitname2 == nil then unitname2 = unitname1 end

  local position = Vector(0,0,0)
  count1 = tonumber(count1) or 1
  count2 = tonumber(count2) or 1
  if count1 < 0 then count1 = -count1 end
  if count2 < 0 then count2 = -count2 end
  local team = PlayerResource:GetTeam(playerID)

  for i=1,4 do
    KillEverything()
  end

  GameMode:RemoveFogOfWar(playerID)

  for i=1,count1 do
    print("spawning "..unitname1.." number " .. tostring(i))
    CreateUnitByName(unitname1, position, true, nil, nil, team)
  end
  for i=1,count2 do
    print("spawning "..unitname2.." number " .. tostring(i))
    CreateUnitByName(unitname2, position, true, nil, nil, GetOpposingTeam(team))
  end
end

function GameMode:GoldCheat(playerID, value)
  PlayerResource:GetSelectedHeroEntity(playerID):ModifyCustomGold(tonumber(value) or 10000)
end

function GameMode:RichCheat(playerID)
  GameMode:GoldCheat(playerID)
  GameMode:SetLumberCheat(playerID)
  GameMode:SetCheeseCheat(playerID)
end

function GameMode:RemoveFogOfWar(playerID)
  local team = PlayerResource:GetTeam(playerID)
  local r = 300000
  local duration = 60 * 10
  AddFOWViewer(team, Vector(0,0,0), r, duration, false)
  AddFOWViewer(team, GameRules.leftCastlePosition, r, duration, false)
  AddFOWViewer(team, GameRules.rightCastlePosition, r, duration, false)
end

function GameMode:Reset()
  GameRules.leftRoundsWon = 0
  GameRules.rightRoundsWon = 0
  GameRules.roundCount = 0
  GameMode:EndRound(DOTA_TEAM_NEUTRALS)
end


CHEAT_CODES = {
  ["lumber"] = function(...) GameMode:LumberCheat(...) end,                -- "Gives you X lumber"
  ["setlumber"] = function(...) GameMode:SetLumberCheat(...) end,          -- "Sets you X lumber"
  ["setcheese"] = function(...) GameMode:SetCheeseCheat(...) end,          -- "Sets your cheese to X"
  ["greedisgood"] = function(...) GameMode:GreedIsGood(...) end,           -- "Gives you X gold and lumber"
  ["killallunits"] = function(...) KillAllUnits() end,                     -- "Kills all units"
  ["killallbuildings"] = function(...) KillAllBuildings() end,             -- "Kills all buildings"
  ["reset"] = function(...) GameMode:Reset() end,                          -- "Restarts the round"
  ["nextround"] = function(...) GameMode:StartRound(...) end,              -- "Calls start round"
  ["endround"] = function(...) GameMode:EndRound(...) end,                 -- "Calls end round"
  ["spawn"] = function(...) GameMode:SpawnUnits(...) end,                  -- "Spawns some units."

  ["nofog"] = function(...) GameMode:RemoveFogOfWar(...) end,              -- "Removes fog of var
  ["clean"] = function(...) KillAllUnits() end,                            -- "Synonym for killallunits"
  ["cheese"] = function(...) GameMode:SetCheeseCheat(...) end,             -- "Synonym for setcheese"
  ["gold"] = function(...) GameMode:GoldCheat(...) end,                    -- "Sets your gold to X"
  ["vs"] = function(...) GameMode:EncounterUnits(...) end,                 -- "Cleans map, creates a fight in its middle"
  ["rich"] = function(...) GameMode:RichCheat(...) end,                    -- "Gives you 10000 gold and lumber, 100 cheese"
  ["land"] = function(...) GameMode:LandUnits(...) end,                    -- "Lands a number of units on enemy castle"
}

GAME_COMMANDS = {
  ["ff"] = function(...) GameMode:VoteGG(...) end,
  ["gg"] = function(...) GameMode:VoteGG(...) end,
}

function GameMode:OnPlayerChat(keys)
  local text = keys.text
  local userID = keys.userid
  local playerID = self.vUserIds[userID] and self.vUserIds[userID]:GetPlayerID()
  if not playerID then return end

  if StringStartsWith(text, "!") then
    text = string.sub(text, 2, string.len(text))
    local input = split(text)
    local command = input[1]
    if GAME_COMMANDS[command] then
      GAME_COMMANDS[command](playerID, input[2])
    end
  end

  -- Cheats are only available in the tools
  if not GameRules:IsCheatMode() then return end

  -- Handle '-command'
  if StringStartsWith(text, "-") then
    text = string.sub(text, 2, string.len(text))
  end

  local input = split(text)
  local command = input[1]
  if CHEAT_CODES[command] then
    CHEAT_CODES[command](playerID, input[2], input[3], input[4], input[5])
  end
end