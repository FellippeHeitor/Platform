' One-button auto-runner engine.
' Runs in QB64-PE and in QBJS (no QBJS-specific code needed).
'
' Hold to jump higher, tap for a short hop. Levels are hand-made and fixed,
' so every attempt is the same course: learn it, die, retry.
'
' Controls: SPACE / mouse button / touch = jump, R = restart attempt,
'           M = mute, ESC = back to title (ESC on title quits)
'
' Level check (native only): compile levelcheck.bas, which includes this
' file with HEADLESS set plus tools/solver.bm, and proves every level can be
' beaten by searching all button timings through the same physics code.

Option _Explicit

Const TRUE = -1
Const FALSE = 0

Const SW = 800
Const SH = 450
Const TILE = 25
Const ROWS = 18
Const WATER_Y = 438

' tile codes
Const T_EMPTY = 0
Const T_GROUND = 1
Const T_PLANK = 2
Const T_SPIKE = 3
Const T_SPIKEDOWN = 4
Const T_LAVA = 5
Const T_GEM = 6
Const T_TOGGLEA = 7
Const T_TOGGLEB = 8
Const T_SWITCH = 9
Const T_BARRIER = 10
Const T_TELEIN = 11
Const T_TELEOUT = 12
Const T_JET = 13
Const T_WINGS = 14
Const T_NORMAL = 15
Const T_GOAL = 16

' hero modes
Const MODE_RUN = 0
Const MODE_JET = 1
Const MODE_WINGS = 2

' physics, per 1/60 s tick
Const STEP_DT = 1 / 60
Const RUN_SPEED = 4
Const GRAVITY = 0.6
Const JUMP_V = 10.2
Const CUT_V = 4
Const AIR_JUMP_V = 9
Const MAX_FALL = 12
Const FLAP_V = 5.5
Const JET_GRAVITY = 0.35
Const COYOTE_TICKS = 5
Const BUFFER_TICKS = 7
Const STEP_TOL = 7
Const HERO_W = 14
Const HERO_H = 20
Const TOGGLE_TICKS = 50
Const MAX_GEMS = 30

' death causes
Const DIE_NONE = 0
Const DIE_CRASH = 1
Const DIE_SPIKE = 2
Const DIE_LAVA = 3
Const DIE_WATER = 4

' simulation events, for effects and sound (bit flags)
Const EV_JUMP = 1
Const EV_AIRJUMP = 2
Const EV_LAND = 4
Const EV_GEM = 8
Const EV_SWITCH = 16
Const EV_TELEPORT = 32
Const EV_MODE = 64
Const EV_FLAP = 128

' sound effects (files in sfx/, made by tools/make_sfx.bas)
Const SFX_JUMP = 1
Const SFX_AIRJUMP = 2
Const SFX_FLAP = 3
Const SFX_GEM = 4
Const SFX_SWITCH = 5
Const SFX_TELEPORT = 6
Const SFX_MODE = 7
Const SFX_DIE = 8
Const SFX_WIN = 9
Const SFX_ARRIVE = 10

' presentation timings, in ticks
Const TELE_TICKS = 42 ' teleport: beam out, camera glides, beam in
Const POP_TICKS = 90 ' pickup label

' game states
Const ST_TITLE = 0
Const ST_PLAY = 1
Const ST_DEAD = 2
Const ST_WON = 3
Const ST_END = 4

Type HeroState
    x As Single
    y As Single
    yv As Single
    airJumps As Long
    mode As Long
    grounded As Long
    coyote As Long
    buffer As Long
    heldPrev As Long
    jumping As Long
    barriersOn As Long
    gemMask As Long
    alive As Long
    won As Long
    cause As Long
End Type

Type Theme
    skyTop As _Unsigned Long
    skyBottom As _Unsigned Long
    hillFar As _Unsigned Long
    hillNear As _Unsigned Long
    ground As _Unsigned Long
    groundDark As _Unsigned Long
    grass As _Unsigned Long
    water As _Unsigned Long
    stars As Long
    hotSea As Long
End Type

Type Particle
    x As Single
    y As Single
    xv As Single
    yv As Single
    life As Single
    maxLife As Single
    size As Single
    c As _Unsigned Long
End Type

Type Cloud
    x As Single
    y As Single
    w As Single
    speed As Single
End Type

' level
Dim Shared levelCount As Long, levelNum As Long, levelName As String
Dim Shared levelTheme As Long, levelCols As Long
ReDim Shared tiles(0, 0) As Long, gemIndex(0, 0) As Long
ReDim Shared teleCol(0, 0) As Long, teleRow(0, 0) As Long
Dim Shared startX As Single, startY As Single, goalX As Single, goalRow As Long
Dim Shared hero As HeroState, simTick As Long, simEvents As Long
Dim Shared headless As Long

' presentation
Dim Shared themes(0 To 3) As Theme, th As Theme
Dim Shared levelImg As Long, skyImg As Long, farImg As Long, nearImg As Long
Dim Shared heroImg(0 To 5) As Long
Dim Shared particles(1 To 300) As Particle
Dim Shared clouds(1 To 8) As Cloud
Dim Shared camX As Single, shake As Single, squash As Single, frameCount As Long
Dim Shared gameState As Long, stateTicks As Long, muted As Long
Dim Shared deathsTotal As Long, levelDeaths As Long, attempt As Long
Dim Shared bestPct(1 To 99) As Long, lastPct As Long, deathCause As Long
Dim Shared titleLevel As Long, sounds(1 To 10) As Long
Dim Shared popText As String, popHint As String, popLife As Long, popColor As _Unsigned Long
Dim Shared teleT As Long, teleFromX As Single, teleFromY As Single
Dim Shared teleCamFrom As Single, teleCamTo As Single

Randomize Timer
countLevels

$If HEADLESS = 1 Then
    runLevelCheck ' see levelcheck.bas
$End If

Screen _NewImage(SW, SH, 32)
_Title "Leap Line"
initThemes
initHeroSprites
loadSounds
titleLevel = 1
loadLevel titleLevel
gameState = ST_TITLE

Dim held As Long, heldFrame As Long, pressLatch As Long, k As Long
Dim lastTime As Double, now As Double, acc As Double, dt As Double
lastTime = Timer(.001)

Do
    ' input: any of space, mouse button or touch. Latch presses so a tap that
    ' starts and ends between two physics ticks is still seen.
    While _MouseInput: Wend
    heldFrame = (_MouseButton(1) <> 0) Or _KeyDown(32)
    If heldFrame Then pressLatch = TRUE

    k = _KeyHit
    Select Case k
        Case 27
            If gameState = ST_TITLE Then System
            gameState = ST_TITLE
            loadLevel titleLevel
        Case 77, 109 ' M
            muted = Not muted
        Case 82, 114 ' R
            If gameState = ST_PLAY Or gameState = ST_DEAD Then resetAttempt
        Case 19200 ' left
            If gameState = ST_TITLE And titleLevel > 1 Then titleLevel = titleLevel - 1: loadLevel titleLevel
        Case 19712 ' right
            If gameState = ST_TITLE And titleLevel < levelCount Then titleLevel = titleLevel + 1: loadLevel titleLevel
    End Select

    now = Timer(.001)
    dt = now - lastTime
    If dt < 0 Then dt = dt + 86400 ' midnight
    If dt > .25 Then dt = .25
    lastTime = now
    acc = acc + dt

    Do While acc >= STEP_DT
        held = heldFrame Or pressLatch
        pressLatch = FALSE
        updateGame held
        acc = acc - STEP_DT
    Loop

    render
    _Display
    _Limit 120
Loop

