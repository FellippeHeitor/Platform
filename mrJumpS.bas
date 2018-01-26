OPTION _EXPLICIT
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
    w AS INTEGER
    h AS INTEGER
    img AS LONG
END TYPE

DIM levels AS LONG, thisLevel AS LONG
DIM arenaWidth AS LONG, i AS LONG
DIM x AS SINGLE, y AS SINGLE
DIM totalObjects AS LONG

totalObjects = 30
levels = 1
DIM level(levels) AS newLevel
DIM symbol(levels) AS STRING
DIM obj(100) AS newObject
DIM camera AS LONG

arenaWidth = 3200
RANDOMIZE TIMER
i = 1
obj(i).w = RND * 200 + 50
obj(i).w = obj(i).w - (obj(i).w MOD 20)
obj(i).h = RND * 50 + 50
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
DO
    'sky
    LINE (0, 0)-(_WIDTH, _HEIGHT), level(thisLevel).skyColor, BF

    'water
    LINE (0, _HEIGHT - _HEIGHT / 4)-STEP(_WIDTH, _HEIGHT), level(thisLevel).waterColor4, BF
    LINE (0, _HEIGHT - _HEIGHT / 4)-STEP(_WIDTH, _HEIGHT / 7), level(thisLevel).waterColor3, BF
    LINE (0, _HEIGHT - _HEIGHT / 4)-STEP(_WIDTH, _HEIGHT / 9), level(thisLevel).waterColor2, BF
    LINE (0, _HEIGHT - _HEIGHT / 4)-STEP(_WIDTH, _HEIGHT / 11), level(thisLevel).waterColor1, BF

    'platforms
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
            LINE (0, 0)-(2, obj(i).h), _RGB32(255, 0, 255), BF
            LINE (obj(i).w - 3, 0)-STEP(2, obj(i).h), _RGB32(255, 0, 255), BF
            LINE (0, obj(i).h - 4)-STEP(obj(i).w, 3), _RGB32(255, 0, 255), BF
            _CLEARCOLOR _RGB32(255, 0, 255)
            'LINE (0, obj(i).h - 10)-STEP(2, obj(i).h), _RGBA32(0, 0, 0, 30), BF
            'LINE (obj(i).w - 4, obj(i).h - 10)-STEP(2, obj(i).h), _RGBA32(0, 0, 0, 30), BF
            LINE (3, obj(i).h - 5)-STEP(obj(i).w - 7, 5), _RGBA32(0, 0, 0, 30), BF
            _DEST 0
        END IF
        _PUTIMAGE (obj(i).x + camera, obj(i).y), obj(i).img
    NEXT

    IF _KEYDOWN(19712) THEN 'character goes left, screen goes right
        camera = camera - 15
    END IF

    IF _KEYDOWN(19200) THEN 'character goes right, screen goes left
        camera = camera + 15
    END IF

    'camera = camera - 5

    IF camera > 0 THEN camera = 0
    IF camera < -arenaWidth THEN camera = -arenaWidth
    _DISPLAY
    _LIMIT 30
LOOP
