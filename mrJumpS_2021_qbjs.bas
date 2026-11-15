' mrJumpS, as of commit 314c724 "Reorders layers (shadow shows up again!)"
' (Feb 18, 2021), ported so the same source runs in QBJS and in QB64-PE.
'
' Changes from the original, all for QBJS:
' - TRUE/FALSE constants (QBJS emits "const false = 0", which is invalid JS)
' - classic "Dim x As type" / one-field-per-line TYPE syntax
' - GoTo Restart replaced by an outer loop
' - DRAW glyphs replaced by LINE segments, PAINT by scanline fills
' - _ClearColor corner cut-outs replaced by drawing only the visible pixels
' - UDT copies replaced by field resets / indexes (QBJS copies by reference)
' - image handles checked with <> 0 (QBJS handles are positive)
' - SLEEP on victory replaced by a wait-for-key loop that keeps the page alive

Option _Explicit

Const TRUE = -1
Const FALSE = 0
Const SW = 800
Const SH = 450

Screen _NewImage(SW, SH, 32)

Type newLevel
    landColor As _Unsigned Long
    grassColor As _Unsigned Long
    waterColor As _Unsigned Long
    symbolSpacingX As Long
    symbolSpacingY As Long
End Type

Type gameObject
    id As Long
    w As Long
    h As Long
    img As Long
    x As Single
    xv As Single
    y As Single
    yv As Single
    imgPointer As _Byte
    standing As _Byte
    alive As _Byte
    color As _Unsigned Long
End Type

Const idPlatform = 1
Const idGoal = 2
Const idAirJump = 3
Const idInfiniteJumps = 4
Const idSpike = 5
Const idCloud = 6
Const idScene = 7
Const idSky = 8
Const idWater = 9

Const jumpFactor = 3
Const gravityCap = 15

Dim Shared thisLevel As Long, arenaWidth As Long, i As Long, totalObjects As Long
Dim Shared airJumps As Long, hero As Long, goal As Long
Dim Shared x As Single, y As Single, camera As Single, gravity As Single
Dim Shared drowned As _Byte, restartRequested As _Byte, shadowCast As _Byte
Dim Shared shadowCastOn As Long
Dim Shared levelData As newLevel
Dim Shared lastJump As Single, jumpKeyDown As _Byte
Dim Shared penX As Single, penY As Single, penColor As _Unsigned Long
ReDim Shared obj(100) As gameObject

Randomize Timer

gravity = .8
thisLevel = 1

Do
    setLevel thisLevel
    restartRequested = FALSE

    Do
        processInput
        doPhysics
        adjustCamera
        drawObjects
        If restartRequested Then Exit Do
        If Not drowned Then drawHero
        checkVictory

        If Not obj(hero).alive Then
            _PrintString (0, 0), "Dead"
            _PrintString (0, 20), Str$((obj(hero).x / arenaWidth) * 100) + "%"
        ElseIf obj(hero).standing Then
            _PrintString (0, 0), "Standing"
        End If

        _Display
        _Limit 60
    Loop
Loop

'--- pen helpers standing in for DRAW

Sub penMove (px As Single, py As Single)
    penX = px: penY = py
End Sub

Sub penTo (dx As Single, dy As Single)
    Line (penX, penY)-(penX + dx, penY + dy), penColor
    penX = penX + dx: penY = penY + dy
End Sub

' DRAW "e10f10g10 h8e8f6g6 h4 e4f2g1"
Sub drawGoalGlyph (gx As Single, gy As Single)
    penColor = _RGB32(255, 255, 255)
    penMove gx, gy
    penTo 10, -10: penTo 10, 10: penTo -10, 10
    penTo -8, -8: penTo 8, -8: penTo 6, 6: penTo -6, 6
    penTo -4, -4
    penTo 4, -4: penTo 2, 2: penTo -1, 1
End Sub

' DRAW "e10f10g10h10"
Sub drawAirJumpGlyph (gx As Single, gy As Single)
    penColor = _RGB32(255, 255, 255)
    penMove gx, gy
    penTo 10, -10: penTo 10, 10: penTo -10, 10: penTo -10, -10
End Sub

' DRAW "bd5 e10r1g10r1e10r1g10r1e10r1g10r1e10r1g10"
Sub drawDecoration (dx As Single, dy As Single, c As _Unsigned Long)
    Dim k As Long
    penColor = c
    penMove dx, dy + 5
    For k = 1 To 4
        penTo 10, -10
        penTo 1, 0
        penTo -10, 10
        If k < 4 Then penTo 1, 0
    Next