'=============================================================================
' LEVEL DATA
'=============================================================================
' Level data: count, then per level: name, theme, 18 rows (top to bottom).
' . empty  # ground  = plank (one-way)  ^ spike  v hanging spike  L lava
' * diamond (air jump)  T/t alternating spikes  S switch  B barrier
' O teleporter  o teleporter exit  J jetpack  W wings  N back to normal
' @ start  G goal
Data 6
Data "First Steps",0
Data "......................................................................................................................................................................."
Data "......................................................................................................................................................................."
Data "......................................................................................................................................................................."
Data "......................................................................................................................................................................."
Data "......................................................................................................................................................................."
Data "......................................................................................................................................................................."
Data "......................................................................................................................................................................."
Data "......................................................................................................................................................................."
Data "......................................................................................................................................................................."
Data "......................................................................................................................................................................."
Data "......................................................................................................................................................................."
Data "......................................................................................................................................................................."
Data "......................................................................................................................................................................."
Data "................................................................................................####........................###........................................"
Data "................................#######...........................###.....................##########........................###........................................"
Data "...@....................###############...########................###...........########..################...######....########......................G................."
Data "##############..#######################...##############...#################....########..################...######....##############....##############################"
Data "##############..#######################...##############...#################....########..################...######....##############....##############################"
Data "Sharp Ideas",0
Data "....................................................................................................................................................................."
Data "....................................................................................................................................................................."
Data "....................................................................................................................................................................."
Data "....................................................................................................................................................................."
Data "....................................................................................................................................................................."
Data "....................................................................................................................................................................."
Data "....................................................................................................................................................................."
Data "....................................................................................................................................................................."
Data "....................................................................................................................................................................."
Data "....................................................................................................................................................................."
Data "................................................................^..............................................................^....^................................"
Data ".............................................................######..........................................................##########.............................."
Data ".............................................................vvvvvv..........................................................vvvvvvvvvv.............................."
Data "...........................................................................................................^^........................................................"
Data "...........................................^......................................^....^.......#####...##########...................................................."
Data "...@...............^........^^.......##########...^^^...........................#########......#####...##########.^................................G................."
Data "##################################...########################################...####################...##############################################################"
Data "##################################...########################################...####################...##############################################################"
Data "Plank Walk",1
Data "...................................................................................................................................................................................."
Data "...................................................................................................................................................................................."
Data "...................................................................................................................................................................................."
Data "...................................................................................................................................................................................."
Data "...................................................................................................................................................................................."
Data "...................................................................................................................................................................................."
Data "...................................................................................................................................................................................."
Data "...................................................................................................................................................................................."
Data "...................................................................................................................................................................................."
Data "...................................................................................................................................................................................."
Data "...................................................................................................................................................................................."
Data "...................................................................................................................................................................................."
Data "..........................................................................................======.......^............................................................................"
Data ".................................======..........................................======............=========........................................................................"
Data "........................======............=====...................####.........................................=====...=====....................=====...=====......................."
Data "...@...........======.............................======...####...####...#####.................................................=====..............................G................."
Data "############...............................................####...####...#####.........................................................######...................####################"
Data "############...............................................####...####...#####.........................................................######...................####################"
Data "Diamond Skies",2
Data "........................................................................................................................................................."
Data "........................................................................................................................................................."
Data "........................................................................................................................................................."
Data "........................................................................................................................................................."
Data "........................................................................................................................................................."
Data "........................................................................................................................................................."
Data "........................................................................................................................................................."
Data "........................................................................................................................................................."
Data "........................................................................................................................................................."
Data "........................................................................................................................................................."
Data "........................................................................................................................................................."
Data "........................................................................................................................................................."
Data ".............................................................................................................*..........................................."
Data ".............................................................*.....................................................####.................................."
Data "......................................*...........................................................^................####.................................."
Data "...@...........*..................######........########......................*.*............##########............####................G................."
Data "##################........##############........############........##############...........##############........####....##############################"
Data "##################LLLLLLLL##############LLLLLLLL############LLLLLLLL##############LLLLLLLLLLL##############LLLLLLLL####LLLL##############################"
Data "Clockwork",3
Data "................................................................................................................................................"
Data "................................................................................................................................................"
Data "................................................................................................................................................"
Data "................................................................................................................................................"
Data "................................................................................................................................................"
Data "................................................................................................................................................"
Data "...................................................................####........................................................................."
Data "...................................................................####........................................................................."
Data "...................................................................####........................................................................."
Data "...................................................................####........................................................................."
Data "...................................................................####.............................................B...B......................."
Data ".............................................B.....................####...........o.................................B...B......................."
Data ".............................................B.....................####.........##########..........................B...B......................."
Data "....................................S........B.....................####.........##########...................S......B...B......................."
Data ".............................................B........T..t......O..####.........################....................B...B......................."
Data "...@............TT.......ttTT................B.....#######################......################..tt..TT............B...B.....G................."
Data "################################################...#######################......################################################################"
Data "################################################...#######################......################################################################"
Data "Lift Off",1
Data "................############################################################...................................................................................."
Data ".......................##......##......##......##......##......##......##......................................................................................."
Data ".......................##......##......##......##......##......##......##......................................................................................."
Data ".......................##......##......##......##......##......##......##......................................................................................."
Data ".......................##......##......##......##......##......##......##......................................................................................."
Data ".......................##......##......##......##......##......vv......##......................................................................................."
Data ".......................##......##......##......vv......##..............##......................................................................................."
Data ".......................##......vv......##..............##..............##......................................................................................."
Data ".......................##..............##..............vv..............vv......................................................................................."
Data ".......................vv..............vv......................................................................................................................."
Data ".............................................................................................................^.................................................."
Data "...........................................................................................................................^...................................."
Data "...............................................................##..............................................................................................."
Data "...............................................##..............##..............................................................................................."
Data "...............................##..............##..............##...................................^................^.........................................."
Data "...@..........J................##..............##......##......##......##......N....W..........................................N........^.....G................."
Data "#####################^^##^^^^^^##^^^^^^##^^^^^^##^^^^^^##^^^^^^##^^^^^^##^^^##########........................................##################################"
Data "######################################################################################........................................##################################"

'=============================================================================
' GAME FLOW
'=============================================================================

Sub updateGame (held As Long)
    Static prevHeld As Long
    Dim fresh As Long, prevX As Single, prevY As Single
    fresh = held And Not prevHeld
    prevHeld = held
    stateTicks = stateTicks + 1
    frameCount = frameCount + 1

    Select Case gameState
        Case ST_TITLE
            ' attract mode: scroll the camera along the level
            camX = camX + 1.5
            If camX > levelCols * TILE - SW Then camX = 0
            If fresh Then
                levelDeaths = 0
                resetAttempt
                gameState = ST_PLAY
            End If

        Case ST_PLAY
            If teleT > 0 Then
                ' the world waits while the teleport plays out; simTick
                ' doesn't advance, so the level checker's results still hold
                updateTeleport
            Else
                prevX = hero.x: prevY = hero.y
                simTick = simTick + 1
                simEvents = 0
                simStep hero, held
                handleEvents
                If simEvents And EV_TELEPORT Then startTeleport prevX + RUN_SPEED, prevY
                If popLife > 0 Then popLife = popLife - 1
                If Not hero.alive Then
                    deathsTotal = deathsTotal + 1
                    levelDeaths = levelDeaths + 1
                    lastPct = progressPct
                    If lastPct > bestPct(levelNum) Then bestPct(levelNum) = lastPct
                    deathCause = hero.cause
                    burst hero.x + HERO_W / 2, hero.y + HERO_H / 2, 40, _RGB32(255, 255, 255)
                    burst hero.x + HERO_W / 2, hero.y + HERO_H / 2, 20, _RGB32(230, 70, 70)
                    shake = 10
                    sfx SFX_DIE
                    gameState = ST_DEAD
                    stateTicks = 0
                ElseIf hero.won Then
                    bestPct(levelNum) = 100
                    burst goalX, hero.y, 60, _RGB32(255, 230, 90)
                    sfx SFX_WIN
                    gameState = ST_WON
                    stateTicks = 0
                End If
                If teleT = 0 Then followCamera
            End If

        Case ST_DEAD
            ' a short pause so a held button doesn't skip the result
            If fresh And stateTicks > 15 Then resetAttempt: gameState = ST_PLAY

        Case ST_WON
            If fresh And stateTicks > 40 Then
                If levelNum < levelCount Then
                    titleLevel = levelNum + 1
                    loadLevel titleLevel
                    levelDeaths = 0
                    resetAttempt
                    gameState = ST_PLAY
                Else
                    gameState = ST_END
                    stateTicks = 0
                End If
            End If

        Case ST_END
            If fresh And stateTicks > 40 Then
                titleLevel = 1
                loadLevel 1
                gameState = ST_TITLE
            End If
    End Select

    updateParticles
    updateClouds
    shake = shake * .85
    If shake < .3 Then shake = 0
    If squash > .08 Then
        squash = squash - .08
    ElseIf squash < -.08 Then
        squash = squash + .08
    Else
        squash = 0
    End If
End Sub

Sub resetAttempt
    attempt = attempt + 1
    initHero hero
    simTick = 0
    squash = 0
    teleT = 0
    popLife = 0
    camX = 0
    followCamera
    stateTicks = 0
    gameState = ST_PLAY
End Sub

Function progressPct&
    Dim p As Single
    p = (hero.x - startX) / (goalX - startX) * 100
    If p < 0 Then p = 0
    If p > 100 Then p = 100
    progressPct& = Int(p)
End Function

Sub followCamera
    camX = hero.x - SW * .28
    If camX < 0 Then camX = 0
    If camX > levelCols * TILE - SW Then camX = levelCols * TILE - SW
