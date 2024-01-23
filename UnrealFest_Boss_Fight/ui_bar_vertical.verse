using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Assets }
using { /UnrealEngine.com/Temporary/SpatialMath}
using { /Verse.org/Colors}

# Example usage:
# OnBegin<override>()<suspends>:void=
#     spawn{VerticalTest()}
    
# VerticalTest()<suspends>:void=
#     for (Player : GetPlayspace().GetPlayers()):
#         var Percent : float = 0.0
#         loop:
#             Sleep(0.0)
#             VerticalProgressUI := ui_bar_vertical{Player := Player}
#             VerticalProgressUI.UpdateProgress(Percent)
#             if (Percent >= 100.0) { break }
#             set Percent += 0.1

ui_bar_vertical:= class:
    Player : player

    BAR_HEIGHT<private> : float = 500.0

    var MoveBar<private> : ?overlay_slot = false
    var MainWidget<private> : ?canvas = false

    # To increase performance, we only store these so we don't have to 
    # re-create them every time we update the bar
    var MoveBarColor<private> : ?color_block = false
    var HeightBarColor<private> : ?color_block = false

    UpdateProgress(Percent : float):void=
        
        HeightValue := BAR_HEIGHT * (Percent / 100.0)

        if (PlayerUI := GetPlayerUI[Player]):
            if (MW := MainWidget?) { PlayerUI.RemoveWidget(MW)}
            W := UpdateCanvas(margin{Bottom := HeightValue})
            PlayerUI.AddWidget(W)
            set MainWidget = option{W}


    UpdateCanvas<private>(MoveBarPadding : margin)<transacts> : canvas=

        BAR_WIDTH := 100.0
        
        # This is the height box. You can swap this out with a texture if you want
        # Or simply set opacity to 0.0 to have no background at all
        var HeightBar : color_block = color_block{
            DefaultColor := MakeColorFromHex("FFFFFF")
            DefaultOpacity := 1.0
            DefaultDesiredSize := vector2{X:=BAR_WIDTH, Y:=BAR_HEIGHT}
        }

        # Only create new widget on first time load
        if (HB := HeightBarColor?):
            set HeightBar = HB
        
        var MoveBarBlock : color_block = color_block{
            DefaultColor := MakeColorFromHex("c81c12")
            DefaultDesiredSize := vector2{X:=BAR_WIDTH, Y:=10.0}}

        # Only create new widget on first time load
        if (MB := MoveBarColor?):
            set MoveBarBlock = MB

        MoveBarTemp := overlay_slot{
            Padding := MoveBarPadding
            Widget := MoveBarBlock
            VerticalAlignment := vertical_alignment.Bottom
        }

        # Since we are adjusting padding, this has to be recreated every time
        # because we don't have a SetPadding option
        set MoveBar = option{MoveBarTemp}


        canvas:
            Slots := array:
                canvas_slot :
                    Anchors := anchors{Minimum := vector2{X := 0.0, Y := 0.5}, Maximum := vector2{X := 0.0, Y := 0.5}}
                    Offsets := margin{Top := 0.0, Left := 30.0, Right := 0.0, Bottom := 0.0}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    Widget := overlay:
                        Slots := array:
                            overlay_slot:
                                Widget := HeightBar
                            MoveBarTemp
                            