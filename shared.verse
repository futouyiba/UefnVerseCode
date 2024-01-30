# This file contains several classes and extension methods used in a Fortnite creative project.
# The classes include:
# - cage_swap_device: a device that handles all players joining a game.
# - shop_device: a device that handles a shop where players can purchase items.
# - shop_item: a class that represents an item in the shop.
# - shared_waiter: a generic class that can wait on multiple events and return the first event that occurs.
# - mutatorDevice: a device that freezes player actions while a cinematic sequence is playing.

# The extension methods include:
# - ToString: an extension method for the logic type that converts it to a string.
# - ToMessage: an extension method for the string type that converts it to a message.
# - MakeMessageFromString: a method that creates a message from a string.

# Each class and method is documented in more detail within its own code block.
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }
using { /Verse.org/Concurrency }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /Verse.org/Random }
using { /Fortnite.com/AI }
using { /Fortnite.com/FortPlayerUtilities }
using { /Verse.org/Simulation/Tags }

fort_callback := type {_(:fort_character):void}
# from youtube warforge live broadcast, put it within a class
# HotDogPickedUpEvent : fort_callback

# logger that can used in <transacts> and <decides> functions
my_log_channel<public> := class(log_channel):

tagSpawner := class(tag){}


# A project-wide "Logger" to print messages from functions that are not in a class with a log.
# The non-Logger Print is <no_rollback>, so it can't be used in a <transacts> function.
ProjectLog<public>(Message:[]char, ?Level:log_level = log_level.Normal)<transacts>:void=
    Logger := log{Channel := my_log_channel}
    Logger.Print(Message, ?Level := Level)

# Usage:
# ProjectLog("EndGame: Player has won!", ?Level := log_level.Verbose)

# You don't have to specify the Level
# ProjectLog("Hello Verse!")

# interesting about how to handle all players joining.
cage_swap_device := class(creative_device):
 
    OnBegin<override>()<suspends>:void=
        AllPlayers := GetPlayspace().GetPlayers()
        for(Player : AllPlayers):
            AgentSetup(Player)
        GetPlayspace().PlayerAddedEvent().Subscribe(OnJoin)
        
    AgentSetup(Agent: agent):void= {}

    OnJoin(Agent: agent):void=
        AgentSetup(Agent)
    
# extension methods 
(Value : logic).ToString<public>() : string =
    if (Value?):
        return "true"
    return "false"

# (Value: string).ToMessage<localizes>() : message = "{Value}"

(Translation:vector3).ToString<public>():string = 
    return "V3 ~ X: {Translation.X}, Y: {Translation.Y}, Z: {Translation.Z}"

(Rotation:rotation).ToString<public>():string = 
    return "Rot2V3: {Rotation.GetAxis()}"

(Transform:transform).ToString<public>():string = 
    return "Transform ~ Translation: {Transform.Translation.ToString()}, Rotation: {Transform.Rotation.ToString()}, Scale: {Transform.Scale.ToString()}"

MakeMessageFromString<localizes>(Text: string): message = "{Text}"

# Removes an element from the given map and returns a new map without that element
RemoveKeyFromMap(ExampleMap:[string]int, ElementToRemove:string):[string]int=
    var NewMap:[string]int = map{}
    # Concatenate Keys from ExampleMap into NewMap, excluding ElementToRemove
    for (Key -> Value : ExampleMap, Key <> ElementToRemove):
        set NewMap = ConcatenateMaps(NewMap, map{Key => Value})
    return NewMap

# Returns Number converted to a string, truncated to Decimals places.
ToTruncatedString<public>(Number:float, Decimals:int):[]char=
    var Str:[]char = ToString(Number)
    if:
        DotIndex := Str.Find['.']
        StopIndex := if (Decimals > 0) then Min(DotIndex+Decimals+1,Str.Length) else DotIndex
        Tmp := Str.Slice[0, StopIndex] 
        set Str = Tmp
    Str
    
# Device Configuration:
# 1.  Set the 'Cashier' Conditional Button Device's Key Item to use the currency type you want (Gold, etc).
# 2.  Set the HUD Message Device to 'Message Recipient:  Triggering Player'.
# 3.  Set the Button Device to the desired Interact Time.
# 4.  Add the Item being purchased to the Item List of the Item Granter.
shop_device := class(creative_device):

    @editable
    Cashier: conditional_button_device = conditional_button_device{}

    @editable
    HUDMessage: hud_message_device = hud_message_device{}

    @editable
    ShopItems: []shop_item = array{}
    
    MakeMessage<localizes>(Text: string): message = "{Text}"

    OnBegin<override>()<suspends>:void=
        ShopSetup()

    ShopSetup(): void =
        for (Item : ShopItems):
            Item.Init(Self)

    ShowHUDMessage(Agent: agent, Text: string): void =
        HUDMessage.SetText(MakeMessage(Text))
        HUDMessage.Show(Agent)

shop_item := class<concrete>():

    var VerseDevice: shop_device = shop_device{}

    @editable
    ItemName: string = "Item"

    @editable
    ItemCost: type{X: int where X >= 0} = 10

    @editable
    Button: button_device = button_device{}

    @editable
    ItemGranter: item_granter_device = item_granter_device{} 

    MakeMessage<localizes>(Text: string): message = "{Text}"

    Init(MainDevice: shop_device): void =
        set VerseDevice = MainDevice
        Button.InteractedWithEvent.Subscribe(PurchaseAttempt)
        if (ItemCost > 0):
            Button.SetInteractionText(MakeMessage("Purchase {ItemName}"))

        else:
            Button.SetInteractionText(MakeMessage("Pick Up {ItemName}"))

    PurchaseAttempt(Agent: agent): void =
        if (ItemCost > 0):
            PlayerGold := VerseDevice.Cashier.GetItemCount(Agent, 0)
            if (PlayerGold >= ItemCost):
                VerseDevice.Cashier.SetItemCountRequired(0, ItemCost)
                VerseDevice.Cashier.Activate(Agent)
                ItemGranter.GrantItem(Agent)
                VerseDevice.ShowHUDMessage(Agent, "Purchased {ItemName}.")

            else:
                VerseDevice.ShowHUDMessage(Agent, "Not enough resources.")

        else:
            ItemGranter.GrantItem(Agent)
            VerseDevice.ShowHUDMessage(Agent, "Obtained {ItemName}.")

# Generic class which you can set up to wait on multiple events
# and return the event that does occur and its payload.
# When you instantiate the class, you define the payload type you want. For example:
#     SharedWaiter:shared_waiter(int) = shared_waiter(int){}
shared_waiter<public>(payload:type) := class(awaitable(payload)):
    # Single custom event to wait and signal on
    SharedEvent<internal>:event(payload) = event(payload){}
        
    # Wait on the custom shared event. Result is the associated payload.
    Await<override>()<suspends>:payload=
        SharedEvent.Await()

    # Add the event to wait on and the payload associated with the event if it occurs
    AddAwaitable<public>(Awaitable:awaitable(t), Payload:payload where t:type):void=
        spawn{AwaitFirstSignal(Awaitable, Payload)}
    
    # Race between the multiple events. First event to occur signals the shared event
    # and cancels the wait for any remaining events that are still waiting to occur.
    AwaitFirstSignal<internal>(Awaitable:awaitable(t), Payload:payload where t:type)<suspends>:void=
        race:
            SharedEvent.Await()
            block:
                Awaitable.Await()
                SharedEvent.Signal(Payload)


# 在播sequencer时冻结玩家操作
mutatorDevice := class(creative_device):

    @editable SequencerDevice:cinematic_sequence_device = cinematic_sequence_device{}

    PlaySequence()<suspends>:void=
        # Put every player in stasis
        for (Player : GetPlayspace().GetPlayers()):
            if (Character := Player.GetFortCharacter[]):
                Character.PutInStasis(stasis_args{})

        # Play the sequence
        SequencerDevice.Play()

        # Wait for the sequence to end
        SequencerDevice.StoppedEvent.Await()

        # Release every player from stasis
        for (Player : GetPlayspace().GetPlayers()):
            if (Character := Player.GetFortCharacter[]):
                Character.ReleaseFromStasis()


queue<public>(t:type) := class:
    Elements<internal>:[]t = array{}

    Enqueue<public>(NewElement:t):queue(t)=
        queue(t){Elements := Elements + array{NewElement}}
    
    Dequeue<public>()<decides><transacts>:tuple(queue(t),t)=
        FirstElement := Front[]
        (queue(t){Elements := Elements.RemoveElement[0]}, FirstElement)

    Size<public>()<transacts>:int=
        Elements.Length
    
    IsEmpty<public>()<decides><transacts>:void=
        Size() = 0
    
    Front<public>()<decides><transacts>:t=
        Elements[0]
    
    Rear<public>()<decides><transacts>:t=
        Elements[Elements.Length - 1]
        
CreateQueue<public><constructor>(InitialElements:[]t where t:type) := queue(t):
    Elements := InitialElements