End Sub

' Solid triangle (0,h-1)-(w/2,0)-(w-1,h-1), the shape PAINT used to fill.
Sub fillMountain (w As Long, h As Long, c As _Unsigned Long)
    Dim yy As Long, half As Single
    For yy = 0 To h - 1
        half = (w / 2) * yy / (h - 1)
        Line (w / 2 - half, yy)-(w / 2 + half, yy), c
    Next
End Sub

'--- game

Sub addWater
    Dim this As Long
    this = newObject
    obj(this).id = idWater
    obj(this).img = _NewImage(SW, SH, 32)
    _Dest obj(this).img
    Line (0, SH - SH / 4)-Step(SW, SH / 4), darken(levelData.waterColor, 55), BF
    Line (0, SH - SH / 4)-Step(SW, SH / 7), darken(levelData.waterColor, 70), BF
    Line (0, SH - SH / 4)-Step(SW, SH / 9), darken(levelData.waterColor, 85), BF
    Line (0, SH - SH / 4)-Step(SW, SH / 11), levelData.waterColor, BF
    _Dest 0
End Sub

Sub drawObjects
    For i = 1 To totalObjects
        Select Case obj(i).id
            Case idPlatform
                _PutImage (obj(i).x + camera, obj(i).y), obj(i).img
            Case idGoal
                drawGoalGlyph obj(goal).x + camera, obj(goal).y + obj(goal).h / 2
            Case idAirJump
                drawAirJumpGlyph obj(i).x + camera, obj(i).y + obj(i).h / 2
            Case idCloud
                obj(i).x = obj(i).x - obj(i).xv
                If obj(i).x + obj(i).w < 0 Then obj(i).x = arenaWidth
                Line (obj(i).x + camera / 2.5, obj(i).y)-Step(obj(i).w, obj(i).h), _RGBA32(255, 255, 255, 30), BF
            Case idScene
                _PutImage (obj(i).x + camera / obj(i).xv, obj(i).y), obj(i).img
            Case idSky
                Line (0, 0)-(SW, SH), obj(i).color, BF
            Case idWater
                _PutImage (0, 0), obj(i).img
        End Select
    Next
End Sub

Sub processInput
    Dim button As Long

    If _KeyHit = 27 Then
        obj(hero).alive = TRUE
        obj(hero).yv = 0
        restartRequested = TRUE
        Exit Sub
    End If

    If obj(hero).alive = FALSE Then Exit Sub

    'keep hero moving forward
    If obj(hero).x + obj(hero).w < arenaWidth + SW Then obj(hero).x = obj(hero).x + 5

    While _MouseInput: Wend
    button = FALSE
    If _MouseButton(1) Then button = TRUE
    If _KeyDown(32) Then button = TRUE

    If button Then
        If jumpKeyDown = FALSE And (obj(hero).standing = TRUE Or airJumps > 0) Then
            If airJumps > 0 Then airJumps = airJumps - 1
            jumpKeyDown = TRUE
            obj(hero).standing = FALSE
            lastJump = 0
            obj(hero).yv = obj(hero).yv - gravity * jumpFactor
        Else
            lastJump = lastJump + 1
            If lastJump < 7 Then
                obj(hero).yv = obj(hero).yv - gravity * jumpFactor
            End If
        End If
    Else
        jumpKeyDown = FALSE
    End If
End Sub

Sub adjustCamera
    camera = SW / 4 - obj(hero).x
    If camera > 0 Then camera = 0
    If camera < -arenaWidth Then camera = -arenaWidth
End Sub

Sub drawHero
    Dim sx As Single, sy As Single, sw2 As Single, p As Long
    Line (obj(hero).x + camera, obj(hero).y)-Step(obj(hero).w, obj(hero).h), obj(hero).color, BF

    If obj(hero).alive Then
        If shadowCast Then
            'shadow already cast on a platform
            p = shadowCastOn
            sx = (obj(hero).x + 1) + camera
            sy = obj(p).y + 5
            sw2 = obj(hero).w - 2
            Do While sx < obj(p).x + camera
                sx = sx + 1
                sw2 = sw2 - 1
            Loop
            Do While sx + sw2 > obj(p).x + obj(p).w + camera
                sw2 = sw2 - 1
            Loop
            Line (sx, sy)-Step(sw2, 2), _RGBA32(0, 0, 0, 30), BF
        Else
            'cast shadow on water
            Line ((obj(hero).x + 1) + camera, SH - SH / 4 + SH / 22)-Step(obj(hero).w - 2, 2), _RGBA32(0, 0, 0, 30), BF
        End If
    End If
