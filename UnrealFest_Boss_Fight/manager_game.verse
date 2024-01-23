
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Fortnite.com/Characters }

game_player := struct:
    BossUI : ui_boss_bar

manager_game := class(creative_device):

    @editable BossManager : manager_boss = manager_boss{}
    @editable WeaponGranter : item_granter_device = item_granter_device{}

    OnBegin<override>()<suspends>:void=
        if (set GlobalData[GetSession()] = map{}){}

        GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerJoinedServer)

        # Initalize all existing players right away because some
        # Spawner spawned events may have already fired
        for (Player : GetPlayspace().GetPlayers()):
            InitPlayer(Player)

        # Decide when and how to start the game, Sleep here is just for testing
        Sleep(1.0)
        spawn{BossManager.StartBossFight()}

    
    # Every player must have a copy of the UI
    InitPlayer(Player : player):void=
        BossUI := ui_boss_bar{Player := Player}
        GamePlayer := game_player{BossUI := BossUI}
        if (Agent := agent[Player]) {WeaponGranter.GrantItem(Agent)}
        
        if (set GlobalData[GetSession()][Player] = GamePlayer) {}

    OnPlayerJoinedServer(PlayerEntering : player):void=
        InitPlayer(PlayerEntering)