# This snippet sends a guard to a prop and then keeps the prop near the guard as they move to their next destination, creating the appearance that the guard has picked up and moved the prop.
guard_prop_carry := class(creative_device):
 
    # A reference to the Guard Spawner device. This must be set in the Details panel of this Verse device before starting the game.
    @editable
    GuardSpawner:guard_spawner_device = guard_spawner_device{}
 
    # A reference to prop that will spawn when the game starts. This must be set in the Details panel of Verse device before starting the game.
    @editable
    Loot:creative_prop_asset = DefaultCreativePropAsset
 
    # A reference to the guard that will spawn when the game starts
    var MaybeGuardFollower:?agent = false
 
    # A reference to the result of calling SpawnProp()
    # The ?creative_prop value needs to be false so we can check if the prop did spawn.
    # The spawn_prop_result will be overwritten so it can be set to anything.
    var PropResult:tuple(?creative_prop, spawn_prop_result) = (false, spawn_prop_result.Ok)
 
    # Runs when the device is started in a running game
    OnBegin<override>()<suspends>:void=
        
        # Spawn the prop to be navigated to
        # This location was chosen at random
        set PropResult = SpawnProp(Loot, vector3{X := 832.000000,Y := 1168.000000, Z := 0.000000}, rotation{})
 
        # Await the Guard Spawner SpawnedEvent
        GuardAgent := GuardSpawner.SpawnedEvent.Await()
        # OnGuardSpawned(GuardAgent)
        
        # Short Sleep to ensure you can see the guard start the navigation.
        # This is not required for the code to function.
        Sleep(2.0)
 
        # Create a Task so we know when NavigateToProp completes
        NavigateTask := spawn{NavigateToProp()}
        # Await NavigateToProp completion
        NavigateTask.Await()
        # When we know the guard has reached the prop, make the prop follow the guard
        AttachPropToGuard()
 
    # Send guard to a location near the prop
    NavigateToProp()<suspends>:void=
        if:
            GuardFollower := MaybeGuardFollower?
            Prop := PropResult(0)?
            FollowerNav := GuardFollower.GetFortCharacter[].GetNavigatable[]
        then:
            Print("GuardFollower navigating to prop")
            PropLocation := Prop.GetTransform().Translation
            # Here we use a random offset distance from the prop so the guard does not jump on top of the prop or try to destroy it
            RandomOffsetFromProp := vector3{X:=PropLocation.X + GetRandomFloat(-200.0, 200.0), Y:= PropLocation.Y + GetRandomFloat(-200.0, 200.0), Z:= PropLocation.Z}
            NavigationTarget := MakeNavigationTarget(RandomOffsetFromProp)
            FollowerNav.NavigateTo(NavigationTarget)
 
    # Make the prop "follow" the guard by looping a call to MoveTo that moves the prop to the guard's Transform
    AttachPropToGuard()<suspends>:void=
        if:
            Prop := PropResult(0)?
            GuardFollower := MaybeGuardFollower?
            GuardFortCharacter := GuardFollower.GetFortCharacter[]
        then:
            loop:
                Prop.MoveTo(GuardFortCharacter.GetTransform(), 1.0)

# 注意index的使用，这里的index是从0开始的，所接的符号不是:, but :=
ForLoopWithIndex():void = 
    Arr := array{1, 2.0, "a"}
    for (Index := 0..Arr.Length-1):
        if(Value := Arr[Index]) {Print("Index: {Index}, Value: unknown type so skip to string...")}


StandStillEvents := module:
    # Copyright (c) 2023 Rift9
# Licensed under the MIT License. See https://opensource.org/licenses/MIT for details.

using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/SpatialMath }


# This maximum amount of distance travelled between an update which will trigger a stand still event
StandStillMovePerSecondThreshold: float = 0.01

# Update 3 times per second, enough to detect standing still
PlayerStandStillUpdateFrequency: float = 0.333


# This data struct contains everything needed for tracking a given player
player_standstill_tracker := class():

    # Keep a reference to the agent of this player
    Agent: agent

    # Keep a reference to the agent of this player
    Character: fort_character

    # Fires when player stands still
    StandStillEvent: event() = event(){}

    # Fires when player stops standing still
    StopStandingStillEvent: event() = event(){}

    # Player transform this simulation update
    var CurrentTranslation: vector3 = vector3{}

    # Toggles when player stand-stills are detected
    var PlayerIsStandingStill<private>: logic = true


    Update(ElapsedSeconds: float): void =

        # No divide by Zeros allowed
        if. ElapsedSeconds.IsAlmostZero[0.000001] then. return

        PlayerTransform := Character.GetTransform()
        PlayerMoveDistanceSquared := DistanceSquared(CurrentTranslation, PlayerTransform.Translation)

        # Set new data in the map
        set CurrentTranslation = PlayerTransform.Translation
        MovementPerSecond := PlayerMoveDistanceSquared / Pow(ElapsedSeconds, 2.0)
        
        # Check for stand still event
        if. PlayerIsStandingStill = false and MovementPerSecond < Pow(StandStillMovePerSecondThreshold, 2.0)
        then:
            set PlayerIsStandingStill = true
            StandStillEvent.Signal()

        # Else check for start move again event
        else if. PlayerIsStandingStill = true and MovementPerSecond > Pow(StandStillMovePerSecondThreshold, 2.0)
        then:
            set PlayerIsStandingStill = false
            StopStandingStillEvent.Signal()


    
    # Get tracking data for a given agent
    IsStandingStill()<transacts><decides>: void =
        
        PlayerIsStandingStill = true


# Create a logging class to get more options for `Print` and a channel name automatically added to the log
standstill_tracking_device_log<internal> := class(log_channel){}


# This class handles iterating all players in the game and tracking properties
# Keeping this tracking centralized prevents multiple devices doing iteratiosn over player list
standstill_tracking_device := class(creative_device):

    Logger<private> : log = log{Channel:=standstill_tracking_device_log}   

    # A map of player data used for tracking values between simulation updates
    var Players<private>: [agent]player_standstill_tracker = map{}

    var TimeLastUpdate<private>: float = 0.0

    OnBegin<override>()<suspends>: void =

        set TimeLastUpdate = GetSimulationElapsedTime()
        
        # Use playspace to find players
        Playspace := GetPlayspace()
        PlayspacePlayers := Playspace.GetPlayers()

        # Initialize existing players
        for:
            Player : PlayspacePlayers
            FortCharacter := Player.GetFortCharacter[]
            PlayerAgent := FortCharacter.GetAgent[]

        do. InitAgent(PlayerAgent)

        # Subscribe to future players leaving and joining
        Playspace.PlayerAddedEvent().Subscribe(HandlePlayerAdded)
        Playspace.PlayerRemovedEvent().Subscribe(HandlePlayerRemoved)

        # Loops indefinitely
        loop:
            # We need to calculate time adjusted move amount
            ElapsedSeconds := GetSimulationElapsedTime() - TimeLastUpdate
            set TimeLastUpdate = GetSimulationElapsedTime()

            # Keep track of all player translations 
            for. PlayerData : Players do. PlayerData.Update(ElapsedSeconds)

            # No syncronous infinite loop!
            Sleep(PlayerStandStillUpdateFrequency)


    # Get tracking data for a given agent
    GetAgentTrackingData(Agent: agent)<transacts><decides>: player_standstill_tracker =
        
        Players[Agent]


    # Playspace event
    HandlePlayerAdded<private>(Player : player) : void =

        if. PlayerAgent := Player.GetFortCharacter[].GetAgent[]
        then. InitAgent(PlayerAgent)


    # Playspace event
    HandlePlayerRemoved<private>(Player : player) : void =

        if. PlayerAgent := Player.GetFortCharacter[].GetAgent[]
        then. ClearAgent(PlayerAgent)
        

    # Create player data
    InitAgent<private>(Agent: agent): void =

        if:
            Player := player[Agent]
            PlayerCharacter := Player.GetFortCharacter[]
            PlayerTransform := PlayerCharacter.GetTransform()
            set Players[Agent] = player_standstill_tracker{
                Agent:=Agent
                Character:=PlayerCharacter
                CurrentTranslation:=PlayerTransform.Translation
            }

        else. Logger.Print("Error intializing player data", ?Level:=log_level.Error)

    
    # Remove player data
    ClearAgent<private>(Agent: agent): void =

        set Players = RemoveAgentFromMap(Players, Agent)        
            

    # Map edit function. Would be nice if it was generic
    RemoveAgentFromMap<private>(Map:[agent]player_standstill_tracker, ElementToRemove: agent): [agent]player_standstill_tracker =

        var NewMap: [agent]player_standstill_tracker = map{}

        for:
            Key -> Value : Map
            Key <> ElementToRemove
        do. set NewMap = ConcatenateMaps(NewMap, map{Key => Value})

        return NewMap
BasicRadioRepeater := module:
    using { /Fortnite.com/Devices }
    using { /Verse.org/Simulation }
    using { /Verse.org/Random }

    # radio repeater requires more than one radio device to work
    # set device for four second intro/outro or update setting
    # stock code plays radio for three minutes per track

    radio_repeater := class(creative_device):
        var Index:int = 0
        @editable
        FadeTime:float = 4.0
        @editable
        TrackTime:float = 180.0
        @editable
        Radios:[]radio_device = array{}
        OnBegin<override>()<suspends>:void=
            if( Radios.Length > 0 ):
                loop:
                    if:
                        PrevRadio := Radios[ Index ]
                    then:
                        set Index = GetRandomInt( 0 , Radios.Length - 1 )
                        if( NextRadio := Radios[ Index ] ):
                            PrevRadio.Stop()
                            Sleep( FadeTime )
                            NextRadio.Play()
                            Sleep( TrackTime )

