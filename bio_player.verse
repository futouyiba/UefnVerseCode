using { /Verse.org/Simulation }
using { /Fortnite.com/Characters }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Fortnite.com/FortPlayerUtilities }
using { /Fortnite.com/Devices }
using { /UnrealEngine.com/Temporary/SpatialMath }

# 打算不用它。但是先不删，等待时机成熟
bio_player_type:= enum{ 
    none,
    human,
    zombie
    }

zombie_pre_stuff := class<concrete>:
    @editable ZombieProp:creative_prop = creative_prop{}
    @editable AudioDev : audio_player_device = audio_player_device{}
    @editable AttackDmgZone: damage_volume_device = damage_volume_device{}
    @editable CineDevice:cinematic_sequence_device = cinematic_sequence_device{}
    @editable CineDeviceRun: cinematic_sequence_device = cinematic_sequence_device{}
    @editable CineDeviceCrouch: cinematic_sequence_device = cinematic_sequence_device{}
    @editable CineDeviceJump: cinematic_sequence_device = cinematic_sequence_device{}
    @editable CineDeviceJumpLoop: cinematic_sequence_device = cinematic_sequence_device{}
    @editable CineDeviceJumpEnd: cinematic_sequence_device = cinematic_sequence_device{}
    @editable CineDeviceDeath: cinematic_sequence_device = cinematic_sequence_device{}
    @editable CineDeviceAttack: cinematic_sequence_device = cinematic_sequence_device{}

LiteralMoveStateIdle :string = "IDLE"
LiteralMoveStateRun : string = "RUN"
LiteralMoveStateCrouch : string = "CROUCH"
LiteralMoveStateJump : string = "JUMP"
LiteralMoveStateJumpLoop:string = "JUMP_LOOP"
LiteralMoveStateJumpEnd:string = "JUMP_END"

LiteralCombatStateMoveOrIdle : string = "MOVE_OR_IDLE"
LiteralCombatStateAttack : string = "ATTACK"
LiteralCombatStateDead : string = "DEAD"

combat_state:= enum{
    move_or_idle,
    attack,
    dead
}

move_state := enum{
    idle,
    run,
    crouch,
    jump,
    jump_loop,
    jump_end
}

