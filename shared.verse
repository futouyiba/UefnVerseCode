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
