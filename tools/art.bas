' Draws the store art from the game's own drawing code (native only):
'   icon.png   1024 x 1024 app icon (rounded square, as macOS expects)
'   cover.png  630 x 500 itch.io cover image
'   banner.png 960 x 200 itch.io page header
' Includes the game with ART set, so once the sprites exist the game calls
' makeArt instead of starting. tools/release.sh builds and runs it:
'   ./art /folder/for/the/images
$Let ART = 1
'$Include:'../mrJumpS.bas'

Sub makeArt
    Dim dest As String, scene As Long, sq As Long, icon As Long, cover As Long, banner As Long
    Dim hero1 As Long, img As Long, i As Long, t As Single
    Dim px As Long, py As Long, x As Single, y As Single, w As Long, h As Long

    dest = Command$
    If dest = "" Then dest = "."

    ' a clean frame of level 1 (no hero, no text) to crop backdrops from
    loadLevel 1
    gameState = -1: hero.alive = FALSE
    camX = 600
    _Dest 0
    render
    scene = _CopyImage(0)

    '--- icon: 4x pixels of the meadow in a rounded square, the hero on top
    sq = _NewImage(824, 824, 32)
    _PutImage (0, 0)-(823, 823), scene, sq, (185, 200)-(185 + 205, 200 + 205)
    hero1 = makeHeroFrame(8, 0, 16)
    rawWrites hero1, FALSE
    ' feet on the platform (y 350 in the scene = 600 in the square)
    _PutImage (412 - (14.5 + HERO_PAD) * 16, 600 - (28 + HERO_PAD) * 16 + 4), hero1, sq

    icon = _NewImage(1024, 1024, 32)
    rawWrites icon, TRUE
    _Dest icon
    _Source sq
    For py = 0 To 1023
        For px = 0 To 1023
            x = px + .5: y = py + .5
            t = cov(sdBox(x, y, 512, 512, 412, 412, 185))
            If t > 0 Then
                pxBegin
                pxLayer Point(px - 100, py - 100), t
                pxEnd px, py
            End If
        Next
    Next
    _Source 0
    _Dest 0
    _SaveImage dest + "/icon.png", icon

    '--- cover: 2x pixels, the title, and the hero leaping over the gap
    cover = _NewImage(630, 500, 32)
    _PutImage (0, 0)-(629, 499), scene, cover, (160, 200)-(160 + 314, 200 + 249)
    ' darken the sky behind the title a little, as the title screen does
    _Dest cover
    For py = 0 To 230
        Line (0, py)-(629, py), _RGBA32(20, 30, 60, 70 * (1 - py / 230))
    Next
    ' the jump so far, as a dotted arc from the platform's edge
    For i = 0 To 7
        t = i / 8
        x = 424 + t * 74: y = 296 - Sin(t * 1.6) * 34
        Line (x - 3, y - 3)-(x + 2, y + 2), _RGBA32(255, 255, 255, 110 + i * 15), BF
    Next
    hero1 = makeHeroFrame(6, -.4, 4)
    rawWrites hero1, FALSE
    _PutImage (530 - (14 + HERO_PAD) * 4, 262 - (16 + HERO_PAD) * 4), hero1, cover

    ' title and tagline, in the game's crisp pixel font
    _Dest 0
    w = _PrintWidth("LEAP LINE"): h = _FontHeight
    img = crispText("LEAP LINE", _RGB32(30, 26, 46))
    _PutImage (315 - w * 3.5 + 7, 90 - h * 3.5 + 7)-Step(w * 7 - 1, h * 7 - 1), img, cover
    img = crispText("LEAP LINE", _RGB32(255, 255, 255))
    _PutImage (315 - w * 3.5, 90 - h * 3.5)-Step(w * 7 - 1, h * 7 - 1), img, cover
    w = _PrintWidth("Don't stop. Don't fall.")
    img = crispText("Don't stop. Don't fall.", _RGB32(30, 26, 46))
    _PutImage (315 - w + 2, 176 + 2)-Step(w * 2 - 1, h * 2 - 1), img, cover
    img = crispText("Don't stop. Don't fall.", _RGB32(255, 255, 255))
    _PutImage (315 - w, 176)-Step(w * 2 - 1, h * 2 - 1), img, cover
    _SaveImage dest + "/cover.png", cover

    '--- banner: a 2x strip of the meadow, the title on the left and the
    ' hero leaping over the gap on the right
    banner = _NewImage(960, 200, 32)
    _PutImage (0, 0)-(959, 199), scene, banner, (220, 290)-(220 + 479, 290 + 99)
    _Dest banner
    For py = 0 To 160
        Line (0, py)-(959, py), _RGBA32(20, 30, 60, 70 * (1 - py / 160))
    Next
    For i = 0 To 7
        t = i / 8
        x = 314 + t * 84: y = 116 - Sin(t * 1.6) * 34
        Line (x - 3, y - 3)-(x + 2, y + 2), _RGBA32(255, 255, 255, 110 + i * 15), BF
    Next
    hero1 = makeHeroFrame(6, -.4, 3)
    rawWrites hero1, FALSE
    _PutImage (432 - (14 + HERO_PAD) * 3, 84 - (16 + HERO_PAD) * 3), hero1, banner
    _Dest 0
    w = _PrintWidth("LEAP LINE")
    img = crispText("LEAP LINE", _RGB32(30, 26, 46))
    _PutImage (670 - w * 2.5 + 5, 64 - h * 2.5 + 5)-Step(w * 5 - 1, h * 5 - 1), img, banner
    img = crispText("LEAP LINE", _RGB32(255, 255, 255))
    _PutImage (670 - w * 2.5, 64 - h * 2.5)-Step(w * 5 - 1, h * 5 - 1), img, banner
    w = _PrintWidth("Tap to hop. Hold to jump higher.")
    img = crispText("Tap to hop. Hold to jump higher.", _RGB32(30, 26, 46))
    _PutImage (670 - w + 2, 120 + 2)-Step(w * 2 - 1, h * 2 - 1), img, banner
    img = crispText("Tap to hop. Hold to jump higher.", _RGB32(255, 255, 255))
    _PutImage (670 - w, 120)-Step(w * 2 - 1, h * 2 - 1), img, banner
    _SaveImage dest + "/banner.png", banner

    System
End Sub