End Sub

Sub handleEvents
    Dim cx As Single, by As Single
    cx = hero.x + HERO_W / 2
    by = hero.y + HERO_H
    If simEvents And EV_JUMP Then squash = -.6: dust cx, by, 5: sfx SFX_JUMP
    If simEvents And EV_AIRJUMP Then squash = -.6: ring cx, by, _RGB32(120, 230, 255): sfx SFX_AIRJUMP
    If simEvents And EV_FLAP Then squash = -.4: dust cx, by, 3: sfx SFX_FLAP
    If simEvents And EV_LAND Then squash = .7: dust cx, by, 6
    If simEvents And EV_GEM Then
        ring cx, hero.y, _RGB32(120, 230, 255): sfx SFX_GEM
        showPopup "+1 AIR JUMP", "press again in mid-air", _RGB32(120, 230, 255)
    End If
    If simEvents And EV_SWITCH Then
        shake = 4: sfx SFX_SWITCH
        showPopup "SWITCH!", "barriers down", _RGB32(255, 210, 60)
    End If
    If simEvents And EV_MODE Then
        sfx SFX_MODE
        Select Case hero.mode
            Case MODE_JET
                ring cx, hero.y + HERO_H / 2, _RGB32(255, 150, 60)
                showPopup "JETPACK", "every tap is a flap", _RGB32(255, 160, 80)
            Case MODE_WINGS
                ring cx, hero.y + HERO_H / 2, _RGB32(130, 240, 150)
                showPopup "WINGS", "jump as often as you like", _RGB32(140, 245, 160)
            Case Else
                ring cx, hero.y + HERO_H / 2, _RGB32(170, 210, 255)
                showPopup "ON FOOT", "normal jumps again", _RGB32(180, 215, 255)
        End Select
    End If
End Sub

Sub showPopup (t As String, hint As String, c As _Unsigned Long)
    popText = t: popHint = hint: popColor = c
    popLife = POP_TICKS
End Sub

' The simulation has already moved the hero; this only stages it on screen.
Sub startTeleport (fromX As Single, fromY As Single)
    teleT = TELE_TICKS
    teleFromX = fromX: teleFromY = fromY
    teleCamFrom = camX
    followCamera
    teleCamTo = camX
    camX = teleCamFrom
    ring fromX + HERO_W / 2, fromY + HERO_H / 2, _RGB32(220, 120, 255)
    sfx SFX_TELEPORT
End Sub

Sub updateTeleport
    Dim p As Single, q As Single
    teleT = teleT - 1
    p = teleProgress
    ' camera glides between the beam-out and beam-in, easing in and out
    q = (p - .3) / .45
    If q < 0 Then q = 0
    If q > 1 Then q = 1
    camX = teleCamFrom + (teleCamTo - teleCamFrom) * q * q * (3 - 2 * q)
    If p < .3 Then sparkle teleFromX + HERO_W / 2, teleFromY + HERO_H / 2
    If p > .75 Then sparkle hero.x + HERO_W / 2, hero.y + HERO_H / 2
    If teleT = Int(TELE_TICKS * .25) Then
        ring hero.x + HERO_W / 2, hero.y + HERO_H / 2, _RGB32(220, 120, 255)
        sfx SFX_ARRIVE
    End If
    If teleT = 0 Then followCamera
End Sub

Function teleProgress!
    teleProgress! = 1 - teleT / TELE_TICKS
End Function

'=============================================================================
' SIMULATION
' Everything that decides life or death lives in initHero/simStep and reads
' only `tiles()` and the HeroState passed in, so the solver can run it too.
'=============================================================================

Sub initHero (h As HeroState)
    h.x = startX
    h.y = startY
    h.yv = 0
    h.airJumps = 0
    h.mode = MODE_RUN
    h.grounded = TRUE
    h.coyote = 0
    h.buffer = 0
    h.heldPrev = TRUE ' the press that started this attempt must not also jump
    h.jumping = FALSE
    h.barriersOn = TRUE
    h.gemMask = 0
    h.alive = TRUE
    h.won = FALSE
    h.cause = DIE_NONE
End Sub

Sub simStep (h As HeroState, held As Long)
    Dim pressed As Long, wasGrounded As Long, prevBottom As Single
    Dim i As Long, landY As Single, ceilY As Single

    pressed = held And Not h.heldPrev
    h.heldPrev = held
    If pressed Then h.buffer = BUFFER_TICKS

    ' --- jump input
    If h.mode = MODE_JET Then
        If pressed Then h.yv = -FLAP_V: h.buffer = 0: simEvents = simEvents Or EV_FLAP
    Else
        If h.buffer > 0 And (h.grounded Or h.coyote > 0) Then
            h.yv = -JUMP_V
            h.buffer = 0
            h.coyote = 0
            h.grounded = FALSE
            h.jumping = TRUE
            simEvents = simEvents Or EV_JUMP
        ElseIf pressed And Not h.grounded And (h.airJumps > 0 Or h.mode = MODE_WINGS) Then
            If h.mode <> MODE_WINGS Then h.airJumps = h.airJumps - 1
            h.yv = -AIR_JUMP_V
            h.buffer = 0
            h.jumping = TRUE
            simEvents = simEvents Or EV_AIRJUMP
        End If
        ' releasing early cuts the jump short: the tap length sets the height
        If Not held And h.jumping And h.yv < -CUT_V Then h.yv = -CUT_V
    End If
    If h.buffer > 0 Then h.buffer = h.buffer - 1

    ' --- gravity
    If h.mode = MODE_JET Then h.yv = h.yv + JET_GRAVITY Else h.yv = h.yv + GRAVITY
    If h.yv > MAX_FALL Then h.yv = MAX_FALL

    ' --- horizontal: always running. Hitting a wall is fatal, but small
    ' ledges (STEP_TOL pixels) are climbed automatically.
    h.x = h.x + RUN_SPEED
    If overlapsSolid(h, h.x, h.y) Then
        For i = 1 To STEP_TOL
            If Not overlapsSolid(h, h.x, h.y - i) Then Exit For
        Next
        If i > STEP_TOL Then
            h.alive = FALSE: h.cause = DIE_CRASH
            If touchingLava(h, h.x, h.y) Then h.cause = DIE_LAVA
            Exit Sub
        End If
        h.y = h.y - i
    End If

    ' --- vertical
    wasGrounded = h.grounded
    prevBottom = h.y + HERO_H
    h.y = h.y + h.yv
    h.grounded = FALSE
    If h.yv >= 0 Then
        landY = findFloor(h, prevBottom, h.y + HERO_H)
        If landY >= 0 Then
            h.y = landY - HERO_H
            h.yv = 0
            h.grounded = TRUE
            If Not wasGrounded Then simEvents = simEvents Or EV_LAND
            h.jumping = FALSE
            If touchingLava(h, h.x, h.y + 1) Then h.alive = FALSE: h.cause = DIE_LAVA: Exit Sub
        End If
    Else
        ceilY = findCeiling(h)
        If ceilY >= 0 Then h.y = ceilY: h.yv = 0
    End If

    If h.grounded Then
        h.coyote = 0
    ElseIf wasGrounded And Not h.jumping Then
        h.coyote = COYOTE_TICKS ' just walked off a ledge
    ElseIf h.coyote > 0 Then
        h.coyote = h.coyote - 1
    End If

    If h.mode = MODE_JET And h.y < 0 Then h.y = 0: h.yv = 0

    touchTiles h
    If Not h.alive Then Exit Sub

    If h.y > WATER_Y - HERO_H / 2 Then h.alive = FALSE: h.cause = DIE_WATER: Exit Sub
    If h.x >= goalX Then h.won = TRUE
End Sub

Function tileAt& (c As Long, r As Long)
    If c < 0 Or c >= levelCols Or r < 0 Or r >= ROWS Then
        tileAt& = T_EMPTY
    Else
        tileAt& = tiles(c, r)
    End If
End Function

Function isSolid& (h As HeroState, c As Long, r As Long)
    Dim t As Long
    t = tileAt(c, r)
    isSolid& = (t = T_GROUND) Or (t = T_LAVA) Or (t = T_BARRIER And h.barriersOn <> 0)
End Function

Function overlapsSolid& (h As HeroState, x As Single, y As Single)
    Dim c As Long, r As Long
    overlapsSolid& = FALSE
    For c = Int(x / TILE) To Int((x + HERO_W - .01) / TILE)
        For r = Int(y / TILE) To Int((y + HERO_H - .01) / TILE)
            If isSolid(h, c, r) Then overlapsSolid& = TRUE: Exit Function
        Next
    Next
End Function

