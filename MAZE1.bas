' ================================================
' QB64PE MAZE GENERATOR ROUTINE - FINAL VERSION (FIXED for topOpenRows=8)
' Array: 256 x 192 unsigned byte maze
' - Walls: 1 (always 1 tile thick)
' - Paths: 0 (always exactly 2 tiles wide/tall)
' - Top N rows: completely open (value 0) — parameter
' - Perimeter (left/right/bottom): fully walled
' - No entry/exit points
' - Perfect maze (recursive backtracker)
' ================================================

Const MAZE_W = 256
Const MAZE_H = 192
Const CELL_W = 85
Const CELL_H = 62 ' kept for reference; we now compute actual vertical cells dynamically

Dim Shared maze(0 To MAZE_W - 1, 0 To MAZE_H - 1) As _Unsigned _Byte

GenerateMaze 8
'ShowPortion 240, 255, 180, 191
saveMaze "testmaze.map"


' ================================================
' QB64PE MAZE GENERATOR - FIXED for larger topOpenRows
' ================================================

Sub GenerateMaze (topOpenRows As Integer)
    Randomize Timer ' ← change to RANDOMIZE 42 for repeatable maze

    Dim offsetY As Integer
    Dim maxCellY As Integer
    Dim visited As _Byte
    Dim stackX(0 To 10000) As Integer
    Dim stackY(0 To 10000) As Integer
    Dim stackPtr As Integer
    Dim dx(3) As Integer, dy(3) As Integer
    Dim dirs(3) As Integer
    Dim cx As Integer, cy As Integer, nx As Integer, ny As Integer
    Dim neighCount As Integer, chosen As Integer, d As Integer
    Dim bx As Integer, by As Integer, ix As Integer, iy As Integer
    Dim wx As Integer, wy As Integer, px As Integer, py As Integer
    Dim deltax As Integer, deltay As Integer

    dx(0) = 0: dy(0) = -1
    dx(1) = 1: dy(1) = 0
    dx(2) = 0: dy(2) = 1
    dx(3) = -1: dy(3) = 0

    ' Fill with walls
    For y = 0 To MAZE_H - 1
        For x = 0 To MAZE_W - 1
            maze(x, y) = 1
        Next x
    Next y

    ' Top rows completely open
    If topOpenRows > 0 And topOpenRows < MAZE_H Then
        For y = 0 To topOpenRows - 1
            For x = 0 To MAZE_W - 1
                maze(x, y) = 0
            Next x
        Next y
    End If

    offsetY = topOpenRows

    ' === NEW: compute how many vertical cells we can actually fit ===
    ' We reserve at least 2 bottom wall rows (rows 190-191) so the bottom
    ' perimeter stays fully walled, exactly like the original top=4 case.
    If offsetY > 187 Then
        maxCellY = 0
    Else
        maxCellY = Int((187 - offsetY) / 3) + 1
    End If

    If maxCellY < 1 Then
        ' Not enough space for any maze cells — just leave top open + walls
        Exit Sub
    End If

    ' Carve all 2x2 path rooms (now using the safe maxCellY)
    For iy = 0 To maxCellY - 1
        For ix = 0 To CELL_W - 1
            bx = 1 + 3 * ix
            by = offsetY + 1 + 3 * iy
            If by + 1 < MAZE_H Then
                maze(bx, by) = 0
                maze(bx + 1, by) = 0
                maze(bx, by + 1) = 0
                maze(bx + 1, by + 1) = 0
            End If
        Next ix
    Next iy

    ' Backtracker (now safe)
    ReDim visited(0 To CELL_W - 1, 0 To maxCellY - 1) As _Byte

    stackPtr = 0
    cx = Int(Rnd * CELL_W)
    cy = Int(Rnd * maxCellY)
    visited(cx, cy) = 1
    stackX(stackPtr) = cx
    stackY(stackPtr) = cy
    stackPtr = stackPtr + 1

    Do While stackPtr > 0
        cx = stackX(stackPtr - 1)
        cy = stackY(stackPtr - 1)

        neighCount = 0
        For d = 0 To 3
            nx = cx + dx(d)
            ny = cy + dy(d)
            If nx >= 0 And nx < CELL_W And ny >= 0 And ny < maxCellY Then
                If visited(nx, ny) = 0 Then
                    dirs(neighCount) = d
                    neighCount = neighCount + 1
                End If
            End If
        Next d

        If neighCount > 0 Then
            chosen = Int(Rnd * neighCount)
            d = dirs(chosen)
            nx = cx + dx(d)
            ny = cy + dy(d)

            Call CarvePassage(cx, cy, nx, ny, offsetY)

            visited(nx, ny) = 1
            stackX(stackPtr) = nx
            stackY(stackPtr) = ny
            stackPtr = stackPtr + 1
        Else
            stackPtr = stackPtr - 1
        End If
    Loop
End Sub

Sub CarvePassage (ix As Integer, iy As Integer, nix As Integer, niy As Integer, offsetY As Integer)
    deltax = nix - ix
    deltay = niy - iy
    If deltax = 1 Then ' east
        wx = 3 * (ix + 1)
        py = offsetY + 1 + 3 * iy
        maze(wx, py) = 0: maze(wx, py + 1) = 0
    ElseIf deltax = -1 Then ' west
        wx = 3 * ix
        py = offsetY + 1 + 3 * iy
        maze(wx, py) = 0: maze(wx, py + 1) = 0
    ElseIf deltay = 1 Then ' south
        wy = offsetY + 3 * (iy + 1)
        px = 1 + 3 * ix
        maze(px, wy) = 0: maze(px + 1, wy) = 0
    ElseIf deltay = -1 Then ' north
        wy = offsetY + 3 * iy
        px = 1 + 3 * ix
        maze(px, wy) = 0: maze(px + 1, wy) = 0
    End If
End Sub

Sub ShowPortion (sx As Integer, sx1 As Integer, sy As Integer, sy1 As Integer)
    Dim As Integer x, y
    For y = sy To sy1
        For x = sx To sx1
            If maze(x, y) = 1 Then Print "#"; Else Print ".";
        Next x
        Print
    Next y
End Sub

Sub saveMaze (filename As String)
    Open filename For Binary As #1
    Put #1, , maze()
    Close #1
End Sub

