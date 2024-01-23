using { /Verse.org/Simulation }
using { /Fortnite.com/Characters }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Fortnite.com/FortPlayerUtilities }
using { /Fortnite.com/Devices }

bio_player_type:= enum{
    none,
    human,
    zombie}

# 用于存储玩家的信息，包括玩家的阵营，是否是僵尸，是否是幽灵猎人等等
# should be created at the beginning of the game, and should not be destroyed until the game ends
# should be linked to a player
# when player quits the game, it's set to inactive, and will not be deleted
bio_player := class<unique>():
    LinkedPlayer : player
    Manager:bio_mode_device

    # TODO the zombie prop and vfx stuff... vfx could be unecessary
    var ZombieProp : creative_prop = creative_prop{}

    # set to false when player leaves the game, we are not deleting the object
    var IsActive : logic = true
    # 考虑不用这个了，直接使用classId的8位来判断
    var _CurFaction<private> :bio_player_type= bio_player_type.none 

    # 1为普通人类，9为普通僵尸，2为幽灵猎人，10为胖子僵尸。一局开始默认必为普通人类，因此初始值为1。僵尸模式没有无辜的路人,不能像瑞士一样中立
    var _ClassId<private>:int = 1

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
                ShowZombieAesthetic()
        else:
            ProjectLog("Try to turn zombie, but is already a zombie")
            return

    ShowZombieAesthetic():void = 
        Print("ShowZombieAesthetic...")
        ZombieProp.Show()
        # subscribe to events

    ClearZombieAesthetic():void = 
        ProjectLog("try clear Zombie aesthetic...")
        if:
            Self.IsHuman[]
        then:
            Print("QuitZombie... but is already human")
            return;
        # real logic begin...
        
        # TODO unsubscribe to events etc...
            

    RoundReset():void =
        spawn:
            RoundResetCoroutine()

    RoundResetCoroutine()<suspends>:void = 
        ProjectLog("RoundReset coroutine begin...")
        # let game handle respawn automatically
        Sleep(0.5)
        ProjectLog("RoundReset coroutine after sleep...")
        # LinkedPlayer.Respawn()
        SetClassId(classId:int = 1)
        if:
            Fort:= LinkedPlayer.GetFortCharacter[]
        then:
            Fort.Show()
        else:
            ProjectLog("RoundReset... but no fort character found")
            return

    