CONST true = -1, false = NOT true

CONST objHero = 1
CONST objEnemy = 2
CONST objFloor = 3
CONST objBonus = 4
CONST objBackground = 5
CONST objBlock = 6

CONST objShapeRect = 0
CONST objShapeRound = 1
CONST g = 1

TYPE Objects
    kind AS INTEGER
    shape AS INTEGER
    x AS INTEGER
    xv AS SINGLE
    y AS INTEGER
    yv AS SINGLE
    w AS INTEGER
    h AS INTEGER
    color AS _UNSIGNED LONG
    landedOn AS LONG
    taken AS _BYTE
END TYPE

REDIM SHARED Object(1 TO 100) AS Objects
DIM SHARED TotalObjects AS LONG
DIM SHARED Hero AS LONG, NewObj AS LONG
DIM SHARED Dead AS _BYTE, Camera AS LONG
DIM SHARED Points AS LONG

SCREEN _NEWIMAGE(800, 600, 32)
_PRINTMODE _KEEPBACKGROUND

DO
    Level = Level + 1
    ON Level GOSUB Level1, Level2

    DO
        ProcessInput
        DoPhysics
        UpdateScreen
        _LIMIT 40
    LOOP
LOOP

SYSTEM

Level1:
NewObj = AddObject(objBackground, 0, 0, _WIDTH * 2, _HEIGHT, _RGB32(61, 161, 222))

FOR i = 1 TO 10
    NewObj = AddObject(objBackground, RND * _WIDTH * 2, RND * _HEIGHT * .5, 50, 100, _RGB32(255, 255, 255))
    Object(NewObj).shape = objShapeRound
NEXT

NewObj = AddObject(objFloor, 20, _HEIGHT - _HEIGHT / 5, _WIDTH * 1.5, 150, _RGB32(111, 89, 50))
NewObj = AddObject(objFloor, 1300, _HEIGHT - _HEIGHT / 5, _WIDTH * 1.5, 150, _RGB32(111, 89, 50))

NewObj = AddObject(objFloor, 400, 400, 160, 10, _RGB32(111, 89, 50))
NewObj = AddObject(objFloor, 575, 330, 160, 10, _RGB32(111, 89, 50))

NewObj = AddObject(objBlock, 200, _HEIGHT - _HEIGHT / 5 - 16, 15, 15, _RGB32(216, 166, 50))
NewObj = AddObject(objBlock, 216, _HEIGHT - _HEIGHT / 5 - 16, 15, 15, _RGB32(216, 166, 50))
NewObj = AddObject(objBlock, 232, _HEIGHT - _HEIGHT / 5 - 16, 15, 15, _RGB32(216, 166, 50))
NewObj = AddObject(objBlock, 216, _HEIGHT - _HEIGHT / 5 - 32, 15, 15, _RGB32(216, 166, 50))
NewObj = AddObject(objBlock, 232, _HEIGHT - _HEIGHT / 5 - 32, 15, 15, _RGB32(216, 166, 50))
NewObj = AddObject(objBlock, 232, _HEIGHT - _HEIGHT / 5 - 48, 15, 15, _RGB32(216, 166, 50))

NewObj = AddObject(objBonus, 800, 270, 20, 10, _RGB32(249, 244, 55))
Object(NewObj).shape = objShapeRound

NewObj = AddObject(objBonus, 820, 320, 20, 10, _RGB32(249, 244, 55))
Object(NewObj).shape = objShapeRound

NewObj = AddObject(objBonus, 1200, _HEIGHT - _HEIGHT / 5 - 22, 20, 10, _RGB32(249, 244, 55))
Object(NewObj).shape = objShapeRound


Hero = AddObject(objHero, 25, _HEIGHT - _HEIGHT / 5 - 22, 10, 20, _RGB32(127, 244, 127))
RETURN

Level2:
RETURN

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
        IF _KEYDOWN(100306) THEN
            Object(Hero).x = Object(Hero).x + 1
            DO WHILE _KEYDOWN(19712): LOOP
        ELSE
            IF Object(Hero).xv < 0 THEN
                Object(Hero).xv = Object(Hero).xv + 2
            ELSE
                Object(Hero).xv = 4
            END IF
        END IF
    END IF
    IF _KEYDOWN(19200) AND NOT Dead THEN
        IF _KEYDOWN(100306) THEN
            Object(Hero).x = Object(Hero).x - 1
            DO WHILE _KEYDOWN(19200): LOOP
        ELSE
            IF Object(Hero).xv > 0 THEN
                Object(Hero).xv = Object(Hero).xv - 2
            ELSE
                Object(Hero).xv = -4
            END IF
        END IF
    END IF
    IF _KEYDOWN(18432) AND NOT Dead THEN
        IF Object(Hero).landedOn > 0 THEN Object(Hero).yv = -20: Object(Hero).landedOn = 0
    END IF
    IF _KEYDOWN(13) AND Dead THEN
        Dead = 0
        Object(Hero).x = 25
        Object(Hero).y = _HEIGHT - _HEIGHT / 5 - 22
        Object(Hero).yv = 0
        Object(Hero).xv = 0
        Object(Hero).landedOn = 0
    END IF
    IF _KEYDOWN(27) THEN SYSTEM
END SUB