UiDialogModule := module:
    using { /Fortnite.com/Devices }                 
    using { /Fortnite.com/UI }
    using { /Verse.org/Simulation }
    using { /Verse.org/Verse}
    using { /UnrealEngine.com/Temporary/Diagnostics }
    using { /UnrealEngine.com/Temporary/UI }
    using { /UnrealEngine.com/Temporary/SpatialMath }
    using { /Verse.org/Colors }
    
    <#
    What this Verse Device does:
    - In property fields in device Details, dev can specify text strings for the UI dialog “Title”, arrays(lists) for Line 1 and Line 2 text, and text for the “Next” and “Exit” UI Buttons. Optional Item Granter and SFX.
    - Button Device interacted with ==> UI Canvas added to instigator's screen. Contains Widgets for text blocks and clickable button.
    - UI Button "Next" clicked ==> UI Text Lines update to next in array.
    - Last text lines in array shown ==> UI Button text updates to "Exit". 
    - UI Button "Exit" clicked ==> UI Canvas removed.
    ===== #>

    ui_dialog_device := class(creative_device):

        StringToMessage<localizes>(value:string) : message = "{value}"

        #===== Devices =============================================================
        @editable ButtonDialogStarter: button_device = button_device {} # Necessary.
        @editable ItemGranter: item_granter_device = item_granter_device{} # Optional.
        @editable AudioUIAdd: audio_player_device = audio_player_device{} # Optional.
        @editable AudioUIRemove: audio_player_device = audio_player_device{} # Optional.
        # ^ In Audio Player Devices settings, set "Can be heard by" to "Instigator Only".  Uncheck "Enable Spatialization" and "Enable Volume Attenuation".  

        #===== Text for UI ========================================================
        @editable TextButtonNext: string = ""
        @editable TextButtonExit: string = ""
        @editable TextTitle: string = ""
        @editable TextLine1List: []string = array{}
        @editable TextLine2List: []string = array{}

        #===== Variables: Widgets for UI Canvas ====================================== 
        var WidgetUIButton:button_regular=button_regular {}    
        var WidgetLine1:text_block = text_block {DefaultTextColor := NamedColors.DarkOrchid} #Change the color of the text here
        var WidgetLine2:text_block = text_block {DefaultTextColor := NamedColors.DarkOrchid}
        var WidgetTitle:text_block = text_block {DefaultTextColor := NamedColors.RoyalBlue}
        var WidgetBackground: color_block = color_block {DefaultColor := NamedColors.White, DefaultOpacity := 0.70}
        # ^ NamedColors keywords are from CSS Color Module Level 3. See: https://www.w3.org/TR/css-color-3/ 
    
        #==== Variables: Other ======================================================
        var MaybeMyUIPerPlayer : [player]?canvas = map{}
        var currentTextLine : int = 0 

        # ==== Functions ==============================================================

        # ==== Runs when the device is started in a running game =====================
        OnBegin<override>()<suspends>:void=
            Print("UI Dialogue Device began")
            ButtonDialogStarter.InteractedWithEvent.Subscribe(HandleButtonUIAddInteraction)
            WidgetUIButton.OnClick().Subscribe(HandleUIButtonClick)
            WidgetTitle.SetText(StringToMessage(TextTitle))
            WidgetUIButton.SetText(StringToMessage(TextButtonNext))
            
        # ==== Runs when ButtonDialogStarter interacted with. ====================================
        HandleButtonUIAddInteraction(Agent:agent):void= 
            Print("Button Device interacted with")
            ButtonDialogStarter.Disable() 
            AddCanvas(Agent) 
            UpdateText(currentTextLine)
            AudioUIAdd.Play(Agent) # Optional. Plays Audio Cue
            # You could add other functions here too, like a Light, VFX, Cinematic Sequence, Switch, etc.
                
        <# === When UI Button clicked, check if currentTextline int equals index int of the last member of the TextLine1List array.
            (Aka "Is this the last part of dialog?"). If yes, call RemoveCanvas. If no, call UpdateText. #>
        HandleUIButtonClick(Message: widget_message):void= 
            Print("UI Button clicked")
            if (currentTextLine = TextLine1List.Length):
                RemoveCanvas(Message)
                set currentTextLine = 0
                WidgetUIButton.SetText(StringToMessage(TextButtonNext))
    
            else:  
                if (currentTextLine <= TextLine1List.Length - 1):
                    if (currentTextLine = TextLine1List.Length - 1):
                        WidgetUIButton.SetText(StringToMessage(TextButtonExit))
                        UpdateText(currentTextLine)
                    else:
                        UpdateText(currentTextLine)     
                
        <# === Update text in WidgetLine1 and WidgetLine2 text blocks, ====================
            to the next members of the arrays.#>
        UpdateText(Index:int):void= 
            Print("Update text")
            if(currentStr := TextLine1List[Index]):
                WidgetLine1.SetText(StringToMessage(currentStr)) 
            if(currentStr := TextLine2List[Index]):
                WidgetLine2.SetText(StringToMessage(currentStr)) 
                set currentTextLine += 1
            
        # ==== Add UI Canvas to the instigating player's screen.===========================
        AddCanvas(Agent:agent):void=
            Print("Add canvas")
            if (InPlayer := player[Agent], PlayerUI := GetPlayerUI[InPlayer]):
                if (MyUI := MaybeMyUIPerPlayer[InPlayer]?):
                    PlayerUI.RemoveWidget(MyUI)
                    if (set MaybeMyUIPerPlayer[InPlayer] = false) {}
                else:
                    NewUI := CreateMyUI()
                    PlayerUI.AddWidget(NewUI, player_ui_slot{InputMode := ui_input_mode.All})
                    if (set MaybeMyUIPerPlayer[InPlayer] = option{NewUI}) {}
            
        # ==== Sets the formatting for the UI Canvas, and returns the canvas. You can edit the Offsets, Alignment, and Padding. =================
        # Canvas > Stack Box > Stack Box Slots > Widgets > Text.
        CreateMyUI():canvas=
            Print("Create UI")
            NewCanvas := canvas:
                Slots := array:
                    canvas_slot:
                        ZOrder := {1}
                        Anchors := anchors{ Maximum:= vector2{X:=1.0, Y:=1.0} }
                        Offsets := margin{ Top:=730.0, Left:= 630.0, Right:=630.0, Bottom := 0.0 } # Screen position of the UI canvas, measured in pixels from edges of a 1920 x 1080 screen.
                        Widget := stack_box:
                            Orientation := orientation.Vertical
                            Slots := array:
                                stack_box_slot:
                                    HorizontalAlignment := horizontal_alignment.Left # Alignment of widget within slot.
                                    Padding := margin{ Bottom:= 20.0} # Empty space between Title and Lines, in pixels.
                                    Widget := WidgetTitle
                                stack_box_slot:
                                    HorizontalAlignment := horizontal_alignment.Left
                                    Padding := margin{ Left:= 50.0, Bottom := 10.0} # Optional left indent padding
                                    Widget := WidgetLine1 
                                stack_box_slot:
                                    HorizontalAlignment := horizontal_alignment.Left
                                    Padding := margin{ Left:= 50.0}
                                    Widget := WidgetLine2 
                                stack_box_slot:
                                    HorizontalAlignment := horizontal_alignment.Right
                                    Padding := margin{ Top:= 10.0} # Empty space between lines and button.
                                    Widget := WidgetUIButton
                    canvas_slot:
                        ZOrder := {0}
                        Anchors := anchors{ Maximum:= vector2{X:=1.0, Y:=1.0} }
                        Offsets := margin{ Top:=700.0, Left:= 600.0, Right:=600.0, Bottom := 110.0 }
                        Widget := WidgetBackground
                                            
            return NewCanvas
            
        # ==== Remove UI Canvas from instigating player's screen. ============================================
        RemoveCanvas(Message: widget_message):void=
            if (PlayerUI := GetPlayerUI[Message.Player], MyUI := MaybeMyUIPerPlayer[Message.Player]?, SelectedButton := text_button_base[Message.Source]):
                Print("Remove Canvas")
                PlayerUI.RemoveWidget(MyUI)
                if (set MaybeMyUIPerPlayer[Message.Player] = false) {} 
                ButtonDialogStarter.Enable() 
                AudioUIRemove.Play(Message.Player)
                ItemGranter.GrantItem(Message.Player) # Optional. Grants gift/reward to Player.
                    <# ^ Call (Message.Player) instead of (Player), because our function RemoveCanvas is widget_message type not Player type. 
                        Message.Player is a member of widget_message type. #>
                    #You could add other functions here too.
            
                
        <# That's it :) Happy building <3 <3 <3 
        - Leave feedback/questions on my UI Dialog Device Forum post: https://forums.unrealengine.com/t/ui-dialog-verse-device-with-next-exit-button-snippet/744022
        - Follow my Devlog for my UEFN game WIP, Sprigs: https://forums.unrealengine.com/t/sprigs-devlog-6-the-floor-is-lava-physical-material-experiments/657293 
        - Epic Docs webpage about Verse UI, for reference: https://dev.epicgames.com/documentation/en-us/uefn/creating-in-game-ui-in-verse #>

# from bug blaster the youtube video made by warforge
PropMoveToPlayer(Prop:creative_prop, Player: player)<suspends>:void=
    MoveSpeed := 0.1
    loop:
        Sleep(0.03)
        if (PlayerFort := Player.GetFortCharacter[], Prop.IsValid[])
        then:
            PropLocation := Prop.GetTransform().Translation
            PlayerLocation := PlayerFort.GetTransform().Translation

            if(LookDirection := (PlayerLocation - PropLocation).MakeUnitVector[]):
                Yaw := RadiansToDegrees(ArcTan(LookDirection.Y, LookDirection.X))
                Pitch := 0.0
                Roll := 0.0
            
                NewRotation := MakeRotationFromYawPitchRollDegrees(Yaw, Pitch, Roll)

                LerpLocation:= Lerp(PropLocation, PlayerLocation, MoveSpeed)
                FinalLocation := vector3 {X:= LerpLocation.X, Y:= LerpLocation.Y, Z:= 0.0}
        else:
            break

# from triad infiltrator

# FindTeamWithLargestDifference():?team =
#     Print("Attempting to find smallest team")
#     var TeamToAssign:?team = false
#     var LargestDifference:int = 0
#     for:
#         CandidateTeam:Teams
#         CurrentTeamSize := GetPlayspace().GetTeamCollection().GetAgents[CandidateTeam].Length
#         MaximumTeamSize := TeamsAndTotals[CandidateTeam]
#     do:
#         Logger.Print("Checking a team...")
#         Logger.Print("Maximum size Maximum size of team {CandidateTeamIndex + 1} is {MaximumTeamSize}")
#         DifferenceFromMaximum := MaximumTeamSize - CurrentTeamSize
#         Logger.Print("Difference from minimum is {DifferenceFromMaximum}")
#         if(LargestDifference < DifferenceFromMaximum):
#             set LargestDifference = DifferenceFromMaximum
#             set TeamToAssign = option{CandidateTeam}
#             Logger.Print("Found a team under minimum players: {DifferenceFromMaximum}")
#     return TeamToAssign

