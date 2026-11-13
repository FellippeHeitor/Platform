' Generates the game's sound effects as small WAV files in sfx/.
' Native QB64-PE tool; run it from the project folder after changing a sound:
'   ./qb64pe -x /path/to/tools/make_sfx.bas -o make_sfx && ./make_sfx /path/to/project
' The WAVs are committed, so the game (native or QBJS) just loads them.
'
' Every sound is a sum of soft sine "voices": a pitch glide with a smooth
' attack and an exponential fade, kept quiet (peaks well below full scale).

$Console:Only
Option _Explicit

Const RATE = 22050
Const PI2 = 6.283185307

ReDim Shared buf(0) As Single
Dim Shared bufLen As Long
Dim outDir As String
outDir = Command$(1)
If outDir = "" Then outDir = "."
outDir = outDir + "/sfx"
If Not _DirExists(outDir) Then MkDir outDir

' name, then voices: start Hz, end Hz, delay s, length s, volume
newSound .12: voice 330, 560, 0, .1, .22: voice 660, 1120, 0, .06, .05
saveWav outDir + "/jump.wav"

newSound .14: voice 520, 860, 0, .12, .18: voice 1040, 1720, .01, .08, .05
saveWav outDir + "/airjump.wav"

newSound .08: voice 230, 320, 0, .07, .14
saveWav outDir + "/flap.wav"

newSound .3: voice 1318, 1318, 0, .22, .12: voice 1760, 1760, .06, .24, .1
saveWav outDir + "/gem.wav"

newSound .2: voice 440, 440, 0, .09, .14: voice 660, 660, .08, .12, .14
saveWav outDir + "/switch.wav"

newSound .3: voice 300, 1200, 0, .28, .12: voice 450, 1800, .02, .24, .04
saveWav outDir + "/teleport.wav"

newSound .3: voice 1200, 300, 0, .26, .1: voice 1800, 450, .02, .22, .03
saveWav outDir + "/arrive.wav"

newSound .25: voice 660, 660, 0, .08, .1: voice 880, 880, .06, .08, .1: voice 1100, 1100, .12, .12, .1
saveWav outDir + "/mode.wav"

newSound .4: voice 420, 110, 0, .36, .24: voice 210, 70, .02, .34, .1
saveWav outDir + "/die.wav"

newSound .7: voice 523, 523, 0, .25, .14: voice 659, 659, .1, .25, .14: voice 784, 784, .2, .25, .14: voice 1046, 1046, .3, .38, .14
saveWav outDir + "/win.wav"

Print "Sounds written to "; outDir
System

Sub newSound (seconds As Single)
    bufLen = Int(seconds * RATE)
    ReDim buf(0 To bufLen - 1) As Single
End Sub

' One soft sine tone gliding from f1 to f2 Hz.
Sub voice (f1 As Single, f2 As Single, delay As Single, length As Single, vol As Single)
    Dim i As Long, n As Long, start As Long, t As Single, f As Single
    Dim phase As Double, env As Single, attack As Single
    start = Int(delay * RATE)
    n = Int(length * RATE)
    attack = .006
    For i = 0 To n - 1
        If start + i >= bufLen Then Exit For
        t = i / RATE
        f = f1 + (f2 - f1) * (i / n) ' linear glide
        phase = phase + PI2 * f / RATE
        If t < attack Then env = t / attack Else env = Exp(-5 * (t - attack) / length)
        env = env * (1 - i / n) ' reach silence exactly at the end, no click
        buf(start + i) = buf(start + i) + Sin(phase) * env * vol
    Next
End Sub

Sub saveWav (fileName As String)
    Dim i As Long, v As Long, d As String, h As String, ff As Long
    d = Space$(bufLen * 2)
    For i = 0 To bufLen - 1
        v = buf(i) * 32767
        If v > 32767 Then v = 32767
        If v < -32768 Then v = -32768
        Mid$(d, i * 2 + 1, 2) = MKI$(v)
    Next
    h = "RIFF" + MKL$(36 + Len(d)) + "WAVE"
    h = h + "fmt " + MKL$(16) + MKI$(1) + MKI$(1) + MKL$(RATE) + MKL$(RATE * 2) + MKI$(2) + MKI$(16)
    h = h + "data" + MKL$(Len(d))
    If _FileExists(fileName) Then Kill fileName
    ff = FreeFile
    Open fileName For Binary As #ff
    Put #ff, , h
    Put #ff, , d
    Close #ff
End Sub
