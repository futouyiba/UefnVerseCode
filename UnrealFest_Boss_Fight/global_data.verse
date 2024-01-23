using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }

# Store players globally so any device can easily access important data
var GlobalData : weak_map(session, [player]game_player) = map{}

# A simply wrapper function to get the game players
GamePlayers()<transacts>:[player]game_player=
    var Players : [player]game_player = map{}
    if (set Players = GlobalData[GetSession()]) {}
    Players