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