Function touchingLava& (h As HeroState, x As Single, y As Single)
    Dim c As Long, r As Long
    touchingLava& = FALSE
    For c = Int(x / TILE) To Int((x + HERO_W - .01) / TILE)
        For r = Int(y / TILE) To Int((y + HERO_H - .01) / TILE)
            If tileAt(c, r) = T_LAVA Then touchingLava& = TRUE: Exit Function
        Next
    Next
End Function

' Top y of the first floor crossed while moving from prevBottom to newBottom,
' or -1. Planks only catch you from above.
Function findFloor! (h As HeroState, prevBottom As Single, newBottom As Single)
    Dim c As Long, r As Long, t As Long, top As Single
    findFloor! = -1
    For r = Int(prevBottom / TILE) To Int((newBottom - .01) / TILE)
        top = r * TILE
        If top >= prevBottom - .5 And top <= newBottom Then
            For c = Int(h.x / TILE) To Int((h.x + HERO_W - .01) / TILE)
                t = tileAt(c, r)
                If isSolid(h, c, r) Or t = T_PLANK Then findFloor! = top: Exit Function
            Next
        End If
    Next
End Function

' Bottom y of a solid tile the head is inside after moving up, or -1.
Function findCeiling! (h As HeroState)
    Dim c As Long, r As Long
    findCeiling! = -1
    r = Int(h.y / TILE)
    For c = Int(h.x / TILE) To Int((h.x + HERO_W - .01) / TILE)
        If isSolid(h, c, r) Then findCeiling! = (r + 1) * TILE: Exit Function
    Next
End Function

Function toggleUp& (t As Long)
    Dim phase As Long
    phase = (simTick \ TOGGLE_TICKS) Mod 2
    toggleUp& = (t = T_TOGGLEA And phase = 0) Or (t = T_TOGGLEB And phase = 1)
End Function

' Hazards and pickups the hero's box is touching.
Sub touchTiles (h As HeroState)
    Dim c As Long, r As Long, t As Long, bit As Long, m As Long
    Dim hx1 As Single, hy1 As Single, hx2 As Single, hy2 As Single
    Dim tx As Single, ty As Single

    ' a slightly smaller box for hazards, so near misses feel fair
    hx1 = h.x + 2: hx2 = h.x + HERO_W - 2
    hy1 = h.y + 2: hy2 = h.y + HERO_H - 1

    For c = Int(h.x / TILE) To Int((h.x + HERO_W - .01) / TILE)
        For r = Int(h.y / TILE) To Int((h.y + HERO_H - .01) / TILE)
            t = tileAt(c, r)
            tx = c * TILE: ty = r * TILE
            Select Case t
                Case T_SPIKE, T_TOGGLEA, T_TOGGLEB
                    If t = T_SPIKE Or toggleUp(t) Then
                        If boxHit(hx1, hy1, hx2, hy2, tx + 6, ty + 11, tx + TILE - 6, ty + TILE) Then
                            h.alive = FALSE: h.cause = DIE_SPIKE: Exit Sub
                        End If
                    End If
                Case T_SPIKEDOWN
                    If boxHit(hx1, hy1, hx2, hy2, tx + 6, ty, tx + TILE - 6, ty + TILE - 11) Then
                        h.alive = FALSE: h.cause = DIE_SPIKE: Exit Sub
                    End If
                Case T_LAVA
                    h.alive = FALSE: h.cause = DIE_LAVA: Exit Sub
                Case T_GEM
                    bit = 2 ^ gemIndex(c, r)
                    If (h.gemMask And bit) = 0 Then
                        h.gemMask = h.gemMask Or bit
                        h.airJumps = h.airJumps + 1
                        simEvents = simEvents Or EV_GEM
                    End If
                Case T_SWITCH
                    If h.barriersOn Then h.barriersOn = FALSE: simEvents = simEvents Or EV_SWITCH
                Case T_TELEIN
                    If teleCol(c, r) >= 0 Then
                        h.x = teleCol(c, r) * TILE + (TILE - HERO_W) / 2
                        h.y = teleRow(c, r) * TILE + TILE - HERO_H
                        simEvents = simEvents Or EV_TELEPORT
                        Exit Sub
                    End If
                Case T_JET, T_WINGS, T_NORMAL
                    m = MODE_RUN
                    If t = T_JET Then m = MODE_JET
                    If t = T_WINGS Then m = MODE_WINGS
                    If h.mode <> m Then
                        h.mode = m
                        h.jumping = FALSE
                        simEvents = simEvents Or EV_MODE
                    End If
            End Select
        Next
    Next
End Sub

Function boxHit& (ax1 As Single, ay1 As Single, ax2 As Single, ay2 As Single, bx1 As Single, by1 As Single, bx2 As Single, by2 As Single)
    boxHit& = ax1 < bx2 And ax2 > bx1 And ay1 < by2 And ay2 > by1
End Function

'=============================================================================
' LEVEL LOADING
'=============================================================================

Sub countLevels
    Restore
    Read levelCount
End Sub

Sub loadLevel (n As Long)
    Dim i As Long, r As Long, c As Long, s As String, ch As String
    Dim rowsText(0 To ROWS - 1) As String, gems As Long

    Restore
    Read levelCount
    ' skip earlier levels: each is name, theme, then ROWS rows
    For i = 1 To n - 1
        Read s, r
        For r = 0 To ROWS - 1: Read s: Next
    Next
    Read levelName, levelTheme
    levelCols = 0
    For r = 0 To ROWS - 1
        Read rowsText(r)
        If Len(rowsText(r)) > levelCols Then levelCols = Len(rowsText(r))
    Next

    levelNum = n
    ReDim tiles(0 To levelCols - 1, 0 To ROWS - 1) As Long
    ReDim gemIndex(0 To levelCols - 1, 0 To ROWS - 1) As Long
    ReDim teleCol(0 To levelCols - 1, 0 To ROWS - 1) As Long
    ReDim teleRow(0 To levelCols - 1, 0 To ROWS - 1) As Long
    goalX = (levelCols - 10) * TILE
    startX = 2 * TILE: startY = 15 * TILE + TILE - HERO_H
    gems = 0

    For r = 0 To ROWS - 1
        For c = 0 To levelCols - 1
            ch = Mid$(rowsText(r), c + 1, 1)
            Select Case ch
                Case "#": tiles(c, r) = T_GROUND
                Case "=": tiles(c, r) = T_PLANK
                Case "^": tiles(c, r) = T_SPIKE
                Case "v": tiles(c, r) = T_SPIKEDOWN
                Case "L": tiles(c, r) = T_LAVA
                Case "*"
                    tiles(c, r) = T_GEM
                    gemIndex(c, r) = gems Mod MAX_GEMS
                    gems = gems + 1
                Case "T": tiles(c, r) = T_TOGGLEA
                Case "t": tiles(c, r) = T_TOGGLEB
                Case "S": tiles(c, r) = T_SWITCH
                Case "B": tiles(c, r) = T_BARRIER
                Case "O": tiles(c, r) = T_TELEIN
                Case "o": tiles(c, r) = T_TELEOUT
                Case "J": tiles(c, r) = T_JET
                Case "W": tiles(c, r) = T_WINGS
                Case "N": tiles(c, r) = T_NORMAL
                Case "G": tiles(c, r) = T_GOAL: goalX = c * TILE: goalRow = r
                Case "@": startX = c * TILE + (TILE - HERO_W) / 2: startY = r * TILE + TILE - HERO_H
                Case Else: tiles(c, r) = T_EMPTY
            End Select
        Next
    Next
    pairTeleporters

    initHero hero
    If Not headless Then
        th = themes(levelTheme)
        bakeBackground
        bakeLevel
        initClouds
    End If
    camX = 0
    attempt = 0
End Sub

' Each teleporter leads to the nearest exit to its right.
Sub pairTeleporters
    Dim c As Long, r As Long, c2 As Long, r2 As Long, found As Long
    For c = 0 To levelCols - 1
        For r = 0 To ROWS - 1
            teleCol(c, r) = -1
            If tiles(c, r) = T_TELEIN Then
                found = FALSE
                For c2 = c + 1 To levelCols - 1
                    For r2 = 0 To ROWS - 1
                        If tiles(c2, r2) = T_TELEOUT Then teleCol(c, r) = c2: teleRow(c, r) = r2: found = TRUE: Exit For
                    Next
                    If found Then Exit For
                Next
            End If
        Next
    Next
End Sub

'=============================================================================
' RENDERING
'=============================================================================

