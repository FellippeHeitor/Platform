OPTION _EXPLICIT

CONST false = 0, true = NOT false

SCREEN _NEWIMAGE(800, 450, 32)

TYPE newLevel
    skyColor AS _UNSIGNED LONG
    landColor AS _UNSIGNED LONG
    grassColor AS _UNSIGNED LONG
    decorationColor AS _UNSIGNED LONG
    waterColor1 AS _UNSIGNED LONG
    waterColor2 AS _UNSIGNED LONG
    waterColor3 AS _UNSIGNED LONG
    waterColor4 AS _UNSIGNED LONG
    symbolSpacingX AS INTEGER
    symbolSpacingY AS INTEGER
END TYPE

TYPE newObject
    x AS SINGLE
    y AS SINGLE
    yv AS SINGLE
    w AS INTEGER
    h AS INTEGER
    img AS LONG
    color AS _UNSIGNED LONG
    standing AS _BYTE
    alive AS _BYTE
END TYPE

DIM SHARED levels AS LONG, thisLevel AS LONG
DIM SHARED arenaWidth AS LONG, i AS LONG
DIM SHARED x AS SINGLE, y AS SINGLE
DIM SHARED totalObjects AS LONG

totalObjects = 30
levels = 1
DIM SHARED level(levels) AS newLevel
DIM SHARED symbol(levels) AS STRING
DIM SHARED obj(100) AS newObject
DIM SHARED hero AS newObject
DIM SHARED cloud(5) AS newObject
DIM SHARED camera AS SINGLE
DIM SHARED gravity AS SINGLE

arenaWidth = 3200
gravity = .6
RANDOMIZE TIMER

FOR i = 1 TO 5

NEXT

i = 1
obj(i).w = RND * 200 + 50
obj(i).w = obj(i).w - (obj(i).w MOD 20)
obj(i).h = 200
obj(i).x = RND * (arenaWidth / totalObjects)
obj(i).y = (_HEIGHT - _HEIGHT / 4 + (_HEIGHT / 20)) - obj(i).h
FOR i = 2 TO totalObjects
    obj(i).w = RND * 200 + 50
    obj(i).w = obj(i).w - (obj(i).w MOD 20)
    obj(i).h = RND * 50 + 50
    obj(i).x = obj(i - 1).x + obj(i - 1).w + (RND * (arenaWidth / totalObjects))
    obj(i).y = (_HEIGHT - _HEIGHT / 4 + (_HEIGHT / 20)) - obj(i).h
NEXT

symbol(1) = "bd5 e10r1g10r1e10r1g10r1e10r1g10r1e10r1g10"
level(1).symbolSpacingX = 11
level(1).symbolSpacingY = 11
level(1).skyColor = _RGB32(67, 183, 194)
level(1).landColor = _RGB32(194, 127, 67)
level(1).waterColor1 = _RGB32(33, 166, 188)
level(1).waterColor2 = _RGB32(33, 144, 172)
level(1).waterColor3 = _RGB32(33, 130, 155)
level(1).waterColor4 = _RGB32(33, 116, 155)
level(1).decorationColor = _RGB32(166, 111, 67)
level(1).grassColor = _RGB32(83, 161, 72)

thisLevel = thisLevel + 1

hero.x = obj(1).x + obj(1).w / 2
hero.y = obj(1).y - 25
hero.w = 30
hero.h = 30
hero.alive = true
hero.standing = true

DO
    drawSky
    drawWater
    drawPlatforms
    processInput
    adjustCamera
    doPhysics
    drawHero

    _DISPLAY
    _LIMIT 60
LOOP

SUB drawSky
    LINE (0, 0)-(_WIDTH, _HEIGHT), level(thisLevel).skyColor, BF
END SUB

SUB drawWater
    LINE (0, _HEIGHT - _HEIGHT / 4)-STEP(_WIDTH, _HEIGHT), level(thisLevel).waterColor4, BF
    LINE (0, _HEIGHT - _HEIGHT / 4)-STEP(_WIDTH, _HEIGHT / 7), level(thisLevel).waterColor3, BF
    LINE (0, _HEIGHT - _HEIGHT / 4)-STEP(_WIDTH, _HEIGHT / 9), level(thisLevel).waterColor2, BF
    LINE (0, _HEIGHT - _HEIGHT / 4)-STEP(_WIDTH, _HEIGHT / 11), level(thisLevel).waterColor1, BF
END SUB

