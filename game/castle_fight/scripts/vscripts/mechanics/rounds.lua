function GameMode:SpawnCastles()
  local leftCastle = BuildingHelper:PlaceBuilding(nil, "castle", GameRules.leftCastlePosition, 2, 2, 0, DOTA_TEAM_GOODGUYS)
  local rightCastle = BuildingHelper:PlaceBuilding(nil, "castle", GameRules.rightCastlePosition, 2, 2, 0, DOTA_TEAM_BADGUYS)
end

function GameMode:SetupHeroes()
  for _,hero in pairs(HeroList:GetAllHeroes()) do
    if hero:IsAlive() then
      hero:ModifyGold(STARTING_GOLD - hero:GetGold(), false, 0)
      hero:SetLumber(STARTING_LUMBER)
      hero:SetCheese(STARTING_CHEESE)
      hero:AddNewModifier(hero, nil, "income_modifier", {duration=10})
      hero:RemoveModifierByName("modifier_stunned_custom")
      if not hero:HasItemInInventory("item_rescue_strike") then
        hero:AddItem(CreateItem("item_rescue_strike", hero, hero))
      end
    end
  end
end

function GameMode:SetupShops()
  GameMode:SetupShopForTeam(DOTA_TEAM_GOODGUYS)
  GameMode:SetupShopForTeam(DOTA_TEAM_BADGUYS)
end

function GameMode:InitializeRoundStats()
  GameRules.roundStartTime = GameRules:GetGameTime()
  GameRules.numPlayersBuilt = 0

  GameRules.unitsKilled = {}
  GameRules.buildingsBuilt = {}
  GameRules.numUnitsTrained = {}
  GameRules.rescueStrikeDamage = {}
  GameRules.rescueStrikeKills = {}

  for _,playerID in pairs(GameRules.playerIDs) do
    GameRules.unitsKilled[playerID] = 0
    GameRules.buildingsBuilt[playerID] = 0
    GameRules.numUnitsTrained[playerID] = 0
    GameRules.rescueStrikeDamage[playerID] = 0
    GameRules.rescueStrikeKills[playerID] = 0
  end

  GameMode:ResetIncome()
end

function GameMode:StartIncomeTimer()
  Timers:CreateTimer("IncomeTimer", {
    endTime = INCOME_TICK_RATE,
    callback = function()
      GameMode:PayIncome()
      return INCOME_TICK_RATE
    end
  })
end

function GameMode:StopIncomeTimer()
  Timers:RemoveTimer("IncomeTimer")
end

function GameMode:RandomHero(playerID)
  local heroes = {
    "npc_dota_hero_kunkka",
    "npc_dota_hero_slark",
    "npc_dota_hero_treant",
    "npc_dota_hero_vengefulspirit",
    "npc_dota_hero_abaddon",
    "npc_dota_hero_juggernaut",
    "npc_dota_hero_tusk",
    "npc_dota_hero_invoker",
  }

  -- Randomly select a hero from the pool
  local hero = GetRandomTableElement(heroes)

  PlayerResource:ReplaceHeroWith(playerID, hero, 0, 0)
end

function GameMode:StartHeroSelection()
  print("StartHeroSelection()")

  GameRules.InHeroSelection = true
  CustomNetTables:SetTableValue("hero_select", "status", {ongoing = true})

  GameRules.needToPick = 0
  for _,hero in pairs(HeroList:GetAllHeroes()) do
    if hero:IsAlive() then
      hero.hasPicked = false
      hero:AddNewModifier(hero, nil, "modifier_hide_hero", {})
    end
  end

  GameRules.needToPick = TableCount(GameRules.playerIDs)

  local timeToStart = HERO_SELECT_TIME
  -- Reset the timer if it's already going
  Timers:RemoveTimer(GameRules.HeroSelectionTimer)

  GameRules.HeroSelectionTimer = Timers:CreateTimer(function()
    CustomGameEventManager:Send_ServerToAllClients("countdown",
      {seconds = timeToStart})

    if timeToStart == 0 then
      --Hero Selection is over
      GameMode:EndHeroSelection()
    end

    timeToStart = timeToStart - 1

    return 1
  end)
end

function GameMode:EndHeroSelection()
  Timers:RemoveTimer(GameRules.HeroSelectionTimer)

  GameRules.InHeroSelection = false
  CustomNetTables:SetTableValue("hero_select", "status", {ongoing = false})
  -- Force players who haven't picked to random a hero
  for _,hero in pairs(HeroList:GetAllHeroes()) do
    if hero:IsAlive() and not hero.hasPicked then
      GameMode:RandomHero(hero:GetPlayerOwnerID())
    end
  end

  -- Wait for loading, then start the next round
  GameMode:WaitToLoad()
end

function GameMode:WaitToLoad()
  CustomGameEventManager:Send_ServerToAllClients("loading_started", {})

  Timers:RemoveTimer(GameRules.LoadingTimer)

  GameRules.LoadingTimer = Timers:CreateTimer(1, function()
    if GameRules.numToCache == 0 then
      -- Start the next round after we've finished precaching everything
      GameMode:StartRound()
      return
    end
    return 1
  end)