# OnBegin<override>()<suspends> : void =
#     # Get all the Teams
#     set Teams = GetPlayspace().GetTeamCollection().GetTeams()
#     set AllPlayers = GetPlayspace().GetPlayers()
#     # Save the teams to later reference them
#     set Infiltrators = option{Teams[0]}
#     set Attackers = option{Teams[1]}
#     set Defenders = option{Teams[2]}
       
#     if:
#         Infiltrators := InfiltratorsOpt?
#         Attackers := AttackersOpt?
#         Defenders :=  DefendersOpt?
#         Logger.Print("Found all three teams")
#         set TeamsAndTotals[Infiltrators] = MaximumInfiltrators
#         set TeamsAndTotals[Attackers] = MaximumAttackers
#         set TeamsAndTotals[Defenders] = MaximumDefenders
#         Logger.Print("Set all three teams in TeamsAndTotals")
#     then:
#         set AllPlayers = Shuffle(AllPlayers)
#         BalanceTeams()
#         TeleportPlayersToStartLocations()
#     else:
#         Logger.Print("Couldn't find all teams, make sure to assign the correct teams in your island settings.")

triad_infiltration_log_channel := class(log_channel){}

asymmetric_multiplayer_balance := class(creative_device):

    Logger:log = log{Channel := triad_infiltration_log_channel}

    # To avoid players not being able to join a team, you should set the maximum number
    @editable
    MaximumInfiltrators:int = 2
    @editable
    MaximumAttackers:int = 3
    @editable
    MaximumDefenders:int = 3
    var TeamsAndTotals:[team]int = map{}
    @editable
    Teleporters:[]teleporter_device = array{}
   
    @editable
    InvisibilityManager:invisibility_manager = invisibility_manager{}

    @editable
    var WeaponGranters:[]item_granter_device = array{}

    @editable
    PlayersSpawners:[]player_spawner_device = array{}
   
    var InfiltratorsOpt:?team = false
    var AttackersOpt:?team = false
    var DefendersOpt:?team = false
    var Teams:[]team = array{}
    var AllPlayers:[]player = array{}

    OnBegin<override>()<suspends> : void =
        # Get all the Teams
        set Teams = GetPlayspace().GetTeamCollection().GetTeams()
        set AllPlayers = GetPlayspace().GetPlayers()
        # Save the teams to later reference them
        set InfiltratorsOpt = option{Teams[0]}
        set AttackersOpt = option{Teams[1]}
        set DefendersOpt = option{Teams[2]}
       
        if:
            Infiltrators := InfiltratorsOpt?
            Attackers := AttackersOpt?
            Defenders :=  DefendersOpt?
            Logger.Print("Found all three teams")
            set TeamsAndTotals[Infiltrators] = MaximumInfiltrators
            set TeamsAndTotals[Attackers] = MaximumAttackers
            set TeamsAndTotals[Defenders] = MaximumDefenders
            Logger.Print("Set all three teams in TeamsAndTotals")
        then:
            set AllPlayers = Shuffle(AllPlayers)
            #Subscribe to PlayerAddedEvent to allow team rebalancing when a new player joins the game
            GetPlayspace().PlayerAddedEvent().Subscribe(OnPlayerAdded)
            for(PlayerSpawner:PlayersSpawners):
                PlayerSpawner.SpawnedEvent.Subscribe(OnPlayerSpawn)
           
            BalanceTeams()
            Logger.Print("Teams balanced, calling invisibility script")
            InvisibilityManager.StartInvisibilityManager(Teams, AllPlayers, Infiltrators)
            TeleportPlayersToStartLocations()
        else:
            Logger.Print("Couldn't find all teams, make sure to assign the correct teams in your island settings.")

    # Grants players a weapon based on the index of their team in the Teams array
    # by indexing into the WeaponGranters array.
    GrantTeamWeapon(InPlayer:player):void=
        if(CurrentTeam := GetPlayspace().GetTeamCollection().GetTeam[InPlayer]):
            for(TeamIndex -> PlayerTeam:Teams, PlayerTeam = CurrentTeam):
                if(WeaponGranter := WeaponGranters[TeamIndex]):
                    WeaponGranter.GrantItem(InPlayer)
                    Logger.Print("Granted the a Player on team {TeamIndex + 1} a weapon")
   
    # Runs when any player spawns from a spawn pad.
    # Calls GrantTeamWeapon using the provided SpawnedAgent.
    OnPlayerSpawn(SpawnedAgent:agent):void=
        if(SpawnedPlayer := player[SpawnedAgent]):
            Logger.Print("Attempting to grant spawned player a weapon")
            GrantTeamWeapon(SpawnedPlayer)


    # Handles a new player joining the game
    OnPlayerAdded(InPlayer:player):void=
        Logger.Print("A new Player joined, assigning them to a team")
        FortTeamCollection := GetPlayspace().GetTeamCollection()
        set AllPlayers = GetPlayspace().GetPlayers()

        # Assign the new player to the smallest team
        BalancePlayer(InPlayer)

        if (FortTeamCollection.GetTeam[InPlayer] = InfiltratorsOpt?):
            InvisibilityManager.OnInfiltratorJoined(InPlayer)

    <#
    For each player, find the number of players of the team they're on. Iterate through the
    list of teams and assign them to the team with the least amount of players, or their
    starting team in case of ties.
    #>
    BalanceTeams():void=
        Logger.Print("Beginning to balance teams")
        FortTeamCollection := GetPlayspace().GetTeamCollection()
        Logger.Print("AllPlayers Length is {AllPlayers.Length}")

        for (TeamPlayer : AllPlayers):
            BalancePlayer(TeamPlayer)
     
    BalancePlayer(InPlayer:player):void=
        var TeamToAssign:?team = false
        set TeamToAssign = FindTeamWithLargestDifference()
        if (AssignedTeam := TeamToAssign?, GetPlayspace().GetTeamCollection().AddToTeam[InPlayer, AssignedTeam]):
            Logger.Print("Attempting to assign newly joined to a new team")
        else:
            Logger.Print("This player was already on the smallest team")

    # Finds the team with the largest difference in their number of players from their
    # maximum number of players
    FindTeamWithLargestDifference():?team =
        Logger.Print("Attempting to find smallest team")
        var TeamToAssign:?team = false
        var LargestDifference:int = 0
        for:
            CandidateTeamIndex -> CandidateTeam:Teams
            CurrentTeamSize := GetPlayspace().GetTeamCollection().GetAgents[CandidateTeam].Length
            MaximumTeamSize := TeamsAndTotals[CandidateTeam]
        do:
            Logger.Print("Checking a team...")
            Logger.Print("Maximum size of team {CandidateTeamIndex + 1} is {MaximumTeamSize}")
            DifferenceFromMaximum := MaximumTeamSize - CurrentTeamSize
            Logger.Print("Difference from maximum is {DifferenceFromMaximum}")
            if(LargestDifference < DifferenceFromMaximum):
                set LargestDifference = DifferenceFromMaximum
                set TeamToAssign = option{CandidateTeam}
                Logger.Print("Found team {CandidateTeamIndex + 1} with difference {DifferenceFromMaximum}")

        return TeamToAssign

    TeleportPlayersToStartLocations():void=
        Logger.Print("Teleporting players to start locations")
        for:
            TeamIndex -> PlayerTeam:Teams 
            TeamPlayers := GetPlayspace().GetTeamCollection().GetAgents[PlayerTeam]
            TeamTeleporter := Teleporters[TeamIndex]
            Transform := TeamTeleporter.GetTransform()
        do:
            for(TeamPlayer:TeamPlayers):
                TeamPlayer.Respawn(Transform.Translation, Transform.Rotation)
                Logger.Print("Teleported this player to their start location")

triad_invisibility_log_channel := class(log_channel){}

