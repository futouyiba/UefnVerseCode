
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }


trigger_pool := class(creative_device):
    _triggers:[]trigger_device = array{}



modifier := class:
    Trigger : trigger_device = trigger_device{}


# A Verse-authored creative device that can be placed in a level
math_treadmill_device := class(creative_device):
    # like an invisible dragger, or an invisible conveyor belt, for modifiers & enemy groups to attach to
    @editable
    invisible_mover:creative_prop = creative_prop{}

    # it should be a fixed position. create the modifier prop first at the position, and attach to the invisible mover after.
    # positioner is an empty prop that is used to editor placing. the transform is actually used.
    @editable
    positioner_modifier_left:creative_prop = creative_prop{}
    @editable
    positioner_modifier_right:creative_prop = creative_prop{}
    transform_modifier_left:transform = transform{}
    transform_modifier_right:transform = transform{}

    @editable
    positioner_enemy_group:creative_device = creative_device{}

    @editable
    object_to_move:creative_device = creative_device{}

    # Runs when the device is started in a running game
    OnBegin<override>()<suspends>:void=
        Print("Hello, math treadmill!")
        Print("wait for 5 seconds")
        Sleep(5.0)
        Print("5 seconds passed, going to move the object")