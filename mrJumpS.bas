OPTION _EXPLICIT

CONST false = 0, true = NOT false

SCREEN _NEWIMAGE(800, 450, 32)

TYPE newLevel
    landColor AS _UNSIGNED LONG
    grassColor AS _UNSIGNED LONG
    waterColor AS _UNSIGNED LONG
    symbolSpacingX AS LONG
    symbolSpacingY AS LONG
END TYPE

TYPE newObject
    id AS LONG
    x AS SINGLE
    xv AS SINGLE
    y AS SINGLE
    yv AS SINGLE
    w AS LONG
    h AS LONG
    img AS LONG
    imgPointer AS _BYTE
    color AS _UNSIGNED LONG
    standing AS _BYTE
    alive AS _BYTE
END TYPE

CONST idPlatform = 1
CONST idGoal = 2
CONST idAirJump = 3
CONST idInfiniteJumps = 4
CONST idSpike = 5
CONST idCloud = 6
CONST idScene = 7
CONST idSky = 8
CONST idWater = 9

DIM SHARED thisLevel AS LONG
DIM SHARED arenaWidth AS LONG, i AS LONG
DIM SHARED x AS SINGLE, y AS SINGLE
DIM SHARED totalObjects AS LONG
DIM SHARED drowned AS _BYTE
DIM SHARED restartRequested AS _BYTE
DIM SHARED levelData AS newLevel
DIM SHARED platformDecoration AS STRING
DIM SHARED obj(100) AS newObject
DIM SHARED hero AS LONG
DIM SHARED goal AS LONG
DIM SHARED camera AS SINGLE
DIM SHARED gravity AS SINGLE
DIM SHARED goalGlyph AS STRING, airJumpGlyph AS STRING
DIM SHARED airJumps AS LONG

RANDOMIZE TIMER

goalGlyph = "C" + STR$(_RGB32(255, 255, 255)) + "e10f10g10 h8e8f6g6 h4 e4f2g1"
airJumpGlyph = "C" + STR$(_RGB32(255, 255, 255)) + "e10f10g10h10"
gravity = .8
thisLevel = 1

Restart:
setLevel thisLevel

DO
    processInput
    doPhysics
    adjustCamera
    drawObjects
    IF restartRequested THEN restartRequested = false: GOTO Restart
    IF NOT drowned THEN drawHero

    _DISPLAY
    _LIMIT 60
LOOP

SUB addWater
    DIM this AS LONG
    this = newObject
    obj(this).id = idWater
    obj(this).img = _NEWIMAGE(_WIDTH, _HEIGHT, 32)
    _DEST obj(this).img
    LINE (0, _HEIGHT - _HEIGHT / 4)-STEP(_WIDTH, _HEIGHT / 4), darken(levelData.waterColor, 55), BF
    LINE (0, _HEIGHT - _HEIGHT / 4)-STEP(_WIDTH, _HEIGHT / 7), darken(levelData.waterColor, 70), BF
    LINE (0, _HEIGHT - _HEIGHT / 4)-STEP(_WIDTH, _HEIGHT / 9), darken(levelData.waterColor, 85), BF
    LINE (0, _HEIGHT - _HEIGHT / 4)-STEP(_WIDTH, _HEIGHT / 11), levelData.waterColor, BF
    _DEST 0
END SUB

SUB drawObjects
    FOR i = 1 TO totalObjects
        SELECT CASE obj(i).id
            CASE idPlatform
                _PUTIMAGE (obj(i).x + camera, obj(i).y), obj(i).img
            CASE idGoal
                DRAW "bm" + STR$(obj(goal).x + camera) + "," + STR$(obj(goal).y + obj(goal).h / 2)
                DRAW goalGlyph
            CASE idAirJump
                DRAW "bm" + STR$(obj(i).x + camera) + "," + STR$(obj(i).y + obj(i).h / 2)
                DRAW airJumpGlyph
            CASE idCloud
                obj(i).x = obj(i).x - obj(i).xv
                IF obj(i).x + obj(i).w < 0 THEN obj(i).x = arenaWidth
                LINE (obj(i).x + camera / 2.5, obj(i).y)-STEP(obj(i).w, obj(i).h), _RGBA32(255, 255, 255, 30), BF
            CASE idScene
                _PUTIMAGE (obj(i).x + camera / obj(i).xv, obj(i).y), obj(i).img
            CASE idSky
                LINE (0, 0)-(_WIDTH, _HEIGHT), obj(i).color, BF
            CASE idWater
                _PUTIMAGE , obj(i).img
        END SELECT
    NEXT