invisibility_manager := class(creative_device):

    Logger:log = log{Channel := triad_invisibility_log_channel}

    @editable
    PlayersSpawners:[]player_spawner_device = array{}
   
    # Whether the visibility of the infiltrators is shared with teammates.
    @editable
    IsVisibilityShared:logic = true

    # How long the infiltrators are visible for after being damaged.
    @editable
    VulnerableSeconds:float = 3.0
   
    # How quickly infiltrators flicker after being damaged
    @editable
    FlickerRateSeconds:float = 0.8
   
    var Teams:[]team = array{}

    var PlayerVisibilitySeconds:[agent]float = map{}

    OnBegin<override>()<suspends>:void=
        # Wait for teams to be balanced before subscribing to events that make the players invisible.
        Logger.Print("Waiting for teams to be balanced...")
   
    StartInvisibilityManager<public>(AllTeams:[]team, Players:[]player, Infiltrators:team):void=
        Logger.Print("Invisibility script started!")
        set Teams = AllTeams
        AllPlayers := Players
        for(PlayerSpawner:PlayersSpawners):
            PlayerSpawner.SpawnedEvent.Subscribe(OnPlayerSpawn)
       
        <# For each player, if they spawned on the infiltrator team, spawn an OnInfiltratorDamaged function for that
        player. Then make their character invisible. #>
        for(TeamPlayer : AllPlayers):
            if:
                FortCharacter:fort_character = TeamPlayer.GetFortCharacter[]
                CurrentTeam := GetPlayspace().GetTeamCollection().GetTeam[TeamPlayer]
                Logger.Print("Got this player's current team")
                Infiltrators = CurrentTeam
                set PlayerVisibilitySeconds[TeamPlayer] = 0.0
                Logger.Print("Added player to PlayerVisibilitySeconds")
            then:
                spawn{OnInfiltratorDamaged(TeamPlayer)}
                Logger.Print("Player spawned as an infiltrator, making them invisible")
                FortCharacter.Hide()
            else:
                Logger.Print("This player isn't an infiltrator")

    FlickerCharacter(InCharacter:fort_character)<suspends>:void=
        Logger.Print("FlickerCharacter() invoked")
        # Loop hiding and showing the character to create a flickering effect.
        loop:
            InCharacter.Hide()
            Sleep(FlickerRateSeconds)
            InCharacter.Show()
            Sleep(FlickerRateSeconds)
            # Each loop, decrease the amount of time the character is flickering by FlickerRateSeconds.
            # If Remaining time hits 0, break out of the loop.
            if:
                TimeRemaining := set PlayerVisibilitySeconds[InCharacter.GetAgent[]] -= FlickerRateSeconds * 2
                TimeRemaining <= 0.0
            then:
                InCharacter.Hide()
                break                          

    OnInfiltratorDamaged(InAgent:agent)<suspends>:void=
        Logger.Print("Attempting to start flickering this character")
        TeamCollection := GetPlayspace().GetTeamCollection()
        if (FortCharacter := InAgent.GetFortCharacter[]):
            loop:
                if (IsVisibilityShared?, CurrentTeam := TeamCollection.GetTeam[InAgent], TeamAgents := TeamCollection.GetAgents[CurrentTeam]):
                    # For each teammate, set them in PlayerVisibility seconds and spawn a FlickerEvent
                    for(Teammate : TeamAgents):
                        Logger.Print("Calling StartOrResetFlickering on a Teammate")
                        StartOrResetFlickering(Teammate)
                else:
                    # Just flicker the damaged character
                    Logger.Print("Calling StartOrResetFlickering on InAgent")
                    StartOrResetFlickering(InAgent)
                FortCharacter.DamagedEvent().Await()

    StartOrResetFlickering(InAgent:agent):void=
        if (not IsFlickering[InAgent], FortCharacter := InAgent.GetFortCharacter[]):
            Logger.Print("Attempting to start NEW FlickerEvent for this character")
            # New flickering started
            if (set PlayerVisibilitySeconds[InAgent] = VulnerableSeconds):
                spawn{FlickerCharacter(FortCharacter)}
                Logger.Print("Spawned a FlickerEvent for this character")
        else:
            # Reset ongoing flickering
            if (set PlayerVisibilitySeconds[InAgent] = VulnerableSeconds):
                Logger.Print("Reset character's FlickerTimer to VulnerableSeconds")
       
    IsFlickering(InAgent:agent)<decides><transacts>:void=
        PlayerVisibilitySeconds[InAgent] > 0.0

    OnInfiltratorJoined<public>(InAgent:agent):void=
        spawn{OnInfiltratorDamaged(InAgent)}
       
    OnPlayerSpawn(SpawnedAgent:agent):void=
        if:
            FortCharacter:fort_character = SpawnedAgent.GetFortCharacter[]
            CurrentTeam := GetPlayspace().GetTeamCollection().GetTeam[SpawnedAgent]
            Teams[0] = CurrentTeam
            Logger.Print("Player spawned as an infiltrator, making them invisible")
        then:
            FortCharacter.Hide()

triad_item_capture_log_channel := class(log_channel){}

item_capture_manager := class(creative_device):

    Logger:log = log{Channel := triad_item_capture_log_channel}
    @editable
    CaptureItemSpawner:capture_item_spawner_device = capture_item_spawner_device{}
    @editable
    CaptureItemIndicator:creative_prop = creative_prop{}
    @editable
    UpdateRateSeconds:float = 0.033
    @editable
    VerticalOffset:float = 180.0

    OnBegin<override>()<suspends>:void=
        CaptureItemSpawner.ItemPickedUpEvent.Subscribe(OnItemGrabbed)
   
    OnItemGrabbed(InAgent:agent):void=
        Logger.Print("Objective Captured")
        if(FortCharacter := InAgent.GetFortCharacter[]):
            spawn{FollowCharacter(FortCharacter)}

    FollowCharacter(FortCharacter:fort_character)<suspends>:void=
        Logger.Print("Spawned FollowCharacter function")
        race:
            loop:
                Transform := FortCharacter.GetTransform()
                if:
                    CaptureItemIndicator.TeleportTo[Transform.Translation + vector3{Z := VerticalOffset}, Transform.Rotation]
                Sleep(UpdateRateSeconds)
            CaptureItemSpawner.ItemCapturedEvent.Await()
            CaptureItemSpawner.ItemDroppedEvent.Await()
            FortCharacter.EliminatedEvent().Await()

        Sleep(UpdateRateSeconds)
        Logger.Print("Objective dropped or captured")
        SpawnerTransform := CaptureItemSpawner.GetTransform()
        if:
            # Teleport back to spawner
            CaptureItemIndicator.TeleportTo[SpawnerTransform.Translation + vector3{Z := VerticalOffset * -10}, SpawnerTransform.Rotation]
            Logger.Print("Returned Beacon to capture spawner")

wrapp_event_add_param:=module:
        #usage example (when subscribing to an event that returns an agent)
    # ButtonDevice.InteractedWithEvent.SubscribeAgent(OnButtonInteract, "Hello!")

    OnButtonInteract(Agent : agent, Text : string) : void =
        Print("Button interacted with {Text}!")
        
    #usage example (when subscribing to an event that returns tuple(), aka an empty tuple)
    # CampfireDevice.CampfirePulseEvent.SubscribeEmpty(OnCampfirePulse, 90210)

    OnCampfirePulse(Number : int) : void =
        Print("Campfire pulse had {Number}!")

    #The important code is below. Put this in one of your verse files, perhaps utils.verse or something!

    using { /Verse.org/Simulation }

    (Listenable : listenable(agent)).SubscribeAgent(OutputFunc : tuple(agent, t)->void, ExtraData : t where t:type) : cancelable =
        Wrapper := wrapper_agent(t){ExtraData := ExtraData, OutputFunc := OutputFunc}
        Listenable.Subscribe(Wrapper.InputFunc)

    wrapper_agent(t : type) := class():
        ExtraData : t;
        OutputFunc : tuple(agent, t) -> void
        InputFunc(Agent : agent):void = OutputFunc(Agent, ExtraData)

    (Listenable : listenable(tuple())).SubscribeEmpty(OutputFunc : t -> void, ExtraData : t where t:type) : cancelable =
        Wrapper := wrapper_empty(t) {ExtraData := ExtraData, OutputFunc := OutputFunc}
        Listenable.Subscribe(Wrapper.InputFunc)

    wrapper_empty(t : type) := class():
        ExtraData : t;
        OutputFunc : t -> void
        InputFunc():void = OutputFunc(ExtraData)

opt_in_selection_pool := module:
        
    using { /Fortnite.com/Characters }
    using { /Fortnite.com/Devices }
    using { /UnrealEngine.com/Temporary/Diagnostics }
    using { /Verse.org/Random }
    using { /Verse.org/Simulation }

    # Selects a random subset of Count elements from Elements and returns an array of the selected elements.
    # If Count is greater than the number of elements in Elements, all elements are returned in a random order.
    # This function uses parametric types, a feature of Verse. Parametric types allow you to specify arguments without a specific type.
    # This means that expressions can be more "generic" and operate on the arguments as long as those operations are supported by the type.
    # In this case, we don't need to know the type of each element in Elements to operate on the array, so we can use Shuffle and Slice on any type "t".
    # For more information, see https://dev.epicgames.com/documentation/en-us/uefn/Verse/parametric-types-in-verse
    SelectRandomElements<public>(Elements:[]t, Count:int where t:type):[]t=
        # Shuffle the Elements so they're in random order when we pick them.
        RandomElements := Shuffle(Elements)
        # Slice returns an array from StartIndex (first argument) to StopIndex (second argument).
        # Since the elements are in random order, this will return a random subset of Count elements from the start.
        if (Selection := RandomElements.Slice[0, Count]):
            Selection # If the Slice operation succeeds this is the last expression of the function, which is used as the implicit return.
        else:
            # If there are less than Count elements in the array, return all elements. They'll be in random order.
            RandomElements

    # This device is used by players to opt in or out of a selection pool.
    # The players interact with the OptInOutDevice to opt-in or opt-out of the SelectionPool.
    # Interacting with the SelectionTrigger device selects SelectionCount players from the pool and fires the PlayersSelectedEvent.
    opt_in_selection_pool_device := class(creative_device):
        # Used by a player to opt in or out of the selection pool.
        @editable
        OptInOutDevice:switch_device = switch_device{}
        # Used to trigger players' selection from the pool.
        @editable
        SelectionTrigger:button_device = button_device{}
        # How many players are selected from the pool.
        @editable
        SelectionCount<public>:int = 1
        # Event fired when players are selected from the pool. Contains the array of selected players.
        PlayersSelectedEvent<public>:event([]player) = event([]player){}

        # Pool of players from which to select SelectionCount players.
        var SelectionPool:[]player = array{}

        # Add the Agent to the selection pool as a player.
        OptIn<private>(Agent:agent):void=
            # We cast the Agent to a player (player[Agent]) to add it to the SelectionPool array.
            # This will fail if the Agent is not a player.
            if (Player := player[Agent]):
                # To add the Player to the SelectionPool we construct a new array from the current
                # SelectionPool + an array with the new Player.
                set SelectionPool += array{Player}
                Print("Player opted in to selection pool. Players in pool: {SelectionPool.Length}")

        # Remove the Agent from the selection pool as a player.
        OptOut<private>(Agent:agent):void=
            # RemoveFirstElement returns the array without the first match found, so we set SelectionPool = the new array.
            # We must wrap it in a failure context if the player is not in the array or casting the Agent to a player fails.
            if (Tmp := SelectionPool.RemoveFirstElement[player[Agent]]; set SelectionPool = Tmp;):
                Print("Player opted out of selection pool. Players in pool: {SelectionPool.Length}")
        
        # Reset all players to opted-out state and removes them from the SelectionPool
        ResetPool<private>():void=
            # Since we're calling OptInOutDevice.TurnOff for the Player, OptOut(Player) is called since it's subscribed
            # to the OptInOutDevice.TurnedOffEvent. That'll remove the Player from the SelectionPool.
            for (Player:SelectionPool) do OptInOutDevice.TurnOff(Player)
            # We still reset the SelectionPool with "= array{}" to remove any players that left the game before a selection
            # is made. It's simpler than tracking players leaving the game.
            set SelectionPool = array{}
            Print("Pool reset.")        
            
        # Selects the Players and resets the SelectionPool
        SelectPlayers<private>(Agent:agent):void= 
            SelectedPlayers := SelectRandomElements(SelectionPool, SelectionCount)
            PlayersSelectedEvent.Signal(SelectedPlayers)
            ResetPool()
            
        OnBegin<override>()<suspends>:void=
            OptInOutDevice.TurnedOnEvent.Subscribe(OptIn)
            OptInOutDevice.TurnedOffEvent.Subscribe(OptOut)
            SelectionTrigger.InteractedWithEvent.Subscribe(SelectPlayers)

            # An example of how you could use the PlayersSelectedEvent.
            # This example will damage the selected players.
            loop:
                SelectedPlayers := PlayersSelectedEvent.Await()
                for (Player:SelectedPlayers, Character := Player.GetFortCharacter[]):
                    Character.Damage(5.0)


