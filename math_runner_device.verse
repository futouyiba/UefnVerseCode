
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }

# See https://dev.epicgames.com/documentation/en-us/uefn/create-your-own-device-in-verse for how to create a verse device.

# A Verse-authored creative device that can be placed in a level
math_runner_device := class(creative_device):

    # asset to spawn for road props
    @editable
    RoadPropAsset : creative_prop_asset = DefaultCreativePropAsset;

    # 编辑器里先手动放置2个road prop，然后把这2个road prop的reference拖到这里。这两个可能很重要，它们定义了road的初始位置和方向、间隔多大。
    @editable
    RoadProp1: creative_prop = creative_prop{}
    @editable
    RoadProp2: creative_prop = creative_prop{}
    # 滚动生成+删除road prop，保持的road prop数量
    @editable
    NumKeepRoadProps: int = 5

    # 用来阻挡玩家的barrier prop。就是它推着玩家一直往前走
    @editable
    BarrierTreadmill:barrier_device = barrier_device{}

    # 测试用，从开始到第一次滚动的延迟
    @editable
    TreadmillMoveDelay: float = 10.0
    @editable
    TreadmillMoveSpeed: vector3 = vector3{ X:=0.0,Y:= 800.0,Z:= 0.0 }
    @editable
    TreadmillMoveDuration: float = 10000.0

    var RoadOrigin: vector3 = vector3{ X:=0.0,Y:= 0.0,Z:= 0.0 }
    var RoadRotation: rotation = rotation{}
    var RoadGap: vector3 = vector3{}
    var ArrRoads : []creative_prop = array{}

    TreadmillFailureEvent: event() = event(){}
    TreadmillSuccessEvent: event() = event(){}

    # Runs when the device is started in a running game
    OnBegin<override>()<suspends>:void=
        Print("Hello, math runner!")
        Print("starting to populate road props")
        loop:
            Sleep(1.0)
            PopulateOneRoadProp()
            if (ArrRoads.Length >= NumKeepRoadProps) then:
                break
        Print("finished populating road props")
        Print("for testing purpose, wait {TreadmillMoveDelay} seconds before starting to move the treadmill")
        Sleep(TreadmillMoveDelay);
        set RoadOrigin = RoadProp1.GetTransform().Translation
        set RoadRotation = RoadProp1.GetTransform().Rotation
        set RoadGap = RoadProp2.GetTransform().Translation - RoadProp1.GetTransform().Translation
        StartRollForward();
        
    GetCurTreadMillPos():vector3=
        return BarrierTreadmill.GetTransform().Translation

    StartRollForward()<suspends>:void = 
        race:
            block:
                BarrierTreadmill.MoveTo(BarrierTreadmill.GetTransform().Translation + TreadmillMoveSpeed*TreadmillMoveDuration, BarrierTreadmill.GetTransform().Rotation, TreadmillMoveDuration);
            loop:
                # generate new road block, eliminate old road block
                Sleep(RoadGap.Y/TreadmillMoveSpeed.Y);
                PopulateOneRoadProp()
                RemoveBehindRoadProp()
            block:
                TreadmillFailureEvent.Await();
            
    PopulateOneRoadProp():void =
        if(LastRoad := ArrRoads[ArrRoads.Length-1]) then:
            set RoadOrigin = LastRoad.GetTransform().Translation + RoadGap
            set RoadRotation = LastRoad.GetTransform().Rotation
        else:
            set RoadOrigin = RoadProp1.GetTransform().Translation
            set RoadRotation = RoadProp1.GetTransform().Rotation
        SpawnRslt := SpawnProp(RoadPropAsset, RoadOrigin, RoadRotation)
        if:
            Spawned := SpawnRslt(0)?
        then:
            set ArrRoads = ArrRoads + array{Spawned}

    RemoveBehindRoadProp():void =
        if:
            ArrRoads.Length > NumKeepRoadProps
            LeftBehind:=ArrRoads[0]
            set ArrRoads = ArrRoads.Slice[1, ArrRoads.Length-1]
        then:
            LeftBehind.Dispose()
