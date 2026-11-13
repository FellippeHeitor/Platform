' Native-only level checker. Includes the game with HEADLESS set, so the game
' calls runLevelCheck (tools/solver.bm) instead of opening a window.
' Build from the QB64-PE folder:  ./qb64pe -x /path/to/levelcheck.bas -o levelcheck
$Console:Only
$Let HEADLESS = 1
'$Include:'mrJumpS.bas'
'$Include:'tools/solver.bm'
