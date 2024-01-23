using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /Verse.org/Concurrency }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }

# Spawnable lightning attack that damages players in a radius
# Can drag and drop into any project

attack_lightning := class<concrete>():
    # The LightningAsset is a Blueprint with the "Building Prop" parent class
    # We put a Niagara VFX inside of it and when it is spawned the VFX automatically plays
    @editable LightningAsset: creative_prop_asset = DefaultCreativePropAsset

    # The audio player device is used to play the lightning sound
    @editable LightningAudio : audio_player_device = audio_player_device{}

    var Players<private> : []player = array{}
    var AttackDamage<private> : float = 10.0

    TOTAL_ATTACKS : int = 6
    ATTACK_RANGE : int = 1000
    BOLT_DAMAGE_RADIUS : float = 300.0

    StartAttack(AttackPlayers : []player, LightningAttackDamage : float, Delay : float, SourceLocation : vector3)<suspends>:void=
        Sleep(Delay)
        set Players = AttackPlayers
        set AttackDamage = LightningAttackDamage
        
        Points := GenerateRandomPointsInCircle(TOTAL_ATTACKS, SourceLocation, ATTACK_RANGE)
        spawn{PlayAudio(true, 1.0)}
        for (IDX := 0..Points.Length - 1):
            if (Point := Points[IDX]):
                spawn{SpawnAtPoint(Point)}
                Sleep(0.5)
        

    # Because we have more than one lightning attack, the audio is put into a Cue
    # And the bolts are timed there. If we increase TOTAL_ATTACKS here, we'll need to add those
    # Sounds to the Cue as well
    PlayAudio<private>(Start : logic, Delay : float)<suspends>:void=
        Sleep(Delay)
        if (Start?):
            LightningAudio.Play()
        else:
            LightningAudio.Stop()

    # Spawns the actual lightning Bolt Creative prop
    SpawnAtPoint<private>(Point: vector3)<suspends>:void=
        Prop := SpawnProp(LightningAsset, Point, IdentityRotation())

        DamagePlayersInRadius(Point)
        Sleep(3.0)
        if (P := Prop(0)?, P.IsValid[]):
            P.Dispose()

    # Checks the distance of current players, and if within damage radius
    # We apply damage to the player
    DamagePlayersInRadius<private>(Point: vector3):void=
        for (Player : Players, Fort := Player.GetFortCharacter[]):
            Loc := Fort.GetTransform().Translation
            Dis := DistanceXY(Point, Loc)
            if (Dis <= BOLT_DAMAGE_RADIUS):
                Fort.Damage(AttackDamage)
            else if (Dis <= BOLT_DAMAGE_RADIUS + (BOLT_DAMAGE_RADIUS * 0.2)):
                Fort.Damage(AttackDamage / 2.0)

    