Sub initThemes
    ' 0 meadow
    themes(0).skyTop = _RGB32(78, 180, 228): themes(0).skyBottom = _RGB32(186, 230, 240)
    themes(0).hillFar = _RGB32(122, 184, 150): themes(0).hillNear = _RGB32(84, 150, 98)
    themes(0).ground = _RGB32(176, 116, 64): themes(0).groundDark = _RGB32(140, 88, 48)
    themes(0).grass = _RGB32(92, 176, 72): themes(0).water = _RGB32(36, 150, 200)
    ' 1 dusk
    themes(1).skyTop = _RGB32(58, 48, 112): themes(1).skyBottom = _RGB32(242, 146, 112)
    themes(1).hillFar = _RGB32(138, 88, 128): themes(1).hillNear = _RGB32(92, 60, 104)
    themes(1).ground = _RGB32(122, 92, 112): themes(1).groundDark = _RGB32(92, 66, 88)
    themes(1).grass = _RGB32(214, 128, 150): themes(1).water = _RGB32(64, 72, 150)
    ' 2 desert
    themes(2).skyTop = _RGB32(238, 176, 96): themes(2).skyBottom = _RGB32(252, 232, 176)
    themes(2).hillFar = _RGB32(226, 164, 104): themes(2).hillNear = _RGB32(196, 124, 82)
    themes(2).ground = _RGB32(206, 148, 82): themes(2).groundDark = _RGB32(170, 110, 62)
    themes(2).grass = _RGB32(236, 198, 120): themes(2).water = _RGB32(226, 82, 34)
    themes(2).hotSea = TRUE
    ' 3 night
    themes(3).skyTop = _RGB32(14, 18, 48): themes(3).skyBottom = _RGB32(52, 62, 116)
    themes(3).hillFar = _RGB32(40, 50, 92): themes(3).hillNear = _RGB32(28, 34, 66)
    themes(3).ground = _RGB32(72, 82, 104): themes(3).groundDark = _RGB32(52, 58, 78)
    themes(3).grass = _RGB32(110, 206, 224): themes(3).water = _RGB32(22, 42, 96)
    themes(3).stars = TRUE
End Sub

' Hero frames: 8x10 pixel art drawn at 2x. 0-2 run, 3 jump, 4 fall, 5 idle.
Sub initHeroSprites
loadSounds
    Dim body(0 To 7) As String, legs(0 To 5) As String
    Dim f As Long, r As Long, c As Long, s As String, ch As String, col As _Unsigned Long

    body(0) = "..KKKK.."
    body(1) = ".KBBBBK."
    body(2) = "KRRRRRRK"
    body(3) = "KBBBWPBK"
    body(4) = "KBBBWPBK"
    body(5) = "KBBBBBBK"
    body(6) = ".KBBBBK."
    body(7) = "..KKKK.."
    legs(0) = ".F....F.F......F"
    legs(1) = "..F..F....F..F.."
    legs(2) = "...FF......FF..."
    legs(3) = "..F.F....F...F.."
    legs(4) = "..F..F...F....F."
    legs(5) = "..F..F....F..F.."

    For f = 0 To 5
        heroImg(f) = _NewImage(16, 20, 32)
        _Dest heroImg(f)
        For r = 0 To 9
            If r < 8 Then s = body(r) Else s = Mid$(legs(f), (r - 8) * 8 + 1, 8)
            For c = 0 To 7
                ch = Mid$(s, c + 1, 1)
                Select Case ch
                    Case "K": col = _RGB32(34, 32, 52)
                    Case "B": col = _RGB32(246, 244, 236)
                    Case "R": col = _RGB32(232, 72, 72)
                    Case "W": col = _RGB32(255, 255, 255)
                    Case "P": col = _RGB32(34, 32, 52)
                    Case "F": col = _RGB32(34, 32, 52)
                    Case Else: col = 0
                End Select
                If col <> 0 Then Line (c * 2, r * 2)-Step(1, 1), col, BF
            Next
        Next
    Next
    _Dest 0
End Sub

Function mixColor~& (a As _Unsigned Long, b As _Unsigned Long, t As Single)
    mixColor~& = _RGB32(_Red32(a) + (_Red32(b) - _Red32(a)) * t, _Green32(a) + (_Green32(b) - _Green32(a)) * t, _Blue32(a) + (_Blue32(b) - _Blue32(a)) * t)
End Function

Function shade~& (c As _Unsigned Long, f As Single)
    Dim r As Single, g As Single, b As Single
    r = _Red32(c) * f: g = _Green32(c) * f: b = _Blue32(c) * f
    If r > 255 Then r = 255
    If g > 255 Then g = 255
    If b > 255 Then b = 255
    shade~& = _RGB32(r, g, b)
End Function

' Cheap deterministic noise so baked textures look the same every time.
Function hash01! (a As Long, b As Long)
    Dim v As Long
    v = (a * 73 + b * 151 + a * b * 7) Mod 997
    hash01! = v / 997
End Function

' Triangle with its tip at (cx, peakY) and a flat base at baseY (either side).
Sub fillTri (cx As Single, peakY As Single, halfW As Single, baseY As Single, c As _Unsigned Long)
    Dim y As Long, w As Single, y1 As Long, y2 As Long
    If baseY >= peakY Then y1 = Int(peakY): y2 = Int(baseY) Else y1 = Int(baseY): y2 = Int(peakY)
    For y = y1 To y2
        w = halfW * Abs(y - peakY) / (Abs(baseY - peakY) + .001)
        Line (cx - w, y)-(cx + w, y), c
    Next
End Sub

Sub bakeBackground
    Dim y As Long, i As Long, x As Single, h As Single, w As Single

    If skyImg < -1 Then _FreeImage skyImg
    skyImg = _NewImage(SW, SH, 32)
    _Dest skyImg
    For y = 0 To SH - 1
        Line (0, y)-(SW - 1, y), mixColor(th.skyTop, th.skyBottom, y / SH)
    Next
    If th.stars Then
        For i = 1 To 90
            PSet (hash01(i, 3) * SW, hash01(i, 11) * SH * .6), _RGBA32(255, 255, 255, 80 + hash01(i, 5) * 170)
        Next
    End If

    ' hill strips are 2 screens wide and wrap seamlessly
    If farImg < -1 Then _FreeImage farImg
    farImg = _NewImage(SW * 2, SH, 32)
    _Dest farImg
    For i = 0 To 9
        x = i * SW * 2 / 10 + hash01(i, 1) * 80
        h = 140 + hash01(i, 2) * 120
        w = 160 + hash01(i, 4) * 120
        fillTri x, SH - h - 40, w, SH, th.hillFar
        fillTri x + SW * 2, SH - h - 40, w, SH, th.hillFar
        fillTri x - SW * 2, SH - h - 40, w, SH, th.hillFar
    Next
    If nearImg < -1 Then _FreeImage nearImg
    nearImg = _NewImage(SW * 2, SH, 32)
    _Dest nearImg
    For i = 0 To 13
        x = i * SW * 2 / 14 + hash01(i, 7) * 60
        h = 80 + hash01(i, 8) * 90
        w = 110 + hash01(i, 9) * 90
        fillTri x, SH - h, w, SH, th.hillNear
        fillTri x + SW * 2, SH - h, w, SH, th.hillNear
        fillTri x - SW * 2, SH - h, w, SH, th.hillNear
    Next
    _Dest 0
End Sub

Sub initClouds
    Dim i As Long
    For i = 1 To 8
        clouds(i).x = Rnd * SW * 2
        clouds(i).y = 20 + Rnd * 160
        clouds(i).w = 60 + Rnd * 100
        clouds(i).speed = .1 + Rnd * .3
    Next
End Sub