# 用于存储玩家的信息，包括玩家的阵营，是否是僵尸，是否是幽灵猎人等等
# should be created at the beginning of the game, and should not be destroyed until the game ends
# should be linked to a player
# when player quits the game, it's set to inactive, and will not be deleted
bio_player := class<unique>():
    LinkedPlayer : player
    Manager:bio_mode_device
    ZombiePreStuff:zombie_pre_stuff
    IncrementalId : int
    # set to false when player leaves the game, we are not deleting the object
    var IsActive : logic = true
    # 考虑不用这个了，直接使用classId的8位来判断
    # var _CurFaction<private> :bio_player_type= bio_player_type.none 
    var CurMoveState:move_state = move_state.idle;
    var CurCombatState:combat_state = combat_state.move_or_idle;

    var AtkDmgZoneOffset:vector3 = vector3{X:=0.0, Y:=0.0, Z:=0.0}    
    var AtkDmgZoneSinkDepthWithoutAttack:vector3 = vector3{X:=0.0, Y:=0.0, Z:=-1000.0}

    #TODO 有一种特殊情况，在dead倒地的过程当中，回合重新开始了，则不能做respawn

    ZombieCutEvent:event() = event(){}  

    # Fires when player stops sprinting
    StopSprintingEvent: event() = event(){}
    StartSprintingEvent: event() = event(){}
    ZombieNormalAttackEvent: event() = event(){}
    ZombieSpecialAttackEvent: event() = event(){}
    StartCrouchEvent: event() = event(){}
    StopCrouchEvent: event() = event(){}
    JumpedEvent:event() = event(){} 
    JumpAnimFinishEvent:event() = event(){}
    JumpEndAnimFinishEvent:event() = event(){}
    AttackFinishEvent:event() = event(){}
    AirToGroundEvent:event() = event(){}
    
    # To be consumed by zombie FSMs
    EvRoundReset:event() = event(){}
    # 人被挠死了，马上要变成僵尸了。这时候应该做哪些处理？
    EvHumanDown:event() = event(){}
    EvZombieDown:event() = event(){} # should be signaled when zombie is down, and preparing to respawn

    WasJumpingLastSiml : logic = false

    # computed properties
    ZombieProp() : creative_prop = 
        return ZombiePreStuff.ZombieProp

    AudioDevice(): audio_player_device = 
        return ZombiePreStuff.AudioDev

    AttackDmgZone(): damage_volume_device =
        return ZombiePreStuff.AttackDmgZone
    
    CineDeviceIdle(): cinematic_sequence_device =   
        return ZombiePreStuff.CineDevice

    CineDeviceRun():cinematic_sequence_device = ZombiePreStuff.CineDeviceRun
    CineDeviceCrouch():cinematic_sequence_device = ZombiePreStuff.CineDeviceCrouch
    CineDeviceJump():cinematic_sequence_device = ZombiePreStuff.CineDeviceJump
    CineDeviceAttack():cinematic_sequence_device = ZombiePreStuff.CineDeviceAttack
    CineDeviceDeath():cinematic_sequence_device = ZombiePreStuff.CineDeviceDeath
    CineDeviceJumpLoop():cinematic_sequence_device = ZombiePreStuff.CineDeviceJumpLoop
    CineDeviceJumpEnd():cinematic_sequence_device = ZombiePreStuff.CineDeviceJumpEnd

    # 1为普通人类，9为普通僵尸，2为幽灵猎人，10为胖子僵尸。一局开始默认必为普通人类，因此初始值为1。僵尸模式没有无辜的路人,不能像瑞士一样中立
    var _ClassId<private>:int = 1
    var WasOnGround:logic = true

    Init():void =
        ProjectLog("Init... of bio player {IncrementalId}...")
        # conclusion: need not be subscribed again.   done: test whether this must be subscribed again after respawn 
        if. Fort:=LinkedPlayer.GetFortCharacter[]
        then:
            Fort.DamagedEvent().Subscribe(Manager.OnFortDamaged)
            Fort.EliminatedEvent().Subscribe(Manager.OnFortEliminated)
            Fort.SprintedEvent().Subscribe(OnSprintSwitch)
            Fort.CrouchedEvent().Subscribe(OnCrouchSwitch)
            Fort.JumpedEvent().Subscribe(OnJumped)
            DmgZone:=AttackDmgZone()
            DmgZoneTrsfm:=DmgZone.GetTransform()
            FortTransform := Fort.GetTransform()
            set AtkDmgZoneOffset = DmgZoneTrsfm.Translation - FortTransform.Translation
            DiveTranslation := DmgZoneTrsfm.Translation + AtkDmgZoneSinkDepthWithoutAttack
            # TODO 永远不在代码里做这个，但是后续为了攻击更加合理，就在cine seq里面做这样的调整
            # if. DmgZone.TeleportTo[DiveTranslation, DmgZoneTrsfm.Rotation]
            # then:
            #     ProjectLog("Init... of bio player {IncrementalId}... dmg zone teleported to {DiveTranslation.ToString()}...")
            # else:
            #     ProjectLog("Init... of bio player {IncrementalId}... dmg zone failed to teleport to {DiveTranslation.ToString()}...")
            # AtkDmgZoneOffset = AttackDmgZone().GetTransform().Translation - Fort.GetTransform().Translation
        Self.ZombieProp().Hide()
        AttackDmgZone().Disable()
        Self.CineDeviceAttack().StoppedEvent.Subscribe(OnAttackCineFinish)
        # NewBioPlayer.StartZombieUpdate()

    
    StartZombieUpdate():void = 
        UpdateTask:= spawn:
            ZombieUpdateCoroutine()

    <# 20230920 决定对update coroutine做一次重构。
    update循环本身应当一直存在。比如用来切换丧尸状态和人类状态
    （当然用event做会更清洁，更高效，也更满足强迫症。但update也可以选择，因为这点性能消耗完全可以忽略不计。我们直接在loop里if就好）
    但用event也有好处。
    可以在round reset时触发reset human的事件，turn zombie实际转变的时候触发另一个verse event。
    （丧尸倒地可能也需要一个事件？
    人类倒地需要一个事件吗）
    我们为什么需要在update coroutine当中做状态机的唤起？放在TryTurnZombie之类的地方不行吗？
            可能也行，使用spawn，每个状态都spawn后飘着，然后等待event就return，应该也是可以的。不过若是按照concurrency的文档建议，spawn对于lifespan的控制较差
            用loop来表达状态机，可读性强，直接互相spawn有点像“callback hell”。这一点已经有足够强的说服力了。
            结论：使用loop表达状态机，放在zombie update coroutine里。
    人类倒下变成丧尸，这个过程需要respawn吗？
            血量肯定需要更新
            位置不能变
            player的respawn也可能是直接移动过去，有类似的代码案例，用respawn来代替teleport
            所以其实我们需要的可能不是respawn，而是spawn？
            丧尸被杀死时，至少需要一次respawn来重置位置
            20230922: 肯定需要respawn。我想用游戏自带的health、damage、death事件，所以要把人类的血量一直干到0，触发eliminated.
    实验：
            respawn时是否会让玩家变回人形，在不手动干预的时候会不会显示出fort character？
                0921：得到结果，会显示fort，丧尸目前没消息，需要修改 TODO   20230921
            round end时，会触发respawn吗？会触发spawn吗？
                0921：会触发spawn。respawn不知道，没法日志
            实验方法，弄两个按钮，一个respawn，一个round end，然后查看log

    考虑让状态变成一系列的字符串，比枚举好多了。至少打log方便。
            
    我们想要实现的真实功能是：
            变丧尸了，有个respawn，在respawn之后立刻隐藏人物，并显示丧尸模型。然后开始丧尸的greater状态机、移动动画状态机。
            死亡后会： 1 设定class 2 respawn 3 respawn应当引起所有跟丧尸有关的逻辑停止运行
                丧尸的状态机应当在丧尸死亡后停止运行，丧尸死亡后，丧尸的动画状态机应当停止运行，丧尸的greater状态机应当停止运行
            也就是说，这些状态切换大量的由respawn


    设计A：
            roundreset后执行的是关闭
    #>
    ZombieUpdateCoroutine()<suspends>:void =
        sync:
            loop:
                # TODO handle spawned coroutine indefinitely running issue
                # if(not LinkedPlayer?) then. return
                if:
                    not IsActive?
                then:
                    ProjectLog("it's inactive, should be a leaving player, stop this coroutine")
                    return;
                    # the line above should quit whe whole coroutine, stopping other FSMs.
                if:
                    IsHuman[]
                then:
                    ProjectLog("Player {IncrementalId} is now human, stop zombie update coroutine...")
                    return;
                Sleep(0.0)
                if:
                    Fort := LinkedPlayer.GetFortCharacter[]
                    Transform := Fort.GetTransform()
                then:
                    ZombieProp().MoveTo(Transform.Translation, Transform.Rotation, 0.15)
                    # check landing and potentially trigger event
                    if:
                        (not WasOnGround?) and Fort.IsOnGround[]
                    then:
                        AirToGroundEvent.Signal()
                    if (Fort.IsOnGround[]):
                        set WasOnGround = true
                    else:
                        set WasOnGround = false
                else:
                    # ProjectLog("zombie prop {IncrementalId} tried to be updatedor does not have , skipped internal update for bio player", ?Level := log_level.Verbose)
            block:
                ProjectLog("starting greater fsm and anim fsm...")
                sync:
                    MoveFsmCoroutine()
                    CombatFsmCoroutine()

    # 用于判断是否是人类还是僵尸，1为人类，2为僵尸
    GetFaction()<transacts>:int = 
        if (_ClassId < 9):
            return 1
        else:
            return 2

    IsHuman()<decides><transacts>:void = 
        Faction := GetFaction()
        if (Faction < 2):
            return
        else:
            false?

    IsZombie()<decides><transacts>:void =
        Faction := GetFaction()
        if (Faction >= 2):
            return
        else:
            false?

    SetClassId(classId:int)<transacts>:void = 
        ProjectLog("SetClassId to {classId}...")
        if (classId < 1 or classId > 16):
            return
        if (_ClassId = classId):
            ProjectLog("SetClassId to {classId}... but already is {classId}")
            return
        set _ClassId = classId
        # do something else...

    TryTurnZombie():void = 
        ProjectLog("TurnZombie...")
        if:
            Self.IsHuman[]
        then:
            ProjectLog("setting class Id to 9")
            SetClassId(classId:int = 9)
            if:
                Fort:= LinkedPlayer.GetFortCharacter[]
            then:
                Fort.Hide()
                ShowZombieAndSubscribe()
                StartZombieUpdate()
        else:
            ProjectLog("Try to turn zombie, but is already a zombie")
            return

    ShowZombieAndSubscribe():void = 
        ProjectLog("ShowZombieAesthetic...")
        Manager.TeamClassSelectorZombie.ChangeClass(LinkedPlayer)
        ZombieProp().Show()
        # 可有可无
        AttackDmgZone().Disable()
        # # subscribe to events
        # if. Fort:=LinkedPlayer.GetFortCharacter[]
        # then:
        #     Fort.SprintedEvent().Subscribe(OnSprintSwitch)
        #     Fort.CrouchedEvent().Subscribe(OnCrouchSwitch)
        #     Fort.JumpedEvent().Subscribe(OnJumped)
        # else:
        #     ProjectLog("ShowZombie so trying to subscribe... but no fort character found")
        #     return
       
    HideZombieAndUnsubscribe():void =
        ProjectLog("HideZombieAesthetic...")
        Manager.TeamClassSelectorHuman.ChangeClass(LinkedPlayer)
        ZombieProp().Hide()
        AttackDmgZone().Disable()
        # unsubscribe to events
        # if. Fort:=LinkedPlayer.GetFortCharacter[]
        # then:
        #     # 20231003 there is no "unsubscribe" method
        #     # Fort.SprintedEvent().Unsubscribe(OnSprintSwitch)
        #     # Fort.CrouchedEvent().Unsubscribe(OnCrouchSwitch)
        #     # Fort.JumpedEvent().Unsubscribe(OnJumped)
        # else:
        #     ProjectLog("Unsubscribe... but no fort character found")
        #     return

    TryAttack():void =
        CineDeviceAttack().Play()
        ZombieNormalAttackEvent.Signal()
        spawn:
            AttackCoroutine()

    AttackCoroutine()<suspends>:void =
        ProjectLog("AttackCoroutine of {IncrementalId} starts...")
        AttackDmgZone().Enable()
        ZombieNormalAttackEvent.Await()
        AttackDmgZone().Disable()
        ProjectLog("AttackCoroutine of {IncrementalId} ends... dmg zone shuts down...")

    OnAttackCineFinish():void =
        ProjectLog("OnAttackCineFinish...")
        AttackFinishEvent.Signal()

    OnSprintSwitch(FortCharacter:fort_character, ToOn:logic):void =
        ProjectLog("player {IncrementalId} sprint switch to {ToOn.ToString()}...")
        if:
            ToOn?
        then:
            StartSprintingEvent.Signal()
        else:
            StopSprintingEvent.Signal()

    OnCrouchSwitch(FortCharacter:fort_character, ToOn:logic):void = 
        ProjectLog("player {IncrementalId} crouch switch to {ToOn.ToString()}...")
        if. ToOn?
        then. StartCrouchEvent.Signal()
        else. StopCrouchEvent.Signal()

    OnJumped(FortCharacter:fort_character):void = 
        ProjectLog("player {IncrementalId} jumped...")
        JumpedEvent.Signal()      

    RoundReset():void =
        ProjectLog("RoundReset...")
        HideZombieAndUnsubscribe()
        EvRoundReset.Signal()

    MoveFsmCoroutine()<suspends>:void =
        Sleep(0.0)
    #     ProjectLog("start move fsm coroutine...")
    #     loop:
    #         case(CurMoveState):
    #             move_state.idle=>
    #                 AnimStateIdle()
    #             move_state.run=>
    #                 AnimStateRun()
    #             move_state.crouch =>
    #                 AnimStateCrouch()
    #             move_state.jump =>
    #                 AnimStateJump()
    #             move_state.jump_loop =>
    #                 AnimStateJumpLoop()
    #             move_state.jump_end =>
    #                 AnimStateJumpEnd()
    #             _ => AnimStateIdle()
    #         ProjectLog("move fsm state executed one coroutine cycle...")
    #         Sleep(0.0)
    #         ProjectLog("move fsm sleep done... going to exec next cycle...")

    CombatFsmCoroutine()<suspends>:void = 
        Sleep(0.0)
    #     ProjectLog("startf greater fsm coroutine...")
    #     loop:
    #         case(CurCombatState):
    #             combat_state.move_or_idle =>
    #                 CombatStateMoveOrIdle()
    #             combat_state.attack =>
    #                 CombatStateAttack()
    #             combat_state.dead =>
    #                 CombatStateDead()
    #             _ => CombatStateMoveOrIdle()
    #         Sleep(0.0)

    #     # Winner := race:
    #     #     block:        # task 1
    #     #         AsyncFunction1()
    #     #         1
    #     #     block:        # task 2
    #     #         AsyncFunction2a()
    #     #         AsyncFunction2b()
    #     #         AsyncFunction2c()
    #     #         2
    #     #     loop:         # task 3
    #     #         # endless loop which could never win
    #     #         AsyncFunction3()
    #     #         3
    # TryStartMoveSeq(CinematicDevice: cinematic_sequence_device):void =
    #     ProjectLog("TryStartMoveSeq...")
    #     if:
    #         CurCombatState = greater_state.move_or_idle
    #     then:
    #         ProjectLog("in move or idle state, actually start cinematic sequence")
    #         CinematicDevice.Play()
    #     else:
    #         ProjectLog("not in move or idle state, do nothing about cinematic sequence")

    # TryEndMoveSeq(CinematicDevice: cinematic_sequence_device):void = 
    #     ProjectLog("TryEndMoveSeq...")
    #     if:
    #         CurCombatState = greater_state.move_or_idle
    #     then:
    #         ProjectLog("in move or idle state, actually stop cinematic sequence")
    #         CinematicDevice.Pause()
    #         # 下面这两行都是没用的，就因为测试的时候该停不停，所以才加上
    #         CinematicDevice.Stop()
    #         CinematicDevice.Play()
    #         CinematicDevice.Stop()
    #     else:
    #         ProjectLog("not in move or idle state, do nothing about cinematic sequence")

    # AnimStateIdle()<suspends>:void =
    #     # CineDeviceIdle().Play()
    #     ProjectLog("AnimStateIdle...")
    #     TryStartMoveSeq(CineDeviceIdle())
    #     race:
    #         block:
    #             StartCrouchEvent.Await()
    #             set CurMoveState = anim_state.crouch
    #         block:
    #             StartSprintingEvent.Await()
    #             set CurMoveState = anim_state.run
    #         block:
    #             JumpedEvent.Await()
    #             set CurMoveState = anim_state.jump
    #     # this line should happen as an "on exit" event
    #     ProjectLog("AnimStateIdle... exiting...")
    #     TryEndMoveSeq(CineDeviceIdle())

    # AnimStateRun()<suspends>:void = 
    #     ProjectLog("AnimStateRun...")
    #     # CineDeviceRun().Play()
    #     TryStartMoveSeq(CineDeviceRun())
    #     race:
    #         block:
    #             JumpedEvent.Await()
    #             set CurMoveState = move_state.jump
    #         block:
    #             StartCrouchEvent.Await()
    #             set CurMoveState = move_state.crouch
    #         block:
    #             StopSprintingEvent.Await()
    #             set CurMoveState = move_state.run
    #     ProjectLog("AnimStateRun... exiting...")
    #     TryEndMoveSeq(CineDeviceRun())

    # AnimStateCrouch()<suspends>:void =
    #     ProjectLog("AnimStateCrouch...")
    #     TryStartMoveSeq(CineDeviceCrouch())
    #     race:
    #         block:
    #             StartSprintingEvent.Await()
    #             set CurMoveState = move_state.run
    #         block:
    #             JumpedEvent.Await()
    #             set CurMoveState = move_state.jump
    #         block:
    #             StopCrouchEvent.Await()
    #             set CurMoveState = move_state.idle
    #     ProjectLog("AnimStateCrouch... exiting...")
    #     TryEndMoveSeq(CineDeviceCrouch())

    # AnimStateJump()<suspends>:void =
    #     ProjectLog("AnimStateJump...")
    #     TryStartMoveSeq(CineDeviceJump())
    #     race:
    #         loop:
    #             Sleep(0.0)
    #             if. CurCombatState<>LiteralCombatStateMoveOrIdle
    #             then:
    #                 ProjectLog("AnimStateJump... combat state is not or no longer move or idle, exiting...")
    #                 set CurMoveState = move_state.jump_loop
    #                 break
    #         block:
    #             JumpAnimFinishEvent.Await()
    #             set CurMoveState = move_state.jump_loop
    #     ProjectLog("AnimStateJump... exiting...")
    #     TryEndMoveSeq(CineDeviceJump())
            
    # AnimStateJumpLoop()<suspends>:void = 
    #     ProjectLog("Anim state jump loop...")
    #     TryStartMoveSeq(CineDeviceJumpLoop())
    #     race:
    #         loop:
    #             Sleep(0.0)
    #             if:
    #                 Fort:=LinkedPlayer.GetFortCharacter[]
    #                 Fort.IsOnGround[]
    #             then:
    #                 ProjectLog("AnimStateJumpLoop... player is on ground, exiting...")
    #                 set CurMoveState = move_state.jump_end
    #                 break
    #         block:
    #             JumpEndAnimFinishEvent.Await()
    #             set CurMoveState = move_state.jump_end
    #     ProjectLog("AnimStateJumpLoop... exiting...")
    #     TryEndMoveSeq(CineDeviceJumpLoop())


    # CombatStateMoveOrIdle()<suspends>:void = 
    #     ProjectLog("combat state move or idle, shall retrieve move state, and restart move fsm coroutine...")
    #     # 如果不终止之前的move state coroutine，重新运行一个coroutine，会出现的一个问题是存在两个coroutine，它们会导致乱序播放。
    #     # 20230926 这样终究还是太过复杂。因此jump start 和jump end这种状态，一个月内不要加了。
    #     # 即使处理了很多类似的东西，还有一个问题，jump start和jump end依赖于cine device的finish event。但move state这时候可能并未播放cine device，因此只要combat state不是move，就会立即退出此状态
        
