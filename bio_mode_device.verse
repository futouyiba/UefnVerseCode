using { /Fortnite.com/Devices };
using { /Verse.org/Simulation };
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }

bio_mode_device := class(creative_device):

    var BioPlayers:[player]bio_player = map{};
    @editable RoundDevice:round_settings_device = round_settings_device{}

    @editable ZombiePropAsset: creative_prop_asset = DefaultCreativePropAsset

    OnBegin<override>()<suspends>:void=
        AllPlayers := GetPlayspace().GetPlayers()
        for(Player : AllPlayers):
            PlayerSetup(Player)
        GetPlayspace().PlayerAddedEvent().Subscribe(OnJoin)
        GetPlayspace().PlayerRemovedEvent().Subscribe(OnLeave)
        RoundDevice.RoundBeginEvent.Subscribe(OnRoundStart)
        
    PlayerSetup(Player: player):void= {
        NewBioPlayer := bio_player{LinkedPlayer := Player, Manager:= Self}
        if:
            set BioPlayers[Player] = NewBioPlayer
            Fort := Player.GetFortCharacter[]
            Transform := Fort.GetTransform()
        then:
            ProjectLog("Bio Player added in map, going to setup...")
            NewZombieProp := SpawnProp(ZombiePropAsset, Transform.Translation, Transform.Rotation)
            # do damage logic here, not in bio player. so subscribe damaged event here...   
            Fort.DamagedEvent().Subscribe(OnFortDamaged)
    }

    OnJoin(Player: player):void=
        PlayerSetup(Player)

    OnLeave(Player: player):void=
        ProjectLog("Player left the game, check bioplayer then set inactive")
        if:
            BioPlayer := BioPlayers[Player]
        then:
            ProjectLog("Bio Player set to inactive")
            set BioPlayer.IsActive = false

    # 这样操作，比让每一个bio player去subscribe更好，性能更高
    OnRoundStart():void=
        ProjectLog("Round started, going to reset everyone...")
        for(BioPlayer : BioPlayers; BioPlayer.IsActive?):
            BioPlayer.RoundReset()

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
    