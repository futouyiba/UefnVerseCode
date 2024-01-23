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

# logger that can used in <transacts> and <decides> functions
my_log_channel<public> := class(log_channel):

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

MakeMessageFromString<localizes>(Text: string): message = "{Text}"

# Removes an element from the given map and returns a new map without that element
RemoveKeyFromMap(ExampleMap:[string]int, ElementToRemove:string):[string]int=
    var NewMap:[string]int = map{}
    # Concatenate Keys from ExampleMap into NewMap, excluding ElementToRemove
    for (Key -> Value : ExampleMap, Key <> ElementToRemove):
        set NewMap = ConcatenateMaps(NewMap, map{Key => Value})
    return NewMap

        
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