killing_spree := module:
        <## ABOUT ## ===========================================================================================================================##
     Killing Spree is a script that will reward Score and display HUD messages to players for subsequent eliminations in a defined time.   
     Choose the desired Score and time between kills in Options, add as many HUD Messages as you like to the Array List and let the        
     script do the rest.                                                                                                                   
                                                                                                                                           
           By: Axel Capek | Socials: @AxelCapek                                                                                            
           Version: 1.7
           First Published: 2nd August 2022                                                                                                                 
           Last Updated: 23rd March 2022                                                                                                  
                                                                                                                                           
    ## ABOUT ## ===========================================================================================================================##>

    using { /Fortnite.com/Devices }
    using { /Verse.org/Native }
    using { /Verse.org/Simulation}
    using { /UnrealEngine.com/Temporary/Diagnostics }
    using { /Fortnite.com/Playspaces }
    using { /Fortnite.com/Characters }
    using { /Fortnite.com/Game }
    
    log_new_device:=class(log_channel){}
    KillingSpreeScript := class<concrete>(creative_device):
        Logger:log = log{Channel:=log_new_device}
        # Device List ===========================================================================
            @editable      DebugTrigger:trigger_device = trigger_device{}
            @editable      ScoreDevice:score_manager_device = score_manager_device{}
            @editable      KillTimer:timer_device = timer_device{}
            @editable      HUD_First:hud_message_device = hud_message_device{}
            @editable      HUD_KillingSpree:[]hud_message_device = array{}
            <#

            ===================================DEVICE SETTINGS===================================

                TIMER DEVICE :
                    Applies To - Player
                    Completion Behaviour - Reset
                    Show On HUD - OFF
                SCORE MANAGER DEVICE :
                    Increment Score On Awarding - OFF
                    Play Audio - OFF
                HUD MESSAGE DEVICES :
                    Message Recipient - Triggering Player
                    Display Time - 3.0 (Optional)

            End of Device List #>
    
        # Options ================================================================================
            #Enable First Blood?
            @editable      EnableFirstBlood:logic = true
            ##Time (in seconds) between kills before the Killing Spree Timer expires.
            @editable      KillTime:float = 3.5
            ##How many Kills does a player need to have before starting the spree? Ex. 2 Kills in succession = "Double Kill!"
            @editable      KillsToStartSpree:int = 2
            ##How much score does each elim award?
            @editable      ScorePerKill:int = 5
            ##How much additional score does First Blood award?
            @editable      ScoreFirstBlood:int = 10
            ##How much additional score does a spree award? 
            @editable      ScoreForSpree:int = 5
        # End of Options =========================================================================
    
        # Variables  
            var FirstBlood:logic = false
            var PlayerKillCount:[agent]int = map{}
        # End of Variables ========================================================================
    
        # Function: OnBegin =======================================================================
        OnBegin<override>()<suspends>:void=
            # Gets players currently in-game and players that join the game then runs the PlayerJoin() function for each.
            Self.GetPlayspace().PlayerAddedEvent().Subscribe(PlayerJoin)
            SubscribeOnBeginPlayers()
            #Subscribe the Success Event of the Kill Timer to fail the spree.
            KillTimer.SuccessEvent.Subscribe(KillingSpreeFailed)
            #Sets the Kill Timer duration according to the editable KillTime var.
            KillTimer.SetMaxDuration(KillTime)
            # Trigger For Debugging or Event Binding! 
            # 1 - ###[Hit the trigger to simulate elims!]
            # 2 - ###[Trigger Can also be attached to Guard Spawner, Creature Spawner with Event Binding if we want AI to count towards Killing Spree!] 
            DebugTrigger.TriggeredEvent.Subscribe(BeginKillingSpree)
            Logger.Print("Killing Spree Script Started!")
        # ========================================================================================
    
        # Gets the current availible players and runs the PlayerJoin() function for each.
        SubscribeOnBeginPlayers():void = 
            Players:[]player := Self.GetPlayspace().GetPlayers()
            for (PlayerNum -> P : Players ):
                PlayerJoin(P)

        # Subscribe players to all relevant functions.
        PlayerJoin(Agent:agent):void=
            Print("Player Added!")
            # Sets the current agents Kill Streak int to 0.
            if { set PlayerKillCount[Agent] = 0 }
            # Subscribes elim events for the current agent.
            if (Chr := Agent.GetFortCharacter[]):
                Chr.EliminatedEvent().Subscribe(PlayerElimination)

        # Check when a player gets an elimination.
        PlayerElimination(Elimination:elimination_result):void=
            Print("Elimination Event!")
            #Gets the kill instigator from the elimination_result.
            if(Instigator := Elimination.EliminatingCharacter?, InstigatorAgent := Instigator.GetInstigatorAgent[]):
                BeginKillingSpree(option {InstigatorAgent}) 

        # Function: Show First Blood Message!
        GiveFirstBlood(Agent:agent):void=
            set FirstBlood = true
            HUD_First.Show( Agent )
            ScoreDevice.SetScoreAward(ScoreFirstBlood)
            ScoreDevice.Activate(Agent)
            Print("First Blood!")

        ## Begin Killing Spree      
        BeginKillingSpree(Agent:?agent):void=
            if (Player := Agent?):
                #Awards First Blood if enabled!
                if ( not FirstBlood? and EnableFirstBlood?):
                    GiveFirstBlood(Player)
                #Agent got an elimination. Increment kill count and give score.
                if(PlayerKills := set PlayerKillCount[Player] += 1):
                    ScoreDevice.SetScoreAward(ScorePerKill)
                    ScoreDevice.Activate(Player)
                    Print("Kills: {PlayerKills}")
                    #Agent needs at least {KillsToStartSpree} eliminations to trigger a double kill!
                    if (PlayerKills >= KillsToStartSpree and PlayerKills < ( HUD_KillingSpree.Length + 1) ):
                        ##Hides the previous HUD messages.. if they exists.
                        for (Previous := 0 .. (PlayerKills - KillsToStartSpree - 1)):
                            if (KillSpreeMessagePrevious := HUD_KillingSpree[Previous]):
                                KillSpreeMessagePrevious.Hide()
                        ##Shows the next HUD message.
                        if (KillSpreeMessageNext := HUD_KillingSpree[ ( PlayerKills - KillsToStartSpree ) ]):
                            KillSpreeMessageNext.Show( Player )
                        #Because player got a successful elimination, Killing Spree Timer reset & player is awarded Kill Spree Score.
                        KillTimer.Reset(Player)
                        ScoreDevice.SetScoreAward(ScoreForSpree)
                        ScoreDevice.Activate(Player)
                    #Agent has reached the max killing spree amount.. Repeat the final HUD message for subsequent eliminations.
                    else if (PlayerKills >= ( HUD_KillingSpree.Length + 1) ):
                        if (KillSpreeMessagePrevious := HUD_KillingSpree[ ( HUD_KillingSpree.Length - 2 ) ]):
                            KillSpreeMessagePrevious.Hide()
                        ##Shows the next HUD message.
                        if (KillSpreeMessageNext := HUD_KillingSpree[ ( HUD_KillingSpree.Length - 1) ]):
                            KillSpreeMessageNext.Show( Player )
                        KillTimer.Reset(Player)
                        ScoreDevice.SetScoreAward(ScoreForSpree)
                        ScoreDevice.Activate(Player)
                    ##Spawn and Start the Killing Spree Timer.
                    Print("Successful Elimination.")
                    KillTimer.Start(Player)
                    

        KillingSpreeFailed(Agent:?agent):void=
            #Sets the Players Kill Count Variable back to 0.
            if(set PlayerKillCount[Agent?] = 0):
                Logger.Print("Failed Elimination.TTK Timer Expired!") 

    <# END #>

