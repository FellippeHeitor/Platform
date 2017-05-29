CONST objHero = 1
CONST objEnemy = 2
CONST objFloor = 3
CONST objBonus = 4
CONST objBackground = 5
CONST g = .98

TYPE Objects
    kind AS INTEGER
    x AS SINGLE
    xv AS SINGLE
    y AS SINGLE
    yv AS SINGLE
    w AS SINGLE
    h AS SINGLE
    color AS _UNSIGNED LONG
END TYPE

DIM SHARED Object(1 TO 100) AS Objects, TotalObjects AS LONG
DIM SHARED Hero AS LONG, BG AS LONG, Floor AS LONG
DIM SHARED Dead AS _BYTE

SCREEN _NEWIMAGE(800, 600, 32)
_PRINTMODE _KEEPBACKGROUND

BG = AddObject(objBackground, 0, 0, _WIDTH - 1, _HEIGHT - 1, _RGB32(61, 161, 222))
Floor = AddObject(objFloor, 20, _HEIGHT - _HEIGHT / 5, _WIDTH - _WIDTH / 5, 10, _RGB32(111, 89, 50))
Hero = AddObject(objHero, 25, Object(Floor).y - 21, 10, 20, _RGB32(127, 244, 127))

DO
    ProcessInput
    DoPhysics
    UpdateScreen
    _LIMIT 30
LOOP

FUNCTION AddObject (Kind AS INTEGER, x AS SINGLE, y AS SINGLE, w AS SINGLE, h AS SINGLE, c AS _UNSIGNED LONG)
    TotalObjects = TotalObjects + 1
    IF TotalObjects > UBOUND(Object) THEN
        REDIM _PRESERVE Object(1 TO UBOUND(Object) + 99) AS Objects
    END IF

    Object(TotalObjects).kind = Kind
    Object(TotalObjects).x = x
    Object(TotalObjects).y = y
    Object(TotalObjects).w = w
    Object(TotalObjects).h = h
    Object(TotalObjects).color = c

    AddObject = TotalObjects
END FUNCTION

SUB ProcessInput
    IF _KEYDOWN(19712) AND NOT Dead THEN
        IF Object(Hero).xv < 0 THEN
            Object(Hero).xv = Object(Hero).xv + 2
        ELSE
            Object(Hero).xv = 4
        END IF
    END IF
    IF _KEYDOWN(19200) AND NOT Dead THEN
        IF Object(Hero).xv > 0 THEN
            Object(Hero).xv = Object(Hero).xv - 2
        ELSE
            Object(Hero).xv = -4
        END IF
    END IF
    IF _KEYDOWN(18432) AND NOT Dead THEN IF Object(Hero).yv = 0 THEN Object(Hero).yv = -10
    IF _KEYDOWN(13) AND Dead THEN
        Dead = 0
        Object(Hero).x = 25
        Object(Hero).y = Object(Floor).y - 21
        Object(Hero).yv = 0
        Object(Hero).xv = 0
    END IF
END SUB

SUB DoPhysics
    FOR i = 1 TO TotalObjects
        IF Object(i).kind = objHero OR Object(i).kind = objEnemy THEN
            Object(i).x = Object(i).x + Object(i).xv
            Object(i).y = Object(i).y + Object(i).yv

            IF Object(i).x + Object(i).w >= Object(Floor).x AND Object(i).x < Object(Floor).x + Object(Floor).w THEN
                IF Object(i).y + Object(i).h > Object(Floor).y THEN
                    Object(i).y = Object(Floor).y - Object(i).h - 1
                    Object(i).yv = 0
                END IF
            ELSE
                Object(i).yv = Object(i).yv + g
            END IF

            IF Object(Hero).y > _HEIGHT THEN Dead = -1

            IF Object(i).xv > 0 THEN Object(i).xv = Object(i).xv - .1
            IF Object(i).xv < 0 THEN Object(i).xv = Object(i).xv + .1
            IF Object(i).yv <> 0 THEN Object(i).yv = Object(i).yv + g
        END IF
    NEXT
END SUB

SUB UpdateScreen
    DIM this AS Objects
    FOR i = 1 TO TotalObjects
        this = Object(i)
        LINE (this.x, this.y)-STEP(this.w, this.h), this.color, BF
    NEXT

    IF Dead THEN
        _PRINTSTRING (_WIDTH / 2 - _PRINTWIDTH("You're dead!") / 2, _HEIGHT / 2 - _FONTHEIGHT), "You're dead!"
        _PRINTSTRING (_WIDTH / 2 - _PRINTWIDTH("(hit ENTER)") / 2, _HEIGHT / 2 + _FONTHEIGHT), "(hit ENTER)"
    END IF

    _DISPLAY
END SUB