SUB DoPhysics
    FOR i = 1 TO TotalObjects
        IF Object(i).kind = objHero OR Object(i).kind = objEnemy THEN
            Object(i).x = Object(i).x + Object(i).xv
            Object(i).y = Object(i).y + Object(i).yv

            IF Object(i).landedOn = 0 THEN
                Object(i).yv = Object(i).yv + g
            END IF

            FOR j = 1 TO TotalObjects
                IF Object(j).kind = objBonus AND Object(j).taken = false THEN
                    IF Object(i).y + Object(i).h >= Object(j).y AND Object(i).y <= Object(j).y + Object(j).h THEN
                        IF Object(i).x + Object(i).w > Object(j).x AND Object(i).x < Object(j).x + Object(j).w THEN
                            Object(j).taken = true
                            Points = Points + 10
                            EXIT FOR
                        END IF
                    END IF
                END IF

                IF Object(i).xv > 0 THEN
                    IF Object(j).kind = objBlock THEN
                        IF Object(i).y + Object(i).h >= Object(j).y AND Object(i).y <= Object(j).y + Object(j).h THEN
                            IF Object(i).x + Object(i).w > Object(j).x AND Object(i).x < Object(j).x + Object(j).w THEN
                                Object(i).x = Object(j).x - Object(i).w - 1
                                Object(i).xv = 0
                                EXIT FOR
                            END IF
                        END IF
                    END IF
                ELSEIF Object(i).xv < 0 THEN
                    IF Object(j).kind = objBlock THEN
                        IF Object(i).y + Object(i).h >= Object(j).y AND Object(i).y <= Object(j).y + Object(j).h THEN
                            IF Object(i).x + Object(i).w > Object(j).x AND Object(i).x < Object(j).x + Object(j).w THEN
                                Object(i).x = Object(j).x + Object(j).w + 1
                                Object(i).xv = 0
                                EXIT FOR
                            END IF
                        END IF
                    END IF
                END IF

                IF Object(i).yv >= 0 THEN
                    IF Object(j).kind = objFloor OR Object(j).kind = objBlock THEN
                        IF Object(i).x + Object(i).w >= Object(j).x AND Object(i).x <= Object(j).x + Object(j).w THEN
                            IF Object(i).y + Object(i).h > Object(j).y AND Object(i).y < Object(j).y + Object(j).h THEN
                                Object(i).y = Object(j).y - Object(i).h - 1
                                Object(i).yv = 0
                                Object(i).landedOn = j
                                EXIT FOR
                            END IF
                        ELSE
                            IF Object(i).landedOn = j THEN
                                Object(i).landedOn = 0
                                EXIT FOR
                            END IF
                        END IF
                    END IF
                END IF
            NEXT

            IF Object(Hero).y > _HEIGHT THEN Dead = true

            IF Object(i).xv > 0 THEN Object(i).xv = Object(i).xv - 1
            IF Object(i).xv < 0 THEN Object(i).xv = Object(i).xv + 1
            IF Object(i).yv <> 0 THEN Object(i).yv = Object(i).yv + g
        END IF
    NEXT

    IF Object(Hero).x + Camera > _WIDTH / 2 THEN
        Camera = _WIDTH / 2 - Object(Hero).x
    ELSEIF Object(Hero).x + Camera < _WIDTH / 5 THEN
        Camera = _WIDTH / 5 - Object(Hero).x
    END IF

    IF Camera > 0 THEN Camera = 0
END SUB

SUB UpdateScreen
    CLS

    DIM this AS Objects
    FOR i = 1 TO TotalObjects
        this = Object(i)
        IF this.kind = objBackground THEN thisCamera = Camera / 2 ELSE thisCamera = Camera
        IF this.taken THEN GOTO Continue
        IF this.shape = objShapeRect THEN
            LINE (this.x + thisCamera, this.y)-STEP(this.w, this.h), this.color, BF
            LINE (this.x + thisCamera, this.y)-STEP(this.w, this.h), _RGB32(0, 0, 0), B
            '_PRINTSTRING (this.x + Camera, this.y), LTRIM$(STR$(this.x)) + STR$(this.x + this.w)
        ELSEIF this.shape = objShapeRound THEN
            FOR k = 1 TO this.w
                CIRCLE (thisCamera + this.x + this.w / 2, this.y + this.h / 2), k, this.color, , , this.w / this.h
            NEXT
            CIRCLE (thisCamera + this.x + this.w / 2, this.y + this.h / 2), this.w, _RGB32(0, 0, 0), , , this.w / this.h
        END IF
        'IF this.kind = objHero AND this.landedOn > 0 THEN _PRINTSTRING (this.x + Camera, this.y - _FONTHEIGHT), "Landed on" + STR$(this.landedOn)

        Continue:
    NEXT

    IF Dead THEN
        _PRINTSTRING (_WIDTH / 2 - _PRINTWIDTH("You're dead!") / 2, _HEIGHT / 2 - _FONTHEIGHT), "You're dead!"
        _PRINTSTRING (_WIDTH / 2 - _PRINTWIDTH("(hit ENTER)") / 2, _HEIGHT / 2 + _FONTHEIGHT), "(hit ENTER)"
    END IF

    IF Points > 0 THEN _PRINTSTRING (0, 0), STR$(Points)

    _DISPLAY
END SUB