' Static tiles are drawn once into a level-sized image.
Sub bakeLevel
    Dim c As Long, r As Long, t As Long, x As Long, y As Long, i As Long

    If levelImg < -1 Then _FreeImage levelImg
    levelImg = _NewImage(levelCols * TILE, SH, 32)
    _Dest levelImg
    For c = 0 To levelCols - 1
        For r = 0 To ROWS - 1
            t = tiles(c, r)
            x = c * TILE: y = r * TILE
            Select Case t
                Case T_GROUND
                    Line (x, y)-Step(TILE - 1, TILE - 1), th.ground, BF
                    For i = 0 To 2
                        Line (x + 3 + hash01(c, r * 3 + i) * 17, y + 4 + hash01(r, c * 5 + i) * 16)-Step(2, 2), th.groundDark, BF
                    Next
                    If tileAt(c - 1, r) <> T_GROUND Then Line (x, y)-Step(2, TILE - 1), shade(th.ground, 1.15), BF
                    If tileAt(c + 1, r) <> T_GROUND Then Line (x + TILE - 3, y)-Step(2, TILE - 1), th.groundDark, BF
                    If tileAt(c, r - 1) <> T_GROUND Then
                        Line (x, y)-Step(TILE - 1, 6), th.grass, BF
                        Line (x, y)-Step(TILE - 1, 1), shade(th.grass, 1.25), BF
                        Line (x, y + 7)-Step(TILE - 1, 1), shade(th.grass, .7), BF
                    End If
                Case T_PLANK
                    Line (x, y)-Step(TILE - 1, 7), _RGB32(150, 98, 54), BF
                    Line (x, y)-Step(TILE - 1, 1), _RGB32(196, 140, 84), BF
                    Line (x, y + 6)-Step(TILE - 1, 1), _RGB32(96, 60, 34), BF
                    Line (x + TILE - 2, y)-Step(1, 7), _RGB32(96, 60, 34), BF
                Case T_SPIKE
                    drawSpike x, y, FALSE
                Case T_SPIKEDOWN
                    drawSpike x, y, TRUE
                Case T_LAVA
                    Line (x, y)-Step(TILE - 1, TILE - 1), _RGB32(214, 64, 30), BF
                    Line (x, y + 3 + hash01(c, r) * 4)-Step(TILE - 1, 3), _RGB32(255, 168, 48), BF
                    If tileAt(c, r - 1) <> T_LAVA Then Line (x, y)-Step(TILE - 1, 2), _RGB32(255, 220, 120), BF
                Case T_TELEOUT
                    Line (x + 3, y + TILE - 3)-Step(TILE - 7, 2), _RGB32(220, 120, 255), BF
            End Select
        Next
    Next
    _Dest 0
End Sub

Sub drawSpike (x As Single, y As Single, down As Long)
    Dim tip As Single, bas As Single
    If down Then tip = y + TILE - 6: bas = y Else tip = y + 6: bas = y + TILE - 1
    fillTri x + TILE / 2, tip, 8, bas, _RGB32(214, 214, 226)
    Line (x + TILE / 2, tip)-(x + TILE / 2 - 8, bas), _RGB32(90, 90, 110)
    Line (x + TILE / 2, tip)-(x + TILE / 2 + 8, bas), _RGB32(90, 90, 110)
    Line (x + TILE / 2 - 1, tip + 2)-(x + TILE / 2 - 1, (tip + bas) / 2), _RGB32(255, 255, 255)
End Sub

Sub render
    Dim cx As Long, ox As Long, oy As Long, i As Long, p As Single, sx As Single, sy As Single

    ox = 0: oy = 0
    If shake > 0 Then ox = (Rnd - .5) * shake * 2: oy = (Rnd - .5) * shake * 2
    cx = Int(camX)

    _PutImage (0, 0), skyImg
    drawParallax farImg, cx * .2
    drawClouds cx
    drawParallax nearImg, cx * .45
    _PutImage (ox, oy)-(ox + SW - 1, oy + SH - 1), levelImg, 0, (cx, 0)-(cx + SW - 1, SH - 1)
    drawDynamicTiles cx - ox, oy
    If gameState <> ST_TITLE And hero.alive Then
        If teleT > 0 Then
            p = teleProgress
            If p < .3 Then
                ' beam out where the hero stepped in
                sx = hero.x: sy = hero.y
                hero.x = teleFromX: hero.y = teleFromY
                drawBeam cx - ox, oy, p / .3
                drawHero cx - ox, oy, 1 - p / .3
                hero.x = sx: hero.y = sy
            ElseIf p > .75 Then
                drawBeam cx - ox, oy, 1 - (p - .75) / .25
                drawHero cx - ox, oy, (p - .75) / .25
            End If
        Else
            drawHero cx - ox, oy, 1
        End If
    End If
    drawParticles cx - ox, oy
    drawWater cx
    If gameState = ST_PLAY And popLife > 0 Then drawPopup cx

    Select Case gameState
        Case ST_TITLE: drawTitle
        Case ST_PLAY: drawHud
        Case ST_DEAD: drawHud: drawDeadScreen
        Case ST_WON: drawHud: drawWonScreen
        Case ST_END: drawEndScreen
    End Select
End Sub

Sub drawParallax (img As Long, offset As Single)
    Dim o As Long
    o = Int(offset) Mod (SW * 2)
    _PutImage (-o, 0), img
    _PutImage (SW * 2 - o, 0), img
End Sub

Sub updateClouds
    Dim i As Long
    For i = 1 To 8
        clouds(i).x = clouds(i).x - clouds(i).speed
    Next
End Sub

Sub drawClouds (cx As Long)
    Dim i As Long, x As Single, w As Single
    For i = 1 To 8
        x = clouds(i).x - cx * .3
        x = x - Int(x / (SW * 2)) * SW * 2 - 200
        w = clouds(i).w
        Line (x, clouds(i).y)-Step(w, 14), _RGBA32(255, 255, 255, 70), BF
        Line (x + w * .15, clouds(i).y - 8)-Step(w * .5, 8), _RGBA32(255, 255, 255, 70), BF
        Line (x + w * .1, clouds(i).y + 14)-Step(w * .8, 6), _RGBA32(255, 255, 255, 40), BF
    Next
End Sub

Sub drawWater (cx As Long)
    Dim x As Long, y As Single
    Line (0, WATER_Y)-(SW - 1, SH - 1), _RGBA32(_Red32(th.water), _Green32(th.water), _Blue32(th.water), 210), BF
    For x = 0 To SW Step 16
        y = WATER_Y + Sin((x + cx + frameCount * 2) / 30) * 2
        Line (x, y)-Step(9, 1), _RGBA32(255, 255, 255, 110), BF
    Next
End Sub

Sub drawDynamicTiles (cx As Long, oy As Long)
    Dim c As Long, r As Long, t As Long, x As Single, y As Single
    Dim c1 As Long, c2 As Long, b As Single, p As Single

    c1 = Int(cx / TILE) - 1
    c2 = c1 + SW \ TILE + 3
    For c = c1 To c2
        For r = 0 To ROWS - 1
            t = tileAt(c, r)
            If t >= T_GEM Then
                x = c * TILE - cx: y = r * TILE + oy
                Select Case t
                    Case T_GEM
                        If (hero.gemMask And (2 ^ gemIndex(c, r))) = 0 Or gameState = ST_TITLE Then
                            b = Sin(frameCount / 10 + c) * 3
                            drawDiamond x + TILE / 2, y + TILE / 2 + b, 8, _RGB32(120, 230, 255)
                        End If
                    Case T_TOGGLEA, T_TOGGLEB
                        If toggleUp(t) Then
                            drawSpike x, y, FALSE
                        Else
                            Line (x + 5, y + TILE - 4)-Step(TILE - 11, 3), _RGB32(150, 150, 170), BF
                        End If
                    Case T_SWITCH
                        If hero.barriersOn Or gameState = ST_TITLE Then
                            Line (x + 4, y + 4)-Step(TILE - 9, TILE - 9), _RGB32(255, 210, 60), BF
                            Line (x + 4, y + 4)-Step(TILE - 9, TILE - 9), _RGB32(120, 80, 20), B
                            Line (x + 9, y + 9)-Step(TILE - 19, TILE - 19), _RGB32(255, 255, 200), BF
                        Else
                            Line (x + 4, y + 10)-Step(TILE - 9, TILE - 15), _RGB32(150, 120, 60), BF
                        End If
                    Case T_BARRIER
                        If hero.barriersOn Or gameState = ST_TITLE Then
                            Line (x + 2, y)-Step(TILE - 5, TILE - 1), _RGB32(255, 210, 60), BF
                            Line (x + 2, y)-Step(TILE - 5, TILE - 1), _RGB32(120, 80, 20), B
                            Line (x + 6, y + 6)-Step(TILE - 13, TILE - 13), _RGB32(200, 150, 40), B
                        Else
                            Line (x + 2, y)-Step(TILE - 5, TILE - 1), _RGBA32(255, 210, 60, 40), B
                        End If
                    Case T_TELEIN, T_TELEOUT
                        p = (frameCount Mod 30) / 30
                        drawOval x + TILE / 2, y + TILE / 2, 6 + p * 6, 11 + p * 4, _RGBA32(220, 120, 255, 255 * (1 - p))
                        drawOval x + TILE / 2, y + TILE / 2, 6, 11, _RGB32(220, 120, 255)
                    Case T_JET, T_WINGS, T_NORMAL
                        drawModeOrb x + TILE / 2, y + TILE / 2 + Sin(frameCount / 12 + c) * 2, t
                    Case T_GOAL
                        drawGoal x, y
                End Select
            End If
        Next
    Next
End Sub