END SUB

SUB processInput
    DIM button AS _BYTE

    IF _KEYHIT = 27 THEN
        obj(hero).alive = true
        obj(hero).yv = 0
        restartRequested = true
        EXIT SUB
    END IF

    IF obj(hero).alive = false THEN EXIT SUB
    IF obj(hero).x + obj(hero).w < arenaWidth + _WIDTH THEN obj(hero).x = obj(hero).x + 5

    'IF _KEYDOWN(19712) THEN 'character goes left, screen goes right
    '    obj(hero).x = obj(hero).x + 5
    'END IF

    'IF _KEYDOWN(19200) THEN 'character goes right, screen goes left
    '    obj(hero).x = obj(hero).x - 5
    'END IF

    STATIC lastJump!, jumpKeyDown AS _BYTE
    CONST jumpFactor = 3

    WHILE _MOUSEINPUT: WEND
    button = _MOUSEBUTTON(1) OR _KEYDOWN(32)

    IF button THEN '18432
        IF jumpKeyDown = false AND (obj(hero).standing = true OR airJumps > 0) THEN
            IF airJumps > 0 THEN airJumps = airJumps - 1
            jumpKeyDown = true
            obj(hero).standing = false
            lastJump! = 0
            obj(hero).yv = obj(hero).yv - gravity * jumpFactor
        ELSE
            lastJump! = lastJump! + 1
            IF lastJump! < 7 THEN
                obj(hero).yv = obj(hero).yv - gravity * jumpFactor
            END IF
        END IF
    ELSE
        jumpKeyDown = false
    END IF
END SUB

SUB adjustCamera
    camera = _WIDTH / 4 - obj(hero).x
    IF camera > 0 THEN camera = 0
    IF camera < -arenaWidth THEN camera = -arenaWidth
END SUB

SUB drawHero
    LINE (obj(hero).x + camera, obj(hero).y)-STEP(obj(hero).w, obj(hero).h), obj(hero).color, BF
END SUB

SUB doPhysics
    DIM this AS newObject
    DIM j AS LONG, shadowCast AS _BYTE

    IF NOT obj(hero).alive THEN
        _PRINTSTRING (0, 0), "Dead"
        _PRINTSTRING (0, 20), STR$((obj(hero).x / arenaWidth) * 100) + "%"
        EXIT SUB
    END IF

    CONST gravityCap = 15

    obj(hero).standing = false
    drowned = false
    IF obj(hero).y + obj(hero).yv + gravity > _HEIGHT - _HEIGHT / 4 + _HEIGHT / 22 THEN drowned = true: obj(hero).alive = false: EXIT SUB

    FOR j = 1 TO totalObjects
        IF obj(j).id = idPlatform THEN
            IF obj(hero).x + obj(hero).w > obj(j).x AND obj(hero).x < obj(j).x + obj(j).w THEN
                shadowCast = true
                LINE ((obj(hero).x - 3) + camera, obj(j).y + 5)-STEP(obj(hero).w + 6, 2), _RGBA32(0, 0, 0, 30), BF

                IF obj(hero).y + obj(hero).yv + gravity < obj(j).y - (obj(hero).h - 5) THEN
                    EXIT FOR
                ELSEIF obj(hero).y + obj(hero).yv + gravity <= obj(j).y - (obj(hero).h - 20) THEN
                    obj(hero).standing = true
                    obj(hero).y = obj(j).y - (obj(hero).h - 5)
                    EXIT FOR
                ELSEIF obj(hero).y >= obj(j).y - (obj(hero).h - 20) THEN
                    obj(hero).alive = false
                    EXIT FOR
                END IF
            END IF
        END IF
    NEXT

    IF NOT obj(hero).standing THEN
        obj(hero).yv = obj(hero).yv + gravity
        IF obj(hero).yv > gravityCap THEN obj(hero).yv = gravityCap
        obj(hero).y = obj(hero).y + obj(hero).yv
        obj(hero).color = _RGB32(255, 255, 255)
    ELSE
        _PRINTSTRING (0, 0), "Standing"
        obj(hero).yv = 0
        obj(hero).color = _RGB32(200, 200, 200)
    END IF

    IF hit(obj(hero), obj(goal)) THEN _AUTODISPLAY: _PRINTSTRING (_WIDTH / 2 - _PRINTWIDTH("Level complete!") / 2, _HEIGHT / 2 - _FONTHEIGHT / 2), "Level complete!": obj(hero).alive = false: SLEEP

    IF shadowCast = false THEN LINE ((obj(hero).x - 3) + camera, _HEIGHT - _HEIGHT / 4 + _HEIGHT / 22)-STEP(obj(hero).w + 6, 2), _RGBA32(0, 0, 0, 30), BF