End Sub

Sub doPhysics
    Dim j As Long

    If Not obj(hero).alive Then Exit Sub

    obj(hero).standing = FALSE
    drowned = FALSE
    If obj(hero).y + obj(hero).yv + gravity > SH - SH / 4 + SH / 22 Then
        drowned = TRUE
        obj(hero).alive = FALSE
        Exit Sub
    End If

    shadowCast = FALSE
    For j = 1 To totalObjects
        If obj(j).id = idPlatform Then
            If obj(hero).x + obj(hero).w > obj(j).x And obj(hero).x < obj(j).x + obj(j).w Then
                shadowCast = TRUE
                shadowCastOn = j

                If obj(hero).y + obj(hero).yv + gravity < obj(j).y - (obj(hero).h - 5) Then
                    Exit For
                ElseIf obj(hero).y + obj(hero).yv + gravity <= obj(j).y - (obj(hero).h - 20) Then
                    obj(hero).standing = TRUE
                    obj(hero).y = obj(j).y - (obj(hero).h - 5)
                    Exit For
                ElseIf obj(hero).y >= obj(j).y - (obj(hero).h - 20) Then
                    obj(hero).alive = FALSE
                    Exit For
                End If
            End If
        End If
    Next

    If Not obj(hero).standing Then
        obj(hero).yv = obj(hero).yv + gravity
        If obj(hero).yv > gravityCap Then obj(hero).yv = gravityCap
        obj(hero).y = obj(hero).y + obj(hero).yv
        obj(hero).color = _RGB32(255, 255, 255)
    Else
        obj(hero).yv = 0
        obj(hero).color = _RGB32(200, 200, 200)
    End If
End Sub

Function hit& (a As Long, b As Long)
    hit& = FALSE
    If obj(a).x + obj(a).w > obj(b).x And obj(a).x <= obj(b).x + obj(b).w Then
        If obj(a).y + obj(a).h > obj(b).y And obj(a).y < obj(b).y + obj(b).h Then hit& = TRUE
    End If
End Function

Function darken~& (c As _Unsigned Long, pct As Long)
    darken~& = _RGB32(_Red32(c) * (pct / 100), _Green32(c) * (pct / 100), _Blue32(c) * (pct / 100))
End Function

Sub setLevel (level As Long)
    'the order of creation of objects is also the draw order

    Dim totalPlatforms As Long
    Dim this As Long, firstPlatform As Long

    resetObjects
    Select Case level
        Case 1
            arenaWidth = 3200
            totalPlatforms = 30
            levelData.landColor = _RGB32(194, 127, 67)
            levelData.waterColor = _RGB32(33, 166, 188)
            levelData.grassColor = _RGB32(83, 161, 72)

            this = newObject
            obj(this).id = idSky
            obj(this).color = _RGB32(67, 200, 205)

            addScene level

            addWater

            addClouds 5

            levelData.symbolSpacingX = 11
            levelData.symbolSpacingY = 11
            For i = 1 To totalPlatforms
                this = newObject
                obj(this).id = idPlatform
                obj(this).w = Rnd * 200 + 100
                obj(this).w = obj(this).w - (obj(this).w Mod 20)
                If i = 1 Then
                    firstPlatform = this
                    obj(this).h = 200
                    obj(this).x = Rnd * (arenaWidth / totalPlatforms)
                Else
                    obj(this).h = Rnd * 50 + 50
                    obj(this).x = obj(this - 1).x + obj(this - 1).w + (Rnd * (arenaWidth / (totalPlatforms * 1.5)))
                End If
                obj(this).y = (SH - SH / 4 + (SH / 20)) - obj(this).h
                drawPlatform this
            Next

            goal = newObject
            obj(goal).id = idGoal
            obj(goal).x = arenaWidth
            obj(goal).y = SH / 2
            obj(goal).h = 20
            obj(goal).w = 20

            hero = newObject
            obj(hero).x = obj(firstPlatform).x
            obj(hero).y = obj(firstPlatform).y - 25
            obj(hero).w = 15
            obj(hero).h = 30
            obj(hero).alive = TRUE
            obj(hero).standing = TRUE
    End Select
End Sub

Function newObject&
    totalObjects = totalObjects + 1
    If totalObjects > UBound(obj) Then
        ReDim _Preserve obj(totalObjects + 99) As gameObject
    End If
    newObject& = totalObjects
End Function