SUB drawPlatforms
    FOR i = 1 TO totalObjects
        IF obj(i).img = 0 THEN
            obj(i).img = _NEWIMAGE(obj(i).w, obj(i).h, 32)
            _DEST obj(i).img
            LINE (0, 10)-STEP(obj(i).w - 1, obj(i).h - 1), level(thisLevel).landColor, BF
            FOR x = -10 TO obj(i).w STEP level(thisLevel).symbolSpacingX
                FOR y = 15 TO obj(i).h + 10 STEP level(thisLevel).symbolSpacingY
                    PSET (x, y), level(thisLevel).landColor
                    DRAW "C" + STR$(level(thisLevel).decorationColor)
                    DRAW symbol(thisLevel)
                NEXT
            NEXT
            LINE (0, 0)-STEP(obj(i).w - 1, 20), level(thisLevel).grassColor, BF
            LINE (0, 0)-STEP(obj(i).w - 1, 10), _RGBA32(255, 255, 255, 30), BF
            LINE (0, 10)-STEP(10, obj(i).h), _RGBA32(255, 255, 255, 30), BF
            LINE (obj(i).w - 11, 10)-STEP(10, obj(i).h), _RGBA32(0, 0, 0, 30), BF

            LINE (0, 5)-(5, 0), _RGB32(255, 0, 255)
            PAINT (0, 0), _RGB32(255, 0, 255), _RGB32(255, 0, 255)
            LINE (_WIDTH - 1, 5)-(_WIDTH - 6, 0), _RGB32(255, 0, 255)
            PAINT (_WIDTH - 1, 0), _RGB32(255, 0, 255), _RGB32(255, 0, 255)
            LINE (0, obj(i).h - 4)-STEP(obj(i).w, 3), _RGB32(255, 0, 255), BF
            _CLEARCOLOR _RGB32(255, 0, 255)
            LINE (0, obj(i).h - 5)-STEP(obj(i).w - 1, 5), _RGBA32(0, 0, 0, 30), BF
            _DEST 0
        END IF
        _PUTIMAGE (obj(i).x + camera, obj(i).y), obj(i).img
    NEXT
END SUB

SUB processInput

    IF _KEYHIT = 27 THEN hero.alive = true: hero.x = 0: hero.y = 0: hero.yv = 0

    IF hero.alive = false THEN EXIT SUB
    'IF hero.x + hero.w < arenaWidth + _WIDTH THEN hero.x = hero.x + 5

    IF _KEYDOWN(19712) THEN 'character goes left, screen goes right
        hero.x = hero.x + 5
    END IF

    IF _KEYDOWN(19200) THEN 'character goes right, screen goes left
        hero.x = hero.x - 5
    END IF

    STATIC lastJump!, jumpKeyDown AS _BYTE
    CONST jumpFactor = 3

    IF _KEYDOWN(18432) THEN
        IF jumpKeyDown = false AND hero.standing = true THEN
            jumpKeyDown = true
            hero.standing = false
            lastJump! = TIMER
            hero.yv = hero.yv - gravity * jumpFactor
        ELSE
            IF TIMER - lastJump! < .15 THEN
                hero.yv = hero.yv - gravity * jumpFactor
            END IF
        END IF
    ELSE
        jumpKeyDown = false
    END IF
END SUB

SUB adjustCamera
    camera = _WIDTH / 4 - hero.x
    IF camera > 0 THEN camera = 0
    IF camera < -arenaWidth THEN camera = -arenaWidth
END SUB

SUB drawHero
    LINE (hero.x + camera, hero.y)-STEP(hero.w, hero.h), hero.color, BF
END SUB

SUB doPhysics
    DIM this AS newObject
    DIM j AS LONG

    IF NOT hero.alive THEN _PRINTSTRING (0, 0), "Dead": EXIT SUB

    CONST fallCap = 10

    IF NOT hero.standing THEN
        hero.yv = hero.yv + gravity
        IF hero.yv > fallCap THEN hero.yv = fallCap
        hero.y = hero.y + hero.yv
        hero.color = _RGB32(255, 255, 255)
    ELSE
        _PRINTSTRING (0, 0), "Standing"
        hero.yv = 0
        hero.color = _RGB32(200, 200, 200)
    END IF

    hero.standing = false
    FOR j = 1 TO totalObjects
        IF hero.x + hero.w > obj(j).x AND hero.x < obj(j).x + obj(j).w THEN
            LINE ((hero.x - 3) + camera, obj(j).y + 5)-STEP(hero.w + 6, 2), _RGBA32(0, 0, 0, 30), BF
            IF hero.y < obj(j).y - (hero.h - 5) THEN
                EXIT FOR
            ELSEIF hero.y <= obj(j).y - (hero.h - 15) THEN
                hero.standing = true
                hero.y = obj(j).y - (hero.h - 5)
                EXIT FOR
            ELSEIF hero.y >= obj(j).y - (hero.h - 20) THEN
                hero.alive = false
                EXIT FOR
            END IF
        END IF
    NEXT
END SUB
