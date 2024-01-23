
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using {/Fortnite.com/Teams}

# See https://dev.epicgames.com/documentation/en-us/uefn/create-your-own-device-in-verse for how to create a verse device.

# 用于测试更换队伍。0818测试成功，不会被respawn。此装置理论上可以删除。
team_switch_device := class(creative_device):

    @editable Button1: button_device := button_device{}
    @editable Button2: button_device := button_device{}
    var Teams: []team = array{}

    # Runs when the device is started in a running game
    OnBegin<override>()<suspends>:void=
        # TODO: Replace this with your code
        Print("Hello, world!")
        Print("2 + 2 = {2 + 2}")
        set Teams = Self.GetPlayspace().GetTeamCollection().GetTeams()
        Button1.InteractedWithEvent.Subscribe(OnButton1Interacted)
        Button2.InteractedWithEvent.Subscribe(OnButton2Interacted)

    OnButton1Interacted(Interactor:agent):void=
        Print("Button1 was interacted with...")
        if:
            Player:=player[Interactor],
            GetPlayspace().GetTeamCollection().AddToTeam[Player, Teams[1]]
        then:
            Print("Player was added to team [1]")
        else:
            Print("add team failed")
        PrintIsOnFirstTeam(Interactor)

    OnButton2Interacted(Interactor:agent):void=
        Print("Button2 was interacted with...")
        if:
            Player:=player[Interactor],
            GetPlayspace().GetTeamCollection().AddToTeam[Player, Teams[0]]
        then:
            Print("Player was added to team [0]")
        else:
            Print("add team failed")
        PrintIsOnFirstTeam(Interactor)

    PrintEveryTeamLength():void=
        for (Team: Teams):
            # Print("Team {Self.GetPlayspace().GetTeamCollection().} has {Team.GetAgents(Team).Length()} players")

    PrintIsOnFirstTeam(Agent:agent):void=
        PlaySpace:= Self.GetPlayspace()
        TeamCollection:= PlaySpace.GetTeamCollection()
        if:
            Team:= TeamCollection.GetTeams()[0]
            TeamCollection.IsOnTeam[Agent, Team]
        then:
            Print("Agent is on first team")
        else:
            Print("Agent is not on first team")