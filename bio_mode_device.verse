using { /Fortnite.com/Devices };
using { /Verse.org/Simulation };
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Fortnite.com/FortPlayerUtilities }

bio_mode_device := class(creative_device):

    var BioPlayers:[player]bio_player = map{};
    @editable RoundDevices:[]round_settings_device = array{}
    # TODO assign it
    @editable TeamClassSelectorZombie: class_and_team_selector_device = class_and_team_selector_device{}
    @editable TeamClassSelectorHuman: class_and_team_selector_device = class_and_team_selector_device{}

    @editable ZombiePropAsset: creative_prop_asset = DefaultCreativePropAsset
    @editable SignalMgrZombieAttack : signal_remote_manager_device = signal_remote_manager_device {}
    var IncrementalId : int = 0
    @editable HUDMsgDeviceChoosePlace:hud_message_device = hud_message_device{}
    @editable HUDMsgDeviceSelfTurnedZombie : hud_message_device = hud_message_device{}
    @editable HUDMsgDeviceHumanWin : hud_message_device = hud_message_device{}
    @editable HUDMsgDeviceZombieWin : hud_message_device = hud_message_device{}
    @editable HUDMsgDeviceProtectSelf : hud_message_device = hud_message_device{}
    @editable HUDMsgDeviceCountdown:hud_message_device = hud_message_device{}

    @editable SignalMgrDebug : signal_remote_manager_device = signal_remote_manager_device {}
    @editable var AvailablePreStuff: []zombie_pre_stuff = array{}

    @editable DebugButtonRespawn : button_device = button_device{}
    @editable DebugButtonEndRound : button_device = button_device{}

    EvAllInfected : event() = event(){}

    OnBegin<override>()<suspends>:void=
        AllPlayers := GetPlayspace().GetPlayers()
        for(Player : AllPlayers):
            PlayerSetupAtJoinGame(Player)
            # 20230926 加上这一句，这样在本device的onBegin前和OnBegin之后加入的玩家才能逻辑一致。
            OnPlayerSpawned(Player)
        GetPlayspace().PlayerAddedEvent().Subscribe(OnJoin)
        GetPlayspace().PlayerRemovedEvent().Subscribe(OnPlayerLeave)
        for:
            RoundDevice : RoundDevices
        do:
            RoundDevice.RoundBeginEvent.Subscribe(OnRoundStart)
        SignalMgrZombieAttack.PrimarySignalEvent.Subscribe(OnSignalPrimary)
        InitPlayerSpawners()
        SetUpDebugButtons()

    
    InitPlayerSpawners():void = 
        Spawners := GetCreativeObjectsWithTag(tagSpawner{})
        for (Obj: Spawners):
            if (Spawner := player_spawner_device[Obj]):
                Spawner.SpawnedEvent.Subscribe(OnPlayerSpawned)

    OnJoin(Player: player):void=
        Print("player joined...")
        PlayerSetupAtJoinGame(Player)

    PlayerSetupAtJoinGame(Player: player):void= {
        set IncrementalId += 1
        ProjectLog("Bio Player added in map, going to setup...")
        if:
            # assign zombie pre stuff to bio player
            FetchedZombieStuff := Self.AvailablePreStuff[0]
            set Self.AvailablePreStuff = Self.AvailablePreStuff.Remove[0,1]
            NewBioPlayer := bio_player{LinkedPlayer := Player, Manager:= Self, IncrementalId:= Self.IncrementalId, ZombiePreStuff:= FetchedZombieStuff}
            set BioPlayers[Player] = NewBioPlayer
            Fort := Player.GetFortCharacter[]
        then:
            ProjectLog("Bio Player setup succeeded, going to do init...")
            NewBioPlayer.Init()
        else:
            ProjectLog("No more zombie prop available(or get fort Character failed), should not happen!", ?Level:=log_level.Error)
    }

    OnPlayerLeave(Player: player):void=
        ProjectLog("Player left the game, check bioplayer then set inactive. can we still get the BioPlayers[Player] since Player could be invalid?")
        if:
            BioPlayer := BioPlayers[Player]
        then:
            # 退还pre stuff
            ProjectLog("get BioPlayers[Player] succeeded, and Bio Player set to inactive")
            set BioPlayer.IsActive = false
            ProjectLog("Returning zombie pre stuff to the pool")
            if:
                set AvailablePreStuff[AvailablePreStuff.Length] = BioPlayer.ZombiePreStuff
            then:
                ProjectLog("Returned to pool")
            else:
                ProjectLog("Failed to return to pool", ?Level:=log_level.Error)
            ProjectLog("remove bio player key value pair from map... ")
            var NewMap:[player]bio_player = map{}
            # Concatenate Keys from ExampleMap into NewMap, excluding ElementToRemove
            for (Key -> Value : BioPlayers, Key <> Player):
                set NewMap = ConcatenateMaps(NewMap, map{Key => Value})
            set BioPlayers = NewMap
            # TODO 后续应该还有退还计分装置的注册，之类的
        else:
            ProjectLog("when player leave, get BioPlayers[Player] failed, should not happen!", ?Level:=log_level.Error)

    # later refactored into bio_player.verse
    OnPlayerSpawned(Player: agent):void=
        ProjectLog("Player spawned, going to check if it's bio player...")
        # 如果是从人类原地变成僵尸，应该不会使用player spawn pad，也就不会触发on player spawned
        # 20231004 变僵尸的过程 team and class selector会改变血量，因此不需要respawn了
        if:
            BioPlayer := BioPlayers[Player]
        then:
            ProjectLog("Bio player found, going to check if it's zombie...")
            if:
                BioPlayer.IsZombie[]
            then:
                ProjectLog("Bio player is zombie, like zombie is shot and respawning")
                BioPlayer.TryTurnZombie()
            else:
                ProjectLog("Bio player is human, going to reset... but we have to check lifecycle, like respawn comes before setting faction...")
                BioPlayer.RoundReset()
        else:
            ProjectLog("Bio player not found, should not happen!", ?Level := log_level.Error)

    # 这样操作，比让每一个bio player去subscribe更好，性能更高
    OnRoundStart():void=
        ProjectLog("Round started, going to reset everyone...")
        for(BioPlayer : BioPlayers; BioPlayer.IsActive?):
            BioPlayer.RoundReset()
        spawn:
            PhaseLogicCoroutine()

    PhaseLogicCoroutine()<suspends>:void = 
        ProjectLog("Phase logic started...") 
        Sleep(0.0)
        ProjectLog("Phase preparation...")
        HUDMsgDeviceChoosePlace.Show()
        Sleep(14.0)
        Countdown(10)
        ProjectLog("Phase preparation finished, going to spawn zombies...")
        HUDMsgDeviceProtectSelf.Show()
        PlayerNum := Self.GetActiveBioPlayerCount()
        ZombieNum := PlayerNum * 0.2
        if:
            SupposedZombieNum := Ceil[ZombieNum]
        then:
            ProjectLog("There are {PlayerNum} players. Going to spawn {SupposedZombieNum} zombies...")
            var ExistingZombieNum : int = 0
            var InitialHumanPlayers : []player = array{}
            loop:
                ProjectLog("spawn zombie big loop starts one time...")
                for (Player-> BioPlayer:BioPlayers, BioPlayer.IsActive?,BioPlayer.IsHuman[], ExistingZombieNum < SupposedZombieNum):
                    DiceResult := GetRandomInt(1, PlayerNum)
                    if (DiceResult >= SupposedZombieNum):
                        # actual logic when turning zombie
                        BioPlayer.TryTurnZombie()
                        set ExistingZombieNum += 1
                        HUDMsgDeviceSelfTurnedZombie.Show(BioPlayer.LinkedPlayer)
                if:
                    ExistingZombieNum >= SupposedZombieNum
                then:
                    break
        for:
            Player -> BioPlayer: BioPlayers
            BioPlayer.IsActive?
            BioPlayer.IsHuman[]
        do:
            HUDMsgDeviceProtectSelf.Show(Player)
        race:
            block:
                Sleep(105.0)
                HUDMsgDeviceHumanWin.Show()
            block:
                EvAllInfected.Await()
                HUDMsgDeviceZombieWin.Show()
        if:
            RoundDevice := RoundDevices[0]
            Player0 := GetPlayspace().GetPlayers()[0]
        then:
            RoundDevice.EndRound(Player0)
            
    Countdown(seconds: int)<suspends>: void =
        for (i := seconds .. 1):
            HUDMsgDeviceCountdown.SetText(MakeMessageFromString( "in {i}"));
            HUDMsgDeviceCountdown.Show()
            Sleep(1.0)
        return

    OnFortEliminated(Res:elimination_result):void = 
        ProjectLog("Fort eliminated, going to check if it's bio player...")
        if:
            TargetFort := fort_character[Res.EliminatedCharacter]
            TargetAgent := TargetFort.GetAgent[]
            TargetPlayer := player[TargetAgent]
            TargetBioPlayer := BioPlayers[TargetPlayer]
        then:
            if:
                TargetBioPlayer.IsActive?
            then:
                ProjectLog("scoring...")
                # not return here, so to let eliminating logic run
            else:
                ProjectLog("Target player is not active, going to return")
                return
            
        else:
            ProjectLog("on fort eliminated, target bio player not found, going to return")
            return 
        var AllHumansInfected:logic = true
        for:
            Player -> OmgPlayer: BioPlayers
            OmgPlayer.IsHuman[]
        do:
            set AllHumansInfected = false
        if(AllHumansInfected?, RoundDevice := RoundDevices[0], Player0 := GetPlayspace().GetPlayers()[0]): 
            EvAllInfected.Signal()
    
    OnFortDamaged(DamageInfo: damage_result):void=
        ProjectLog("Fort damaged, going to check if it's bio player...")
        if:
            SourceFort := fort_character[DamageInfo.Source?]
            SourceAgent := SourceFort.GetAgent[]
            SourcePlayer := player[SourceAgent]
            SourceBioPlayer := BioPlayers[SourcePlayer]
            TargetFort := fort_character[DamageInfo.Target]
            TargetAgent := TargetFort.GetAgent[]
            TargetPlayer := player[TargetAgent]
            TargetBioPlayer := BioPlayers[TargetPlayer]
        then:
            if:
                not SourceBioPlayer.IsActive?
            then:
                ProjectLog("Source player is not active, going to return")
                return
        else:
            ProjectLog("on fort damaged, source/target bio player not found, going to return")
            return
        # TODO scoring
    
    OnSignalPrimary(Agent: agent):void = 
        ProjectLog("on signal primary, going to check if it's bio player...")
        if:
            Player := player[Agent]
            BioPlayer := BioPlayers[Player]
        then:
            if:
                not BioPlayer.IsActive?
            then:
                ProjectLog("Bio player is not active, going to return")
                return
            
            ProjectLog("Bio player is active, going to check if it's zombie...")
            if:
                BioPlayer.IsZombie[]
            then:
                ProjectLog("Bio player is zombie, going to attack...")
                BioPlayer.TryAttack()
            else:
                ProjectLog("Bio player is human, going to return")
                return

        else:
            ProjectLog("on signal primary, bio player not found, going to return")
            return
    
    GetActiveBioPlayerCount():int = {
        var Count :int= 0
        for(BioPlayer : BioPlayers):
            if:
                BioPlayer.IsActive?
            then:
                set Count = Count + 1
        return Count
    }

            
    SetUpDebugButtons():void = 
        DebugButtonRespawn.InteractedWithEvent.Subscribe(OnDebugButtonRespawn)
        DebugButtonEndRound.InteractedWithEvent.Subscribe(OnDebugButtonEndRound)

    OnDebugButtonRespawn(Agent: agent):void = 
        ProjectLog("Debug button respawn clicked")
        if:
            Player:= player[Agent]
            Fort:=Player.GetFortCharacter[]
        then:
            Transform := Fort.GetTransform()
            Player.Respawn(Transform.Translation, Transform.Rotation)

    OnDebugButtonEndRound(Agent: agent):void =
        ProjectLog("Debug button end round clicked")
        EvAllInfected.Signal()