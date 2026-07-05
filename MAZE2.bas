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
BraidMaze 8, 1.0
'ShowPortion 240, 255, 180, 191
saveMaze "testmaze2.map"


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
' ================================================
' BraidMaze - remove dead ends from an already-generated maze.
'   topOpenRows   - same value passed to GenerateMaze (the open band)
'   braidFraction - 1.0 removes ALL dead ends; lower keeps a random subset
' Cell (ix,iy) -> 2x2 room whose top-left tile is (1+3*ix, offsetY+1+3*iy).
' Direction codes match GenerateMaze: 0=N, 1=E, 2=S, 3=W.
' ================================================
Sub BraidMaze (topOpenRows As Integer, braidFraction As Single)
    Dim offsetY As Integer, maxCellY As Integer
    Dim ix As Integer, iy As Integer, d As Integer
    Dim bestD As Integer, nx As Integer, ny As Integer

    offsetY = topOpenRows
    If offsetY > 187 Then Exit Sub
    maxCellY = Int((187 - offsetY) / 3) + 1
    If maxCellY < 1 Then Exit Sub

    For iy = 0 To maxCellY - 1
        For ix = 0 To CELL_W - 1
            ' only act on live dead ends (degree recomputed as we go)
            If CellDegree(ix, iy, offsetY, maxCellY) = 1 Then
                If Rnd <= braidFraction Then
                    bestD = -1
                    For d = 0 To 3
                        If NeighbourValid(ix, iy, d, maxCellY) Then
                            If PassageOpen(ix, iy, d, offsetY) = 0 Then
                                If bestD = -1 Then bestD = d ' fallback: any closed side
                                nx = ix: ny = iy
                                Select Case d
                                    Case 0: ny = iy - 1
                                    Case 1: nx = ix + 1
                                    Case 2: ny = iy + 1
                                    Case 3: nx = ix - 1
                                End Select
                                ' prefer opening toward another dead end (kills two)
                                If CellDegree(nx, ny, offsetY, maxCellY) = 1 Then bestD = d
                            End If
                        End If
                    Next d
                    If bestD >= 0 Then CarveDir ix, iy, bestD, offsetY
                End If
            End If
        Next ix
    Next iy
End Sub

' Is direction d a valid neighbour cell (inside the grid)? 0=N 1=E 2=S 3=W
Function NeighbourValid% (ix As Integer, iy As Integer, d As Integer, maxCellY As Integer)
    NeighbourValid = 0
    Select Case d
        Case 0: If iy > 0 Then NeighbourValid = 1
        Case 1: If ix < CELL_W - 1 Then NeighbourValid = 1
        Case 2: If iy < maxCellY - 1 Then NeighbourValid = 1
        Case 3: If ix > 0 Then NeighbourValid = 1
    End Select
End Function

' Returns 1 if the passage from cell (ix,iy) in direction d is open.
Function PassageOpen% (ix As Integer, iy As Integer, d As Integer, offsetY As Integer)
    Dim x1 As Integer, y1 As Integer, x2 As Integer, y2 As Integer
    Select Case d
        Case 1 ' east
            x1 = 3 * (ix + 1): y1 = offsetY + 1 + 3 * iy: x2 = x1: y2 = y1 + 1
        Case 3 ' west
            x1 = 3 * ix: y1 = offsetY + 1 + 3 * iy: x2 = x1: y2 = y1 + 1
        Case 2 ' south
            y1 = offsetY + 3 * (iy + 1): x1 = 1 + 3 * ix: y2 = y1: x2 = x1 + 1
        Case 0 ' north
            y1 = offsetY + 3 * iy: x1 = 1 + 3 * ix: y2 = y1: x2 = x1 + 1
    End Select
    If maze(x1, y1) = 0 And maze(x2, y2) = 0 Then PassageOpen = 1 Else PassageOpen = 0
End Function

' Open the wall between cell (ix,iy) and its neighbour in direction d.
Sub CarveDir (ix As Integer, iy As Integer, d As Integer, offsetY As Integer)
    Dim x1 As Integer, y1 As Integer, x2 As Integer, y2 As Integer
    Select Case d
        Case 1 ' east
            x1 = 3 * (ix + 1): y1 = offsetY + 1 + 3 * iy: x2 = x1: y2 = y1 + 1
        Case 3 ' west
            x1 = 3 * ix: y1 = offsetY + 1 + 3 * iy: x2 = x1: y2 = y1 + 1
        Case 2 ' south
            y1 = offsetY + 3 * (iy + 1): x1 = 1 + 3 * ix: y2 = y1: x2 = x1 + 1
        Case 0 ' north
            y1 = offsetY + 3 * iy: x1 = 1 + 3 * ix: y2 = y1: x2 = x1 + 1
    End Select
    maze(x1, y1) = 0: maze(x2, y2) = 0
End Sub

' Count how many of a cell's four sides have an open passage (its degree).
Function CellDegree% (ix As Integer, iy As Integer, offsetY As Integer, maxCellY As Integer)
    Dim d As Integer, n As Integer
    n = 0
    For d = 0 To 3
        If NeighbourValid(ix, iy, d, maxCellY) Then
            If PassageOpen(ix, iy, d, offsetY) Then n = n + 1
        End If
    Next d
    CellDegree = n
End Function

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