# Type alias

    # This is particularly useful in combination with function types. For example,

    # int_predicate := type{_(:int)<transacts><decides> : void}
    # Filter(X : []int, F : int_predicate) : []int =
    #     for (Y : X, F[Y]):
    #         Y
    # Note that Verse does not currently support parametric type aliases.
    
    # For example,
    
    # predicate(t : type) := type{_(:t)<transacts><decides> : void}


hpBarSnippet := module:
    using { /Fortnite.com/Devices }
    using { /Verse.org/Simulation }
    using { /UnrealEngine.com/Temporary/Diagnostics }
    using { /UnrealEngine.com/Temporary/UI }
    using { /UnrealEngine.com/Temporary/SpatialMath }
    using { /Verse.org/Colors }
    using { /Fortnite.com/UI }
    
    subtitle_core := class(creative_device):
    
        @editable
        SubtitleDevices: []subtitle_device = array{}
    
        @editable
        HPBar: hp_bar = hp_bar{}
    
        @editable
        DamageInfo: []damage_info = array{}
    
        GlobalData: global_data = global_data{}
    
        OnBegin<override>()<suspends>:void=
            HPBar.EnableHPBarTrigger.TriggeredEvent.Subscribe(OnEnableHPBar)
            HPBar.DisableHPBarTrigger.TriggeredEvent.Subscribe(OnDisableHPBar)
            HPBar.ResetHPBarTrigger.TriggeredEvent.Subscribe(OnResetHPBar)
    
            set GlobalData.HPBar = Self.HPBar
            set GlobalData.NowHP = Self.HPBar.MaxHP
    
            for(Info : DamageInfo):
                spawn{DamageEvent(Info)}
    
            for(SDevice : SubtitleDevices):
                set SDevice.GlobalData = Self.GlobalData
                SDevice.Setup()
    
        DamageEvent(Info: damage_info)<suspends>:void=
            loop:
                MaybeAgent := Info.DamageTrigger.TriggeredEvent.Await()
                set GlobalData.NowHP -= Info.DamageAmount
                for(Player : GetPlayspace().GetPlayers(), WClass := GlobalData.WidgetPerAgent[Player]):
                    WClass.UpdateUI(Player)
    
                if(GlobalData.NowHP <= 0.0, Agent := MaybeAgent?):
                    if(Agent := MaybeAgent?):
                        HPBar.ElimEvent.Trigger(Agent)
                    else:
                        HPBar.ElimEvent.Trigger()
    
                Sleep(0.0)
    
        OnEnableHPBar(MaybeAgent: ?agent):void=
            for(Player : GetPlayspace().GetPlayers()):
                if:
                    not GlobalData.WidgetPerAgent[Player], set GlobalData.WidgetPerAgent[Player] = main_widget:
                        MaxHP := GlobalData.HPBar.MaxHP
                        BasePosition := GlobalData.HPBar.Position
                        SizePosition := GlobalData.HPBar.Size
                        OutlineSize := GlobalData.HPBar.OutlineSize
                        GlobalData := Self.GlobalData
                        PrevHP := GlobalData.HPBar.MaxHP
                        DamageEffectAmount := GlobalData.HPBar.DamageEffectAmount
                        HPBarBG := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.BackgroundColor)}
                        HPBarOutline := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.OutlineColor)}
                        HPBarBaseColor := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.BarColor)}
                        HPBarDamagedColor := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.DamageEffectColor)}
                        HPBarText := text_block{DefaultTextColor := MakeColorFromHex(GlobalData.HPBar.HPTextColor), DefaultJustification := text_justification.Center}
                if(WClass := GlobalData.WidgetPerAgent[Player]):
                    set WClass.IsDisplayHPBar = true
                    spawn{WClass.UpdateUI(Player)}
    
        OnDisableHPBar(MaybeAgent: ?agent):void=
            for(Player : GetPlayspace().GetPlayers()):
                if:
                    not GlobalData.WidgetPerAgent[Player], set GlobalData.WidgetPerAgent[Player] = main_widget:
                        MaxHP := GlobalData.HPBar.MaxHP
                        BasePosition := GlobalData.HPBar.Position
                        SizePosition := GlobalData.HPBar.Size
                        OutlineSize := GlobalData.HPBar.OutlineSize
                        GlobalData := Self.GlobalData
                        PrevHP := GlobalData.HPBar.MaxHP
                        DamageEffectAmount := GlobalData.HPBar.DamageEffectAmount
                        HPBarBG := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.BackgroundColor)}
                        HPBarOutline := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.OutlineColor)}
                        HPBarBaseColor := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.BarColor)}
                        HPBarDamagedColor := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.DamageEffectColor)}
                        HPBarText := text_block{DefaultTextColor := MakeColorFromHex(GlobalData.HPBar.HPTextColor), DefaultJustification := text_justification.Center}
                if(WClass := GlobalData.WidgetPerAgent[Player]):
                    set WClass.IsDisplayHPBar = false
                    spawn{WClass.UpdateUI(Player)}
    
        OnResetHPBar(MaybeAgent: ?agent):void=
            for(Player : GetPlayspace().GetPlayers()):
                if:
                    not GlobalData.WidgetPerAgent[Player], set GlobalData.WidgetPerAgent[Player] = main_widget:
                        MaxHP := GlobalData.HPBar.MaxHP
                        BasePosition := GlobalData.HPBar.Position
                        SizePosition := GlobalData.HPBar.Size
                        OutlineSize := GlobalData.HPBar.OutlineSize
                        GlobalData := Self.GlobalData
                        PrevHP := GlobalData.HPBar.MaxHP
                        DamageEffectAmount := GlobalData.HPBar.DamageEffectAmount
                        HPBarBG := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.BackgroundColor)}
                        HPBarOutline := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.OutlineColor)}
                        HPBarBaseColor := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.BarColor)}
                        HPBarDamagedColor := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.DamageEffectColor)}
                        HPBarText := text_block{DefaultTextColor := MakeColorFromHex(GlobalData.HPBar.HPTextColor), DefaultJustification := text_justification.Center}
                if(WClass := GlobalData.WidgetPerAgent[Player]):
                    set GlobalData.NowHP = HPBar.MaxHP
                    set WClass.PrevHP = HPBar.MaxHP
                    spawn{WClass.UpdateUI(Player)}
    
    subtitle_device := class(creative_device):
    
        @editable
        SubtitleText: []subtitle_text = array{}
    
        @editable
        SubtitlePosition: position = position{}
    
        @editable
        StartSubtitleTrigger: trigger_device = trigger_device{}
    
        @editable
        EndEventTrigger: trigger_device = trigger_device{}
    
        var GlobalData: global_data = global_data{}
        var IsPlayingSubtitle: logic = false
    
        HalfChar: string = "QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm1234567890-^\\@[;:],./!\"#$%&'()=~|`\{\}+*\<\>?_ "
    
        JapaneseTextSizeX: float = 0.006
        EnglishTextSizeX: float = 0.01
        JapaneseTextSizeY: float = 0.032
        EnglishTextSizeY: float = 0.032
    
        Setup():void=
            StartSubtitleTrigger.TriggeredEvent.Subscribe(OnStart)
    
        GetTextSize(STextInfo: subtitle_text):void=
     
            var MaxTextSizeX: float = 0.0
            var SumTextSizeY: float = 0.0
     
            for(Text: STextInfo.LineText):
     
                SizeX := GetTextSizeX(Text.Text)
                if(SizeX > MaxTextSizeX):
                    set MaxTextSizeX = SizeX
     
                SizeY := GetTextSizeY(Text.Text)
                set Text.LineHeight = SizeY
                set SumTextSizeY += SizeY
                
            set STextInfo.TextSizeX = MaxTextSizeX
            set STextInfo.TextSizeY = SumTextSizeY
     
        GetTextSizeX(String: string):float=
            var TextSize: float = 0.0
     
            for(Character : String):
                if(HalfChar.Find[Character]):
                    set TextSize += EnglishTextSizeX
                else:
                    set TextSize += JapaneseTextSizeX
     
            return TextSize
     
        GetTextSizeY(String: string):float=
            var TextSize: float = 0.0
     
            for(Character : String):
                if(HalfChar.Find[Character]):
                    set TextSize = EnglishTextSizeY
                else:
                    set TextSize = JapaneseTextSizeY
     
            return TextSize
    
        StartSubtitle(Agent: agent)<suspends>:void=
            if:
                not GlobalData.WidgetPerAgent[Agent], set GlobalData.WidgetPerAgent[Agent] = main_widget:
                    MaxHP := GlobalData.HPBar.MaxHP
                    BasePosition := GlobalData.HPBar.Position
                    SizePosition := GlobalData.HPBar.Size
                    OutlineSize := GlobalData.HPBar.OutlineSize
                    GlobalData := Self.GlobalData
                    PrevHP := GlobalData.HPBar.MaxHP
                    DamageEffectAmount := GlobalData.HPBar.DamageEffectAmount
                    HPBarBG := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.BackgroundColor)}
                    HPBarOutline := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.OutlineColor)}
                    HPBarBaseColor := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.BarColor)}
                    HPBarDamagedColor := color_block{DefaultColor := MakeColorFromHex(GlobalData.HPBar.DamageEffectColor)}
                    HPBarText := text_block{DefaultTextColor := MakeColorFromHex(GlobalData.HPBar.HPTextColor), DefaultJustification := text_justification.Center}
            if(WClass := GlobalData.WidgetPerAgent[Agent]):
                race:
                    block:
                        set WClass.IsDisplaySubtitle = true
                        for(STextInfo : SubtitleText):
    
                            set WClass.NowText = STextInfo
                            set WClass.NowTextPosition = Self.SubtitlePosition
    
                            GetTextSize(STextInfo)
                            WClass.UpdateUI(Agent)
                            STextInfo.Sound.Play(Agent)
                            Sleep(STextInfo.DisplayTime)
                        set WClass.NowText = subtitle_text{}
                        set WClass.IsDisplaySubtitle = false
                        WClass.UpdateUI(Agent)
                        EndEventTrigger.Trigger(Agent)
                    StartSubtitleTrigger.TriggeredEvent.Await()
    
        OnStart(MaybeAgent: ?agent):void=
            AllPlayers := GetPlayspace().GetPlayers()
            for(Player : AllPlayers):
                spawn{StartSubtitle(Player)}
    
    subtitle_text := class<concrete>:
        @editable
        LineText: []line_text = array{}
    
        @editable
        DisplayTime: float = 0.0
    
        @editable
        Sound: audio_player_device = audio_player_device{}
    
        var TextSizeX: float = 0.0
        var TextSizeY: float = 0.0
    
    line_text := class<concrete>:
        @editable
        Text: string = array{}
    
        var LineHeight: float = 0.0
    
    hp_bar := class<concrete>:
        @editable
        MaxHP: float = 0.0
    
        @editable
        Position: position = position{X := 0.5, Y := 0.1}
    
        @editable
        Size: position = position{X := 0.5, Y := 0.1}
    
        @editable
        OutlineSize: float = 0.01
    
        @editable
        HPTextColor: string = "FFFFFF"
    
        @editable
        BackgroundColor: string = "000000"
    
        @editable
        OutlineColor: string = "f0f8ff"
    
        @editable
        BarColor: string = "008000"
    
        @editable
        DamageEffectColor: string = "ff4500"
    
        @editable
        DamageEffectAmount: float = 100.0
    
        @editable
        EnableHPBarTrigger: trigger_device = trigger_device{}
    
        @editable
        DisableHPBarTrigger: trigger_device = trigger_device{}
    
        @editable
        ResetHPBarTrigger: trigger_device = trigger_device{}
    
        @editable
        ElimEvent: trigger_device = trigger_device{}
    
    position := class<concrete>:
        @editable
        X: type{_X:float where _X >= 0.0, _X <= 1.0} = 0.0
    
        @editable
        Y: type{_X:float where _X >= 0.0, _X <= 1.0} = 0.0
    
    global_data := class:
        var HPBar: hp_bar = hp_bar{}
    
        var NowHP: float = 0.0
    
        var WidgetPerAgent: [agent]main_widget = map{}
    
    damage_info := class<concrete>:
        @editable
        DamageAmount: float = 0.0
    
        @editable
        DamageTrigger: trigger_device = trigger_device{}
    
    main_widget := class:
    
        HPBarBG: color_block
        HPBarOutline: color_block
        HPBarBaseColor: color_block
        HPBarDamagedColor: color_block
        HPBarText: text_block
    
        var MaxHP: float
    
        BasePosition: position
        SizePosition: position
        OutlineSize: float
        DamageEffectAmount: float
    
        GlobalData: global_data
    
        var PrevHP: float = 0.0
    
        var NowText: subtitle_text = subtitle_text{}
        var NowTextPosition: position = position{}
    
        var NowTextBlock: []tuple(text_block, float) = array{}
    
        var IsDisplaySubtitle: logic = false
        var IsDisplayHPBar: logic = false
    
        var IsUpdating: logic = false
    
        var NowCanvas: ?canvas = false
    
        StringToMessage<localizes>(String: string):message="{String}"
    
        UpdateUI(Agent: agent)<suspends>:void=
            RemoveUI(Agent)
    
            HPBarText.SetText(StringToMessage("{ToTruncatedString(GlobalData.NowHP, 0)} / {ToTruncatedString(MaxHP, 0)}"))
            
            set NowTextBlock = for(Text : NowText.LineText):
                TextBlock := text_block{DefaultText := StringToMessage(Text.Text), DefaultTextColor := NamedColors.White}
                (TextBlock, Text.LineHeight)
     
            if(Player := player[Agent], PlayerUI := GetPlayerUI[Player]):
                var PrevCanvasSlots: []canvas_slot = array{}
    
                if(IsDisplaySubtitle?):
                    set PrevCanvasSlots += CreateSubtitle()
                if(IsDisplayHPBar?):
                    set PrevCanvasSlots += CreateHPBar()
    
                Canvas := canvas:
                    Slots :=  PrevCanvasSlots
    
                PlayerUI.AddWidget(Canvas)
                set NowCanvas = option{Canvas}
    
                spawn{UpdatePrevHP(Agent)}
    
        UpdatePrevHP(Agent: agent)<suspends>:void=
            if(IsUpdating?):
                return
    
            set IsUpdating = true
            loop:
                Diff := GlobalData.NowHP - PrevHP
                if(Diff >= 0.0):
                    set PrevHP = GlobalData.NowHP
                    set IsUpdating = false
                    break
                else if(Value := Int[(Diff / DamageEffectAmount)]):
                    set PrevHP += Value*1.0
                UpdateUI(Agent)
                Sleep(0.0)
        
        RemoveUI(Agent: agent):void=
            if(Player := player[Agent], PlayerUI := GetPlayerUI[Player], Canvas := NowCanvas?):
                PlayerUI.RemoveWidget(Canvas)
                set NowCanvas = false
    
        CreateHPBar():[]canvas_slot=
            if(GlobalData.NowHP <= 0.0):
                set GlobalData.NowHP = 0.0
            if(PrevHP <= 0.0):
                set PrevHP = 0.0
    
            var NowPercent: float = GlobalData.NowHP / MaxHP
            if(GlobalData.NowHP <= 0.0):
                set NowPercent = 0.0
    
    
            NowPercentPosition: float = Lerp(BasePosition.X - SizePosition.X / 2.0, BasePosition.X + SizePosition.X / 2.0, NowPercent)
            
            var PrevPercent: float = PrevHP / MaxHP
            if(PrevHP <= 0.0):
                set PrevPercent = 0.0
            PrevPercentPosition: float = Lerp(BasePosition.X - SizePosition.X / 2.0, BasePosition.X + SizePosition.X / 2.0, PrevPercent)
    
            var CanvasSlots: []canvas_slot = array{}
    
            set CanvasSlots += array:
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := BasePosition.X, Y := BasePosition.Y} - (vector2{X := SizePosition.X, Y := SizePosition.Y} / 2.0) - vector2{X := OutlineSize, Y := OutlineSize}, Maximum := vector2{X := BasePosition.X, Y := BasePosition.Y} + (vector2{X := SizePosition.X, Y := SizePosition.Y} / 2.0) + vector2{X := OutlineSize, Y := OutlineSize}}
                    Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    SizeToContent := true
                    Widget := HPBarOutline
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := BasePosition.X, Y := BasePosition.Y} - (vector2{X := SizePosition.X, Y := SizePosition.Y} / 2.0), Maximum := vector2{X := BasePosition.X, Y := BasePosition.Y} + (vector2{X := SizePosition.X, Y := SizePosition.Y} / 2.0)}
                    Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    SizeToContent := true
                    Widget := HPBarBG
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := BasePosition.X, Y := BasePosition.Y} - (vector2{X := SizePosition.X, Y := SizePosition.Y} / 2.0), Maximum := vector2{Y := BasePosition.Y} + vector2{Y := (SizePosition.Y / 2.0), X := PrevPercentPosition}}
                    Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    SizeToContent := false
                    Widget := HPBarDamagedColor
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := BasePosition.X, Y := BasePosition.Y} - (vector2{X := SizePosition.X, Y := SizePosition.Y} / 2.0), Maximum := vector2{Y := BasePosition.Y} +  vector2{Y := (SizePosition.Y / 2.0), X:= NowPercentPosition}}
                    Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    SizeToContent := false
                    Widget := HPBarBaseColor
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := BasePosition.X, Y := BasePosition.Y},  Maximum := vector2{X := BasePosition.X, Y := BasePosition.Y}}
                    Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    SizeToContent := false
                    Widget := HPBarText
    
            
            CanvasSlots
                
        CreateSubtitle():[]canvas_slot=
            Background: color_block = color_block{DefaultOpacity := 0.75, DefaultColor := NamedColors.Black}
    
            var NowLineHeight: float = 0.0
            for(Text: NowText.LineText):
                set NowLineHeight += Text.LineHeight
    
            var CanvasSlots: []canvas_slot = array{}
    
            set CanvasSlots += array:
                canvas_slot:
                    Anchors := anchors{Minimum := vector2{X := NowTextPosition.X, Y := NowTextPosition.Y} - vector2{X := (NowText.TextSizeX / 2.0) + 0.01, Y := NowText.TextSizeY + 0.03}, Maximum := vector2{X := NowTextPosition.X, Y := NowTextPosition.Y} + vector2{X := (NowText.TextSizeX / 2.0) + 0.01}}
                    Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    SizeToContent := true
                    Widget := Background
    
            for(Index -> TextBlock : NowTextBlock):
                set CanvasSlots += array:
                    canvas_slot:
                        Anchors := anchors{Minimum := vector2{X := NowTextPosition.X, Y := NowTextPosition.Y} - vector2{Y := NowLineHeight}, Maximum := vector2{X := NowTextPosition.X, Y := NowTextPosition.Y} - vector2{Y := NowLineHeight}}
                        Offsets := margin{Top := 0.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                        Alignment := vector2{X := 0.5, Y := 0.5}
                        SizeToContent := true
                        Widget := TextBlock(0)
        
                set NowLineHeight -= if(Value := NowText.LineText[Index].LineHeight). Value else. 0.0
    
            CanvasSlots
    
    ToTruncatedString<public>(Number:float, Decimals:int):[]char=
        var Str:[]char = ToString(Number)
        if:
            DotIndex := Str.Find['.']
            StopIndex := if (Decimals > 0) then Min(DotIndex+Decimals+1,Str.Length) else DotIndex
            set Str = Str.Slice[0, StopIndex] 
        Str