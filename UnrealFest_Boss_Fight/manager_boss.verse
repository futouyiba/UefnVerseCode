using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Fortnite.com/Game }
using { /UnrealEngine.com/Temporary/SpatialMath }

manager_boss := class(creative_device):
    @editable BossBP : creative_prop = creative_prop{}
    @editable MoveSpeed : float = 45.0

    @editable LightningAttack : attack_lightning = attack_lightning{}
    @editable BossManipulator : prop_manipulator_device = prop_manipulator_device{}

    # Cinematics
    @editable BossIntroCinema : cinematic_sequence_device = cinematic_sequence_device{}
    @editable IdleAnim : cinematic_sequence_device = cinematic_sequence_device{}
    @editable DashAnim : cinematic_sequence_device = cinematic_sequence_device{}
    @editable MeleeAttack1Anim : cinematic_sequence_device = cinematic_sequence_device{}
    @editable SkyAttack : cinematic_sequence_device = cinematic_sequence_device{}
    @editable DamageAnim : cinematic_sequence_device = cinematic_sequence_device{}
    @editable BossDeathAnim : cinematic_sequence_device = cinematic_sequence_device{}
    

    # Audio
    @editable AttackEffort : audio_player_device = audio_player_device{}
    @editable BossMusic : audio_player_device = audio_player_device{}

    BOSS_TOTAL_HP : float = 1000.0
    var BossCurrentHP<private> : float = 1000.0

    # This should be stored in a custom player and be adjustable
    PLAYER_DAMAGE : float = 10.0

    OnBegin<override>()<suspends>:void=
        BossManipulator.DamagedEvent.Subscribe(OnBossDamaged)

    StartBossFight()<suspends>:void=
        BossIntroCinema.PlayOneShot().Await()
        BossMusic.Play()

        # Show the bar for all players
        for (GP : GamePlayers()):
            spawn{GP.BossUI.Start()}

        
        # These can be adjusted to make the fight more difficult, easier, or 
        # for better gameplay
        loop:
            Sleep(0.3)
            StopLoopingAnims()
            StartMeleeAttack1()
            Sleep(0.5)
            StartSkyAttack()

    StartIdle()<suspends>:void=
        IdleAnim.Play()
        
    StartMeleeAttack1()<suspends>:void=
        StartLocation := BossBP.GetTransform().Translation
        # Find the nearest player
        Players := GetPlayspace().GetPlayers().ToPositionals()
        if (Target := BossBP.GetTransform().GetClosestPositional(Players)?):
            var TargetLocation : vector3 = Target.GetTransform().Translation
            # Rotate toward player before moving
            var NewRotation : rotation = BossBP.GetTransform().GetLookAtRotation(TargetLocation)
            BossBP.MoveTo(BossBP.GetTransform().Translation, NewRotation, 0.3)

            # Calculate how long it will take to move to the player using Miles Per Hour
            MoveDistance := DistanceXY(StartLocation, TargetLocation)
            DistanceCoveredPerSecond := 45.0 * MoveSpeed
            var MoveTime: float = MoveDistance / DistanceCoveredPerSecond

            if (MoveTime <= 0.0):
                set MoveTime = 1.0

            #Play the dash animation
            DashAnim.Play()
            BossBP.MoveTo(TargetLocation, NewRotation, MoveTime)
            DashAnim.Stop()
 
            
            #  Get target's latest position
            set TargetLocation = Target.GetTransform().Translation

            # One more quick rotation to face the player
            set NewRotation = BossBP.GetTransform().GetLookAtRotation(TargetLocation)
            BossBP.MoveTo(BossBP.GetTransform().Translation, NewRotation, 0.3)
            
            # Play attack
            AttackEffort.Play()
            MeleeAttack1Anim.PlayOneShot().Await()

     

    StartSkyAttack()<suspends>:void=
        spawn{LightningAttack.StartAttack(GetPlayspace().GetPlayers(), 45.0, 3.5, BossBP.GetTransform().Translation)}
        AttackEffort.Play()
        SkyAttack.PlayOneShot().Await()
            
    # Always remember to stop other animations when starting a new one
    # Or they will both play at the same time and you may get unexpected results
    StopLoopingAnims():void=
        IdleAnim.Stop()  
        DashAnim.Stop()

    # Update the progress bar for all players and/or end the game
    OnBossDamaged(Agent : agent):void=
        set BossCurrentHP -= PLAYER_DAMAGE
        if (BossCurrentHP <= 0.0) { OnBossDefeated()}
        else:
            HPPercent := (BossCurrentHP / BOSS_TOTAL_HP) * 100.0
            for (GP : GamePlayers()):
                GP.BossUI.UpdateProgressBar(HPPercent)
            DamageAnim.Play()
        
    OnBossDefeated():void=
        for (GP : GamePlayers()):
            GP.BossUI.Hide()
        BossDeathAnim.Play()
        #Decide what you want to do when the game ends