Sub resetObjects
    For i = 1 To UBound(obj)
        If obj(i).img <> 0 And obj(i).imgPointer = FALSE Then _FreeImage obj(i).img
        obj(i).id = 0: obj(i).w = 0: obj(i).h = 0: obj(i).img = 0
        obj(i).x = 0: obj(i).xv = 0: obj(i).y = 0: obj(i).yv = 0
        obj(i).imgPointer = 0: obj(i).standing = 0: obj(i).alive = 0
        obj(i).color = 0
    Next
    totalObjects = 0
End Sub

Sub drawPlatform (p As Long)
    Dim w As Long, h As Long, r As Long, c As _Unsigned Long, tmp As Long
    w = obj(p).w: h = obj(p).h
    obj(p).img = _NewImage(w, h, 32)

    ' body and decoration, drawn apart and copied over rows 10 to h-5 so
    ' the bottom 4 rows stay transparent
    tmp = _NewImage(w, h + 20, 32)
    _Dest tmp
    Line (0, 10)-(w - 1, h + 19), levelData.landColor, BF
    c = _RGB32(166, 111, 67)
    For x = -10 To w Step levelData.symbolSpacingX
        For y = 15 To h + 10 Step levelData.symbolSpacingY
            drawDecoration x, y, c
        Next
    Next
    _PutImage (0, 10), tmp, obj(p).img, (0, 10)-(w - 1, h - 5)
    _Dest obj(p).img ' switch away before freeing: QBJS flushes the old dest
    _FreeImage tmp

    ' grass with a highlight; the top corners are cut diagonally
    For r = 0 To 20
        If r <= 5 Then
            Line (6 - r, r)-(w - 7 + r, r), levelData.grassColor
            Line (6 - r, r)-(w - 7 + r, r), _RGBA32(255, 255, 255, 30)
        Else
            Line (0, r)-(w - 1, r), levelData.grassColor
            If r <= 10 Then Line (0, r)-(w - 1, r), _RGBA32(255, 255, 255, 30)
        End If
    Next

    ' side highlight and shade, bottom shadow line
    Line (0, 10)-(5, h - 5), _RGBA32(255, 255, 255, 30), BF
    Line (w - 6, 10)-(w - 1, h - 5), _RGBA32(0, 0, 0, 30), BF
    Line (0, h - 5)-(w - 1, h - 5), _RGBA32(0, 0, 0, 30)
    _Dest 0
End Sub

Sub addClouds (max As Long)
    Dim this As Long

    For i = 1 To max
        this = newObject
        obj(this).id = idCloud
        obj(this).x = Rnd * arenaWidth
        obj(this).y = Rnd * (SH / 2)
        obj(this).h = 30
        obj(this).w = arenaWidth / max
        obj(this).xv = Rnd
    Next
End Sub

Sub addScene (level As Long)
    Dim this As Long, firstItem As Long

    Select Case level
        Case 1
            'green mountains, 2 layers

            'farther range
            For i = 1 To 20
                this = newObject
                If i = 1 Then
                    firstItem = this
                    obj(this).img = _NewImage(SW, SH, 32)
                    _Dest obj(this).img
                    fillMountain SW, SH, _RGB32(100, 150, 122)
                    _Dest 0
                Else
                    obj(this).img = obj(firstItem).img
                    obj(this).imgPointer = TRUE
                End If

                obj(this).id = idScene
                obj(this).x = Rnd * arenaWidth
                obj(this).y = Rnd * (SH / 2)
                obj(this).xv = 2.5
            Next

            'closer range
            For i = 1 To 20
                this = newObject
                If i = 1 Then
                    firstItem = this
                    obj(this).img = _NewImage(SW, SH, 32)
                    _Dest obj(this).img
                    fillMountain SW, SH, _RGB32(78, 111, 67)
                    _Dest 0
                Else
                    obj(this).img = obj(firstItem).img
                    obj(this).imgPointer = TRUE
                End If

                obj(this).id = idScene
                obj(this).x = Rnd * arenaWidth
                obj(this).y = Rnd * (SH / 2)
                obj(this).xv = 2
            Next
    End Select
End Sub

Sub checkVictory
    Dim k As Long, msg As String
    If hit(hero, goal) Then
        msg = "Level complete!"
        _PrintString (SW / 2 - _PrintWidth(msg) / 2, SH / 2 - _FontHeight / 2), msg
        _Display
        restartRequested = TRUE
        Do: k = _KeyHit: Loop Until k = 0 ' drop keys already pressed
        Do
            _Limit 30
            k = _KeyHit
        Loop Until k > 0
    End If
End Sub