end

-- Kills all units and structures, including both castles. Does not kill heroes.
function GameMode:KillAllUnitsAndBuildings()
  local numSweeps = 5
  -- Kill everything multiple times, to make sure we get revivers
  Timers:CreateTimer(function()
    if numSweeps <= 0 then return end
    for _,unit in pairs(FindAllUnits()) do
      if not unit:IsHero() then
        unit:ForceKill(false)
      end
    end

    numSweeps = numSweeps - 1

    return 1/30
  end)
end

function GameMode:PlayEndRoundAnimations(winningTeam)
  for _,unit in pairs(FindAllUnits()) do
    if unit:GetTeam() == winningTeam then
      unit:StartGesture(ACT_DOTA_VICTORY)
    else
      unit:StartGesture(ACT_DOTA_DEFEAT)
    end
    unit:AddNewModifier(unit, nil, "modifier_end_round", {})
  end
end

--------------------------------------------------------
-- Start Round
--------------------------------------------------------
function GameMode:StartRound()
  -- Wait for precaching to finish before starting the round
  Timers:CreateTimer(function()
    if GameRules.numToCache > 0 then
      print("Loading...")
      return 1
    end

    print("Starting Round")
    GameMode:InitializeRoundStats()
    GameMode:SpawnCastles()
    GameMode:SetupHeroes()
    GameMode:SetupShops()
    GameMode:StartIncomeTimer()

    Notifications:TopToAll({text="Round " .. GameRules.roundCount .. " started!", duration=3.0})

    EmitGlobalSound("GameStart.RadiantAncient")

    CustomGameEventManager:Send_ServerToAllClients("round_started", 
      {round = GameRules.roundCount})

    GameRules.roundInProgress = true
  end)
end

--------------------------------------------------------
-- End Round
--------------------------------------------------------
function GameMode:EndRound(losingTeam)
  GameRules.roundInProgress = false

  -- Record the winner
  local winningTeam  
  local losingCastlePosition
  if losingTeam == DOTA_TEAM_BADGUYS then
    winningTeam = DOTA_TEAM_GOODGUYS
    GameRules.leftRoundsWon = GameRules.leftRoundsWon + 1
    losingCastlePosition = GameRules.rightCastlePosition
  else
    winningTeam = DOTA_TEAM_BADGUYS
    GameRules.rightRoundsWon = GameRules.rightRoundsWon + 1
    losingCastlePosition = GameRules.leftCastlePosition
  end

  AddFOWViewer(DOTA_TEAM_BADGUYS, losingCastlePosition, 1800, POST_ROUND_TIME, false)
  AddFOWViewer(DOTA_TEAM_GOODGUYS, losingCastlePosition, 1800, POST_ROUND_TIME, false)

  CustomNetTables:SetTableValue("round_score", "score", {
    left_score = GameRules.leftRoundsWon,
    right_score = GameRules.rightRoundsWon,
  })

  -- Send round info to the clients
  local roundDuration = GameRules:GetGameTime() - GameRules.roundStartTime

  GameRules.unitsKilled = {}
  GameRules.buildingsBuilt = {}
  GameRules.numUnitsTrained = {}
  GameRules.rescueStrikeDamage = {}
  GameRules.rescueStrikeKills = {}

  CustomGameEventManager:Send_ServerToAllClients("round_ended", {
    winningTeam = winningTeam,
    losingTeam = losingTeam,
    leftPoints = GameRules.leftRoundsWon,
    rightPoints = GameRules.rightRoundsWon,

    roundNumber = GameRules.roundCount,
    roundDuration = roundDuration,

    losingCastlePosition = losingCastlePosition,
  })

  GameRules.roundCount = GameRules.roundCount + 1

  -- Stop the income timer until the next round
  GameMode:StopIncomeTimer()

  -- Celebrate the end of the round
  GameMode:PlayEndRoundAnimations(winningTeam)

  -- Wait to start the next round
  Timers:RemoveTimer(GameRules.PostRoundTimer)

  GameRules.PostRoundTimer = Timers:CreateTimer(POST_ROUND_TIME, function()
    -- Clear the map
    GameMode:KillAllUnitsAndBuildings()

    if GameRules.leftRoundsWon >= POINTS_TO_WIN or GameRules.rightRoundsWon >= POINTS_TO_WIN then
      GameMode:EndGame(winningTeam)
    else
      -- Go into the next round preparation phase
      GameMode:StartHeroSelection()
    end
  end)

end

function GameMode:EndGame(team)
  if team == DOTA_TEAM_GOODGUYS then
    Notifications:TopToAll({text="Western Forces Victory!", duration=30})
  else
    Notifications:TopToAll({text="Eastern Forces Victory!", duration=30})
  end

  GameRules:SetGameWinner(team)
end