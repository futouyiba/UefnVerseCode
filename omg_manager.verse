using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Simulation/Tags }
using { /Verse.org/Random }
using { /Fortnite.com/Game }

# See https://dev.epicgames.com/documentation/en-us/uefn/create-your-own-device-in-verse for how to create a verse device.

tagSpawner := class(tag){}

# A Verse-authored creative device that can be placed in a level
omg_manager := class(creative_device):

    var OmgPlayers:[player]omg_player = map{}

    @editable IntoStasisButtons : []button_device = array{}
    @editable OutOfStasisButtons : []button_device = array{}

    # Runs when the device is started in a running game
    OnBegin<override>()<suspends>:void =
        Print("omg manager on begin!")
        Print("setting up stasis button events...")
        for (Button: IntoStasisButtons):
            Button.InteractedWithEvent.Subscribe(OnIntoStasisButtonPressed)
        for (Button: OutOfStasisButtons):
            Button.InteractedWithEvent.Subscribe(OnOutOfStasisButtonPressed)
        Print("setting up player events...")
        # GetPlayspace().PlayerRemovedEvent().Subscribe(OnPlayerRemoved)
        GetPlayspace().PlayerRemovedEvent().Subscribe(OnPlayerLeftServer)
        InitPlayerSpawners()

    OnIntoStasisButtonPressed(Agent: agent):void =
        Print("Into stasis button pressed!")
        if:
            Player := player[Agent],
            FortChar := Player.GetFortCharacter[]
        then:
            SpiderWeb(Player, 3.0)

    # 这个spider web一定是需要严谨化
    SpiderWeb(Player: agent, duration:float):void =
        Print("Spider web function start...")
        if:
            FortChar := Player.GetFortCharacter[]
        then:
            FortChar.PutInStasis(stasis_args{})
            spawn:
                OutStasisCoroutine(Player, duration)
    
    OutStasisCoroutine(Player: agent, duration:float)<suspends>:void =
        Print("Out of stasis coroutine start...")
        if:
            FortChar := Player.GetFortCharacter[]
        then:
            Sleep(duration)
            FortChar.ReleaseFromStasis()

    OnOutOfStasisButtonPressed(Player: agent):void =
        Print("Out of stasis button pressed!")
        if:
            FortChar := Player.GetFortCharacter[]
        then:
            FortChar.ReleaseFromStasis()

    OnPlayerLeftServer(PlayerLeaving: player):void = 
        if:
            OmgPlayer := OmgPlayers[PlayerLeaving]
        then:
            Print("Player left server, hp? {OmgPlayer.CurrentHealth} ")
            # remove the player from the map to reduce memory usage
            # first try immutable method
            var NewCustomPlayerMap:[player]omg_player = map{}
            for (Player -> storedOmgPlayer: OmgPlayers, Player <> PlayerLeaving):
                set NewCustomPlayerMap = ConcatenateMaps(NewCustomPlayerMap, map{Player => storedOmgPlayer})
            set OmgPlayers = NewCustomPlayerMap

    InitPlayerSpawners():void = 
        Spawners := GetCreativeObjectsWithTag(tagSpawner{})
        for (Obj: Spawners):
            if (Spawner := player_spawner_device[Obj]):
                Spawner.SpawnedEvent.Subscribe(OnPlayerSpawned)

    OnPlayerSpawned(Agent: agent):void ={
        Print("Player spawned! Check whether it's a respawn...")
        InitPlayer(Agent)}

    InitPlayer(Agent: agent):void =
        Print("init player triggered from spawn event")
        if:
            Player := player[Agent]
            Fort := Player.GetFortCharacter[]
        then:
            if(Existing := OmgPlayers[Player]) {}
            else:
                Fort.EliminatedEvent().Subscribe(OnPlayerEliminated)
                NewOmgPlayer := omg_player{Player:= Player, FortChar := Fort}
                # set OmgPlayers[Player] = omg_player{}
                NewOmgPlayer.Setup()

    OnPlayerEliminated(Result: elimination_result):void =
        if:
            Eliminator := Result.EliminatingCharacter?,
            Eliminatee := Result.EliminatedCharacter,
            TorAgent := Eliminator.GetAgent[],
            TeeAgent := Eliminatee.GetAgent[]
        then:
            # OmgPlayer.Eliminated := true