END SUB

FUNCTION hit%% (obj1 AS newObject, obj2 AS newObject)
    hit%% = obj1.x + obj1.w > obj2.x AND obj1.x <= obj2.x + obj2.w AND obj1.y + obj1.h > obj2.y AND obj1.y < obj2.y + obj2.h
END FUNCTION

FUNCTION darken~& (WhichColor~&, ByHowMuch%)
    darken~& = _RGB32(_RED32(WhichColor~&) * (ByHowMuch% / 100), _GREEN32(WhichColor~&) * (ByHowMuch% / 100), _BLUE32(WhichColor~&) * (ByHowMuch% / 100))
END FUNCTION


SUB setLevel (level AS LONG)
    'the order of creation of objects is also the draw order

    DIM totalPlatforms AS LONG
    DIM this AS LONG, firstPlatform AS LONG

    resetObjects
    SELECT CASE level
        CASE 1
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

            platformDecoration = "c" + STR$(_RGB32(166, 111, 67)) + " bd5 e10r1g10r1e10r1g10r1e10r1g10r1e10r1g10"
            levelData.symbolSpacingX = 11
            levelData.symbolSpacingY = 11
            FOR i = 1 TO totalPlatforms
                this = newObject
                obj(this).id = idPlatform
                obj(this).w = RND * 200 + 50
                obj(this).w = obj(this).w - (obj(this).w MOD 20)
                IF i = 1 THEN
                    firstPlatform = this
                    obj(this).h = 200
                    obj(this).x = RND * (arenaWidth / totalPlatforms)
                ELSE
                    obj(this).h = RND * 50 + 50
                    obj(this).x = obj(this - 1).x + obj(this - 1).w + (RND * (arenaWidth / (totalPlatforms * 1.5)))
                END IF
                obj(this).y = (_HEIGHT - _HEIGHT / 4 + (_HEIGHT / 20)) - obj(this).h
                drawPlatform obj(this)
            NEXT

            goal = newObject
            obj(goal).id = idGoal
            obj(goal).x = arenaWidth
            obj(goal).y = _HEIGHT / 2
            obj(goal).h = 20
            obj(goal).w = 20

            hero = newObject
            obj(hero).x = obj(firstPlatform).x
            obj(hero).y = obj(firstPlatform).y - 25
            obj(hero).w = 15
            obj(hero).h = 30
            obj(hero).alive = true
            obj(hero).standing = true
    END SELECT
END SUB

FUNCTION newObject&
    totalObjects = totalObjects + 1
    IF totalObjects > UBOUND(obj) THEN
        REDIM _PRESERVE obj(totalObjects + 99) AS newObject
    END IF
    newObject& = totalObjects
END FUNCTION

SUB resetObjects
    DIM emptyObject AS newObject
    FOR i = 1 TO UBOUND(obj)
        IF obj(i).img < -1 AND obj(i).imgPointer = false THEN _FREEIMAGE obj(i).img
        obj(i) = emptyObject
    NEXT
    totalObjects = 0
END SUB

