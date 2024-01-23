using { /UnrealEngine.com/Temporary/UI }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Assets }
using { /UnrealEngine.com/Temporary/SpatialMath}
using { /Verse.org/Colors}

ui_boss_bar := class():
    Player : player

    BAR_FULL_WIDTH<private> : float = 700.0
    BAR_HEIGHT<private> : float = 127.0

    # Updateable Widgets
    var BarFillBlock<private> : ?texture_block = false

    # Textures
    BarBorder<private> : texture = Textures.bar_border
    BarBG<private> : texture = Textures.bar_background
    BarFill<private> : texture = Textures.bar_fill
    
    var BarColorFill<private> : color_block = color_block{DefaultColor := MakeColorFromHex("c81c12")}
    var BarTemp<private> : color_block = color_block{DefaultColor := MakeColorFromHex("c81c12")}
    var MainWidget<private> : ?canvas = false

    Start()<suspends>:void=
        Show()

        if (HPBar := BarFillBlock?):
            DURATION := 2.0
            StartTime: float = GetSimulationElapsedTime()
            INITIAL_PERCENT := 0.0

            loop:
                CurrentTime: float = GetSimulationElapsedTime() - StartTime
                Progress: float = Min(CurrentTime / DURATION, 1.0)
                
                PERCENT := INITIAL_PERCENT + (100.0 - INITIAL_PERCENT) * Progress
                UpdateProgressBar(PERCENT)
                
                if (Progress >= 1.0) { break }
                
                Sleep(0.0)
            
            

    UpdateProgressBar(BarPercent : float):void=
        if (Bar := BarFillBlock?):
            Bar.SetDesiredSize(vector2{X:=BAR_FULL_WIDTH * (BarPercent / 100.0), Y:=BAR_HEIGHT})
            BarTemp.SetDesiredSize(vector2{X:=BAR_FULL_WIDTH * (BarPercent / 100.0), Y:=38.0})


    Show():void=
        if (not MainWidget?):
            Create()


    Hide():void=
        if (PlayerUI := GetPlayerUI[Player], Widget := MainWidget?):
            PlayerUI.RemoveWidget(Widget)
            set MainWidget = false


    Create<private>():void=
        if (PlayerUI := GetPlayerUI[Player]):
            if (MW := MainWidget?):
                PlayerUI.RemoveWidget(MW)
                set MainWidget = false

            W := CreateBaseCanvas()
            set MainWidget = option{W}
            UpdateProgressBar(0.0)
            PlayerUI.AddWidget(W)

    CreateBaseCanvas()<transacts> : canvas=

        ColorSlot := color_block{
            DefaultColor := MakeColorFromHex("c81c12")
            DefaultDesiredSize := vector2{X:=BAR_FULL_WIDTH, Y:=BAR_HEIGHT}}

        set BarColorFill = ColorSlot

        BarBGSlot := texture_block{
            DefaultImage := BarBG,
            DefaultDesiredSize := vector2{X:=700.0, Y:=127.0}}

        BarFillBlockTemp := texture_block{
            DefaultVerticalTiling := image_tiling.Stretch,
            DefaultHorizontalTiling := image_tiling.Stretch,
            DefaultImage := BarFill,
            DefaultDesiredSize := vector2{X:=BAR_FULL_WIDTH, Y:=BAR_HEIGHT}}
   
        # Save the widget so we can update it later
        set BarFillBlock = option{BarFillBlockTemp}


        BarBorderSlot := texture_block{
            DefaultImage := BarBorder,
            DefaultDesiredSize := vector2{X:=700.0, Y:=127.0}}

         canvas:
            Slots := array:
                canvas_slot :
                    Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.0}, Maximum := vector2{X := 0.5, Y := 0.0}}
                    Offsets := margin{Top := 90.0, Left := 0.0, Right := 0.0, Bottom := 0.0}
                    Alignment := vector2{X := 0.5, Y := 0.5}
                    Widget := overlay:
                        Slots := array:
                            overlay_slot:
                                HorizontalAlignment := horizontal_alignment.Center
                                Widget := BarBGSlot
                            overlay_slot:
                                HorizontalAlignment := horizontal_alignment.Left
                                Widget := BarFillBlockTemp 
                                Padding := margin{Top := 0.0, Left := 10.0}
                            overlay_slot:
                                HorizontalAlignment := horizontal_alignment.Center
                                Widget := BarBorderSlot
                                    


            