Sub drawDiamond (x As Single, y As Single, s As Single, c As _Unsigned Long)
    fillTri x, y - s, s * .8, y, c
    Dim i As Long
    For i = 0 To s
        Line (x - s * .8 * (1 - i / s), y + i)-(x + s * .8 * (1 - i / s), y + i), shade(c, .75)
    Next
    Line (x - 2, y - s + 3)-Step(1, 3), _RGB32(255, 255, 255), BF
End Sub

Sub drawOval (x As Single, y As Single, rx As Single, ry As Single, c As _Unsigned Long)
    Dim a As Single, px As Single, py As Single, nx As Single, ny As Single
    px = x + rx: py = y
    For a = .4 To 6.4 Step .4
        nx = x + Cos(a) * rx: ny = y + Sin(a) * ry
        Line (px, py)-(nx, ny), c
        px = nx: py = ny
    Next
End Sub

Sub fillCircle (x As Single, y As Single, r As Single, c As _Unsigned Long)
    Dim dy As Long, w As Single
    For dy = -Int(r) To Int(r)
        w = Sqr(r * r - dy * dy)
        Line (x - w, y + dy)-(x + w, y + dy), c
    Next
End Sub

' Mode pickups, each with its own shape so they read at a glance:
' jetpack = orange orb with a pack and flame, wings = green orb with wings
' sticking out, on foot = pale blue arrow pointing down at the ground.
Sub drawModeOrb (x As Single, y As Single, t As Long)
    Dim pulse As Single, f As Single, i As Long, dark As _Unsigned Long
    pulse = 1 + Sin(frameCount / 8) * .12
    dark = _RGB32(40, 36, 60)
    Select Case t
        Case T_JET
            fillCircle x, y, 14 * pulse, _RGBA32(255, 140, 60, 55)
            fillCircle x, y, 9, dark
            fillCircle x, y, 8, _RGB32(255, 140, 60)
            Line (x - 3, y - 6)-Step(6, 8), _RGB32(96, 96, 116), BF
            Line (x - 2, y - 5)-Step(1, 6), _RGB32(180, 180, 200), BF
            fillTri x, y + 7 + Rnd * 2, 3, y + 3, _RGB32(255, 236, 140)
        Case T_WINGS
            fillCircle x, y, 14 * pulse, _RGBA32(130, 240, 150, 55)
            f = Sin(frameCount / 5) * 3
            For i = 0 To 2
                Line (x - 6, y - 3 + i * 3)-(x - 17 + i * 3, y - 6 + i * 3 - f), _RGB32(255, 255, 255)
                Line (x - 6, y - 2 + i * 3)-(x - 17 + i * 3, y - 5 + i * 3 - f), _RGB32(255, 255, 255)
                Line (x + 6, y - 3 + i * 3)-(x + 17 - i * 3, y - 6 + i * 3 - f), _RGB32(255, 255, 255)
                Line (x + 6, y - 2 + i * 3)-(x + 17 - i * 3, y - 5 + i * 3 - f), _RGB32(255, 255, 255)
            Next
            fillCircle x, y, 8, dark
            fillCircle x, y, 7, _RGB32(110, 220, 130)
            fillCircle x - 2, y - 2, 2, _RGB32(210, 255, 220)
        Case Else
            fillCircle x, y, 14 * pulse, _RGBA32(170, 210, 255, 55)
            fillTri x, y + 9, 10, y - 8, dark
            fillTri x, y + 7, 8, y - 7, _RGB32(180, 215, 255)
            Line (x - 9, y + 11)-Step(18, 2), dark, BF
    End Select
End Sub

Sub drawGoal (x As Single, y As Single)
    Dim i As Long, w As Single, fy As Single
    Line (x + 2, y - 70)-Step(3, 70 + TILE - 1), _RGB32(240, 240, 240), BF
    Line (x + 2, y - 70)-Step(3, 70 + TILE - 1), _RGB32(60, 60, 80), B
    For i = 0 To 30
        fy = y - 68 + Sin(frameCount / 6 - i / 5) * 2
        If ((i \ 6) Mod 2) = 0 Then
            Line (x + 6 + i, fy)-Step(0, 9), _RGB32(30, 30, 40)
            Line (x + 6 + i, fy + 10)-Step(0, 9), _RGB32(250, 250, 250)
        Else
            Line (x + 6 + i, fy)-Step(0, 9), _RGB32(250, 250, 250)
            Line (x + 6 + i, fy + 10)-Step(0, 9), _RGB32(30, 30, 40)
        End If
    Next
End Sub

' vis < 1 squeezes the hero into a thin, tall sliver (used by teleports).
Sub drawHero (cx As Long, oy As Long, vis As Single)
    Dim f As Long, x As Single, y As Single, w As Single, h As Single
    Dim sy As Single, r As Long, c As Long, sx1 As Single, sx2 As Single

    ' shadow on the first floor below the hero
    sx1 = hero.x + 2: sx2 = hero.x + HERO_W - 2
    For r = Int((hero.y + HERO_H) / TILE) To ROWS - 1
        If r >= 0 Then
            c = Int((hero.x + HERO_W / 2) / TILE)
            If isSolid(hero, c, r) Or tileAt(c, r) = T_PLANK Then
                sy = r * TILE
                Line (sx1 - cx, sy + 2 + oy)-(sx2 - cx, sy + 4 + oy), _RGBA32(0, 0, 0, 60), BF
                Exit For
            End If
        End If
    Next

    If hero.grounded Then
        If gameState = ST_PLAY Then f = (frameCount \ 5) Mod 3 Else f = 5
    ElseIf hero.yv < 0 Then
        f = 3
    Else
        f = 4
    End If

    ' squash > 0 = landing (wide and short), < 0 = take-off (tall and thin)
    w = 16 * (1 + squash * .35) * vis
    h = 20 * (1 - squash * .3) * (1 + (1 - vis) * .8)
    x = hero.x + HERO_W / 2 - w / 2 - cx
    y = hero.y + HERO_H - h + oy
    If w >= 1 Then _PutImage (x, y)-(x + w - 1, y + h - 1), heroImg(f)
    If vis < 1 Then Exit Sub

    ' mode marker and spare air jumps
    If hero.mode = MODE_JET Then
        Line (x - 3, y + 8)-Step(3, 8), _RGB32(120, 120, 140), BF
        If hero.yv < 0 Then Line (x - 3, y + 17)-Step(3, 3 + Rnd * 4), _RGB32(255, 170, 60), BF
    ElseIf hero.mode = MODE_WINGS Then
        Line (x - 6, y + 6 + (frameCount Mod 10 < 5) * 2)-Step(5, 3), _RGB32(255, 255, 255), BF
    End If
    For c = 1 To hero.airJumps
        drawDiamond x + w / 2 - (hero.airJumps - 1) * 6 + (c - 1) * 12, y - 10, 4, _RGB32(120, 230, 255)
    Next
End Sub

' A column of light on the hero; strength 0..1.
Sub drawBeam (cx As Long, oy As Long, strength As Single)
    Dim x As Single, top As Single, bot As Single
    x = hero.x + HERO_W / 2 - cx
    bot = hero.y + HERO_H + oy
    top = bot - 90
    Line (x - 9, top)-(x + 9, bot), _RGBA32(220, 120, 255, 70 * strength), BF
    Line (x - 4, top)-(x + 4, bot), _RGBA32(255, 230, 255, 120 * strength), BF
End Sub

Sub drawPopup (cx As Long)
    Dim x As Single, y As Single, a As Long, age As Long, w As Single
    age = POP_TICKS - popLife
    a = 255
    If age < 6 Then a = 255 * age / 6
    If popLife < 25 Then a = 255 * popLife / 25
    x = hero.x + HERO_W / 2 - cx
    y = hero.y - 40 - age * .3
    If y < 60 Then y = 60
    w = _PrintWidth(popHint) / 2 + 4
    If w < _PrintWidth(popText) + 4 Then w = _PrintWidth(popText) + 4
    If x < w Then x = w
    If x > SW - w Then x = SW - w
    bigText popText, x, y, 2, _RGBA32(_Red32(popColor), _Green32(popColor), _Blue32(popColor), a)
    If popHint <> "" Then
        putText popHint, x - _PrintWidth(popHint) / 2 + 1, y + 19, 1, _RGBA32(30, 26, 46, a)
        putText popHint, x - _PrintWidth(popHint) / 2, y + 18, 1, _RGBA32(255, 255, 255, a)
    End If
End Sub

Sub sparkle (x As Single, y As Single)
    spawnParticle x + (Rnd - .5) * 16, y + (Rnd - .5) * 24, (Rnd - .5) * .6, -Rnd * 1.5 - .5, 18, 2, _RGB32(240, 190, 255)
