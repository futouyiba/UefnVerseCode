using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }

omg_player := class<unique>():
    
    var MaxHealth :float = 100.0;

    var MaxMana :float = 100.0;

    var CurrentHealth :float = 100.0;

    var Eliminated: logic = false
    @editable var VFXSpawner : vfx_spawner_device = vfx_spawner_device{}
    @editable var DamageDevice: damage_volume_device = damage_volume_device{}
    @editable var DeviceMover: creative_prop = creative_prop{}
    # @editable var SuperButton: button_device = button_device{}
    @editable var SFXPlayer:audio_player_device = audio_player_device{}

    Player:player;
    FortChar : fort_character
    # Parameters for `fort_character.PutInStasis` function.

    Setup():void = {
        Print("Setting up omg player...")
        # TODO create magic related devices
        # VFXSpawner = SpawnProp(Asset:creative_prop_asset, Position:vector3, Rotation:rotation)(vfx_spawner_device)

        # TODO subscribe to duck and jump, sprint events
        # FortChar.PutInStasis(stasis_args{AllowTurning:= false, AllowFalling:=true, AllowEmotes:=true })
        FortChar.SprintedEvent().Subscribe(OnSprinted)
        FortChar.JumpedEvent().Subscribe(OnJumped)
        FortChar.CrouchedEvent().Subscribe(OnCrouched)
        # set up timers to poll player states
        # show combo UI
        # take over damage handling
        spawn:
            PrintStateCoroutine()
    }

    PrintStateCoroutine()<suspends> :void = {
        loop:
            if (FortChar.IsActive[])
            then:
                var IsCrouching: logic = false
                Print("FortChar is active")
                if (FortChar.IsCrouching[]){ set IsCrouching = true;}

                if (FortChar.IsFalling[])
                then:
                    Print("FortChar is falling")
                else:
                    Print("FortChar is not falling")
                Print("is crouching: {IsCrouching.ToString()}")
            else:
                Print("FortChar is not active")
            Sleep(1.0)
    }

    OnSprinted(SprintChar:fort_character, OnOff:logic):void = {
        # TODO play sprint one-time vfx
        Print("Sprinted event triggered...")
        # TODO play sprint loop vfx

        Transform:= SprintChar.GetTransform
        Print("Sprint transform:")

    }

    OnJumped(JumpChar:fort_character):void = {
        # TODO play jump one-time vfx
        Print("Jumped event triggered...")
        # TODO play jump loop vfx
    }

    OnCrouched(CrouchChar:fort_character, OnOff:logic):void = {
        # TODO play crouch one-time vfx
        Print("Crouched event triggered...")
        # TODO play crouch loop vfx
    }

    Dispose():void = {
        # TODO clean all the omg vfx 
    }
        # set Eliminated := true