SUB drawPlatform (this AS newObject)
    this.img = _NEWIMAGE(this.w, this.h, 32)
    _DEST this.img
    LINE (0, 10)-STEP(this.w - 1, this.h - 1), levelData.landColor, BF
    FOR x = -10 TO this.w STEP levelData.symbolSpacingX
        FOR y = 15 TO this.h + 10 STEP levelData.symbolSpacingY
            PSET (x, y), levelData.landColor
            DRAW platformDecoration
        NEXT
    NEXT
    LINE (0, 0)-STEP(this.w - 1, 20), levelData.grassColor, BF
    LINE (0, 0)-STEP(this.w - 1, 10), _RGBA32(255, 255, 255, 30), BF
    LINE (0, 10)-STEP(5, this.h), _RGBA32(255, 255, 255, 30), BF
    LINE (this.w - 6, 10)-STEP(5, this.h), _RGBA32(0, 0, 0, 30), BF

    LINE (0, 5)-(5, 0), _RGB32(255, 0, 255)
    PAINT (0, 0), _RGB32(255, 0, 255), _RGB32(255, 0, 255)
    LINE (_WIDTH - 1, 5)-(_WIDTH - 6, 0), _RGB32(255, 0, 255)
    PAINT (_WIDTH - 1, 0), _RGB32(255, 0, 255), _RGB32(255, 0, 255)
    LINE (0, this.h - 4)-STEP(this.w, 3), _RGB32(255, 0, 255), BF
    _CLEARCOLOR _RGB32(255, 0, 255)
    LINE (0, this.h - 5)-STEP(this.w - 1, 5), _RGBA32(0, 0, 0, 30), BF
    _DEST 0
END SUB

SUB addClouds (max AS LONG)
    DIM this AS LONG

    FOR i = 1 TO max
        this = newObject
        obj(this).id = idCloud
        obj(this).x = RND * arenaWidth
        obj(this).y = RND * (_HEIGHT / 2)
        obj(this).h = 30
        obj(this).w = arenaWidth / max
        obj(this).xv = RND
    NEXT
END SUB

SUB addScene (level AS LONG)
    DIM this AS LONG, firstItem AS LONG

    SELECT CASE level
        CASE 1
            'green mountains, 2 layers

            'farther range
            FOR i = 1 TO 20
                this = newObject
                IF i = 1 THEN
                    firstItem = this
                    obj(this).img = _NEWIMAGE(_WIDTH, _HEIGHT, 32)
                    _DEST obj(this).img
                    LINE (0, _HEIGHT - 1)-(_WIDTH / 2, 0), _RGB32(100, 150, 122)
                    LINE -(_WIDTH - 1, _HEIGHT - 1), _RGB32(100, 150, 122)
                    LINE -(0, _HEIGHT - 1), _RGB32(100, 150, 122)
                    PAINT (_WIDTH / 2, _HEIGHT / 2), _RGB32(100, 150, 122), _RGB32(100, 150, 122)
                    _DEST 0
                ELSE
                    obj(this).img = obj(firstItem).img
                    obj(this).imgPointer = true
                END IF

                obj(this).id = idScene
                obj(this).x = RND * arenaWidth
                obj(this).y = RND * (_HEIGHT / 2)
                obj(this).xv = 2.5
            NEXT

            'closer range
            FOR i = 1 TO 20
                this = newObject
                IF i = 1 THEN
                    firstItem = this
                    obj(this).img = _NEWIMAGE(_WIDTH, _HEIGHT, 32)
                    _DEST obj(this).img
                    LINE (0, _HEIGHT - 1)-(_WIDTH / 2, 0), _RGB32(78, 111, 67)
                    LINE -(_WIDTH - 1, _HEIGHT - 1), _RGB32(78, 111, 67)
                    LINE -(0, _HEIGHT - 1), _RGB32(78, 111, 67)
                    PAINT (_WIDTH / 2, _HEIGHT / 2), _RGB32(78, 111, 67), _RGB32(78, 111, 67)
                    _DEST 0
                ELSE
                    obj(this).img = obj(firstItem).img
                    obj(this).imgPointer = true
                END IF

                obj(this).id = idScene
                obj(this).x = RND * arenaWidth
                obj(this).y = RND * (_HEIGHT / 2)
                obj(this).xv = 2
            NEXT
    END SELECT
END SUB