End Sub

'--- particles

Sub spawnParticle (x As Single, y As Single, xv As Single, yv As Single, life As Single, size As Single, c As _Unsigned Long)
    Dim i As Long
    For i = 1 To UBound(particles)
        If particles(i).life <= 0 Then
            particles(i).x = x: particles(i).y = y
            particles(i).xv = xv: particles(i).yv = yv
            particles(i).life = life: particles(i).maxLife = life
            particles(i).size = size: particles(i).c = c
            Exit Sub
        End If
    Next
End Sub

Sub burst (x As Single, y As Single, n As Long, c As _Unsigned Long)
    Dim i As Long, a As Single, s As Single
    For i = 1 To n
        a = Rnd * 6.283: s = 1 + Rnd * 5
        spawnParticle x, y, Cos(a) * s, Sin(a) * s - 2, 30 + Rnd * 30, 2 + Rnd * 3, c
    Next
End Sub

Sub dust (x As Single, y As Single, n As Long)
    Dim i As Long
    For i = 1 To n
        spawnParticle x + (Rnd - .5) * 10, y - 2, (Rnd - .7) * 2, -Rnd * 1.2, 15 + Rnd * 10, 2 + Rnd * 2, _RGBA32(255, 255, 255, 180)
    Next
End Sub

Sub ring (x As Single, y As Single, c As _Unsigned Long)
    Dim i As Long, a As Single
    For i = 0 To 11
        a = i * 6.283 / 12
        spawnParticle x, y, Cos(a) * 3, Sin(a) * 3, 20, 3, c
    Next
End Sub

Sub updateParticles
    Dim i As Long
    For i = 1 To UBound(particles)
        If particles(i).life > 0 Then
            particles(i).x = particles(i).x + particles(i).xv
            particles(i).y = particles(i).y + particles(i).yv
            particles(i).yv = particles(i).yv + .15
            particles(i).xv = particles(i).xv * .97
            particles(i).life = particles(i).life - 1
        End If
    Next
End Sub

Sub drawParticles (cx As Long, oy As Long)
    Dim i As Long, s As Single, a As Single, c As _Unsigned Long
    For i = 1 To UBound(particles)
        If particles(i).life > 0 Then
            a = particles(i).life / particles(i).maxLife
            c = particles(i).c
            s = particles(i).size
            Line (particles(i).x - cx - s / 2, particles(i).y + oy - s / 2)-Step(s, s), _RGBA32(_Red32(c), _Green32(c), _Blue32(c), _Alpha32(c) * a), BF
        End If
    Next
End Sub

'--- text and screens

' Scaled text: print into a small image, then stretch it onto the screen.
Sub bigText (s As String, cx As Single, cy As Single, scale As Single, c As _Unsigned Long)
    Dim x As Single, y As Single, w As Long, h As Long
    If Len(s) = 0 Then Exit Sub
    w = _PrintWidth(s): h = _FontHeight
    x = cx - w * scale / 2: y = cy - h * scale / 2
    putText s, x + scale, y + scale, scale, _RGBA32(30, 26, 46, _Alpha32(c))
    putText s, x, y, scale, c
End Sub

Sub putText (s As String, x As Single, y As Single, scale As Single, c As _Unsigned Long)
    Dim img As Long, w As Long, h As Long
    w = _PrintWidth(s): h = _FontHeight
    img = _NewImage(w, h, 32)
    _Dest img
    _PrintMode _KeepBackground
    Color c
    _PrintString (0, 0), s
    _Dest 0
    _PutImage (x, y)-(x + w * scale - 1, y + h * scale - 1), img
    _FreeImage img
End Sub

Sub textAt (s As String, x As Single, y As Single, c As _Unsigned Long)
    _PrintMode _KeepBackground
    Color _RGBA32(0, 0, 0, 120)
    _PrintString (x + 1, y + 1), s
    Color c
    _PrintString (x, y), s
End Sub

Sub centerText (s As String, y As Single, c As _Unsigned Long)
    textAt s, SW / 2 - _PrintWidth(s) / 2, y, c
End Sub

Sub dimScreen (a As Long)
    Line (0, 0)-(SW - 1, SH - 1), _RGBA32(10, 10, 30, a), BF
End Sub

Function levelLabel$ (n As Long)
    levelLabel$ = "Level" + Str$(n) + " - " + levelName
End Function

Sub drawHud
    Dim bx As Single, bw As Single, p As Single, s As String

    textAt levelLabel(levelNum), 10, 8, _RGB32(255, 255, 255)
    s = "Deaths:" + Str$(levelDeaths)
    textAt s, SW - 10 - _PrintWidth(s), 8, _RGB32(255, 255, 255)

    ' progress bar with the best attempt marked
    bw = 240: bx = SW / 2 - bw / 2
    Line (bx - 2, 10)-Step(bw + 3, 11), _RGBA32(0, 0, 0, 90), BF
    p = progressPct / 100
    Line (bx, 12)-Step(bw * p, 7), _RGB32(255, 255, 255), BF
    If bestPct(levelNum) > 0 Then
        Line (bx + bw * bestPct(levelNum) / 100, 9)-Step(1, 13), _RGB32(255, 210, 60), BF
    End If
    If muted Then textAt "muted", SW - 10 - _PrintWidth("muted"), 26, _RGB32(255, 255, 255)
End Sub

Sub drawTitle
    dimScreen 90
    bigText "LEAP LINE", SW / 2, 110, 6, _RGB32(255, 255, 255)
    centerText "Tap to hop, hold to jump higher. Don't stop, don't fall.", 175, _RGB32(255, 255, 255)
    centerText "<  " + levelLabel(titleLevel) + "  >", 250, _RGB32(255, 230, 120)
    If bestPct(titleLevel) > 0 Then centerText "best:" + Str$(bestPct(titleLevel)) + "%", 272, _RGB32(255, 255, 255)
    If (frameCount \ 30) Mod 2 = 0 Then centerText "SPACE / click / tap to play", 320, _RGB32(255, 255, 255)
    centerText "R restart   M mute   ESC menu", SH - 30, _RGBA32(255, 255, 255, 180)
End Sub

Sub drawDeadScreen
    Dim s As String
    dimScreen 110
    bigText LTrim$(Str$(lastPct)) + "%", SW / 2, 150, 7, _RGB32(255, 255, 255)
    Select Case deathCause
        Case DIE_CRASH: s = "Bonk! Hit a wall."
        Case DIE_SPIKE: s = "Ouch! Spikes."
        Case DIE_LAVA: s = "Too hot!"
        Case DIE_WATER
            If th.hotSea Then s = "Too hot!" Else s = "Splash!"
    End Select
    centerText s, 225, _RGB32(255, 230, 120)
    centerText "best:" + Str$(bestPct(levelNum)) + "%    attempt" + Str$(attempt), 255, _RGB32(255, 255, 255)
    If stateTicks > 15 Then centerText "SPACE / click to retry", 300, _RGB32(255, 255, 255)
End Sub

Sub drawWonScreen
    dimScreen 90
    bigText "COMPLETE!", SW / 2, 140, 5, _RGB32(255, 230, 90)
    centerText "Deaths on this level:" + Str$(levelDeaths), 210, _RGB32(255, 255, 255)
    If stateTicks > 40 Then
        If levelNum < levelCount Then
            centerText "SPACE / click for level" + Str$(levelNum + 1), 260, _RGB32(255, 255, 255)
        Else
            centerText "SPACE / click to finish", 260, _RGB32(255, 255, 255)
        End If
    End If
End Sub

Sub drawEndScreen
    dimScreen 140
    bigText "ALL CLEAR", SW / 2, 140, 6, _RGB32(255, 230, 90)
    centerText "Total deaths:" + Str$(deathsTotal), 220, _RGB32(255, 255, 255)
    If stateTicks > 40 Then centerText "SPACE / click for the title screen", 270, _RGB32(255, 255, 255)
End Sub

'--- sound: soft WAV effects, loaded the same way in QB64-PE and QBJS.
' A missing file just means that effect stays silent.

Sub loadSounds
    Dim names(1 To 10) As String, i As Long
    names(1) = "jump": names(2) = "airjump": names(3) = "flap"
    names(4) = "gem": names(5) = "switch": names(6) = "teleport"
    names(7) = "mode": names(8) = "die": names(9) = "win"
    names(10) = "arrive"
    For i = 1 To 10
        sounds(i) = _SndOpen("sfx/" + names(i) + ".wav")
    Next
End Sub

Sub sfx (n As Long)
    If muted Or headless Then Exit Sub
    If sounds(n) > 0 Then _SndPlayCopy sounds(n)
End Sub
