device ZXSPECTRUMNEXT

;attr bytes
; Bit:  7      6      5    4    3      2    1    0
;       FLASH  BRIGHT P2   P1   P0     I2   I1   I0
; Colour codes: 0=black, 1=blue, 2=red, 3=magenta, 4=green, 5=cyan, 6=yellow, 7=white.

HUD_ATTR        equ %01110000                       ; BRIGHT yellow paper, black ink
HEALTH_ATTR     equ %01110001
score_text      defb 22, 0, 0, "Score: ", $ff
hiscore_text    defb 22, 1, 0, "High : ", $ff
health_text     defb 22, 2, 0, "Health:", $ff
lives_text      defb 22, 0, 24, "Lives: ", $ff
keys_text       defb 22, 0, 13, "Keys:  / ", $ff
health_bar      defb 22, 2, 7, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128,128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, $ff
healthattr      equ $5847
initHealthBlock equ 23
initHealth      equ 8

addScore:
        ld hl, score0
.addScore1:
        ld a, (hl)
        cp 9
        jr z, .scoreCarry
        inc (hl)
        ret

.scoreCarry:
        ld (hl), 0
        dec hl
        ld a, l
        cp score3 / 256
        jr nz, .addScore1
        ret

newGame:
        ld a, 3
        ld (playerLives), a
        ld a, 0
        ld (playerKeys), a
        ld (score3), a
        ld (score2), a
        ld (score1), a
        ld (score0), a

        ld a, initHealth
        ld (playerHealth), a
        
        ld a, initHealthBlock
        ld (healthBlock), a
        
        ld iy, health_bar
        call displayText

        call showLives
        call showKeys
        call showScore        
        ret

takeDamage:
        ld a, (playerHealth)                        ; get current health value
        dec a                                       ; take damage !
        ld (playerHealth), a                        ; set it back
        ld e,  a                                    ; preserve in E
        
        ld b, 2                                     ; set row 2
        ld a, (healthBlock)                         ; get current health block
        add a, 7                                    ; add starting column
        ld c, a                                     ; set column for display
        ld a, 136                                   ; udg graphic to use, 136 is 0 length, 128 is full block strength
        sub e                                       ; deduct current health block value
        call displayChar                            ; display the char
        ld a, e                                     ; get health value back
        and a                                       ; was it 0?
        ret nz                                      ; return if not

; block now empty -> redraw it as fully empty (136), then move left
        ld a, 8                                     ; full health block value
        ld (playerHealth), a                        ; set it
        ld a, (healthBlock)                         ; but health block value needs to reduce
        dec a                                       ; deduct 1
        ld (healthBlock), a                         ; save health block value
        ret nz                                      ; return if still alive

lostLife:
        ld a, initHealth                            ; reset health of current block
        ld (playerHealth), a
        
        ld a, initHealthBlock                       ; reset count of health blocks
        ld (healthBlock), a
        
        ld iy, health_bar                           ; show the full strength health bar
        call displayText

        ld a, (playerLives)                         ; get player lives
        dec a                                       ; - 1
        and 3                                       ; don't overflow
        ld (playerLives), a                         ; save it
        call showLives                              ; show it

        ret                                         ; return


showScore:
        ld bc, 7
        ld de, score3
        ld a, (de)
        add a, "0"
        call displayChar
        inc de
        ld a, (de)
        add a, "0"
        call displayChar
        inc de
        ld a, (de)
        add a, "0"
        call displayChar
        inc de
        ld a, (de)
        add a, "0"
        call displayChar

        ret


showLives:
        ld iy, lives_text
        call displayText

        ld bc, 31
        ld a, (playerLives)
        call DisplayDigit
        ret

showKeys:
        ld iy, keys_text
        call displayText
        ld bc, 19
        ld a, (playerKeys)
        call DisplayDigit

        ld bc, 21
        ld a, KEY_COUNT 
        call DisplayDigit
        ret


initHUD:
    ; clear top third of display file ($4000-$47FF) so the band is clean
        ld hl, $4000
        ld (hl), 0
        ld de, $4001
        ld bc, 2048 - 1
        ldir

    ; flood top 3 char rows of attributes ($5800-$587F) with yellow
        ld hl, $5800
        ld (hl), HUD_ATTR
        ld de, $5801
        ld bc, 96 - 1
        ldir

        ld iy, score_text
        call displayText

        ld iy, hiscore_text
        call displayText

        ld iy, health_text
        call displayText

;        ld iy, health_bar
;        call displayText

        ld hl, $5847
        ld (hl), HEALTH_ATTR
        ld de, $5848
        ld bc, 24
        ldir

;        call showLives
;        call showKeys
        ret


dist    db 0
paletteFlip db 0
paletteDelay db 0
floodInProgress db 0
; ============================================================
; floodFill - BFS from (floodTargetX,floodTargetY). Fills the
; distance field: 0 at target, increasing outward, clamped at
; 254. 255 = wall/unvisited/unreachable. INERT until called.
; ============================================================
floodFill:
        ld a, 0                                     ; ready to initialise
        ld (qHeadIdx), a                            ; set q head to 0
        ld (qTailIdx), a                            ; set q tail to 0
        ld (qCount), a                              ; set q depth to 0

; ============================================================
; clearDistanceField - set all 49152 field bytes to 255
; (255 = unvisited/wall). Pages each of the 6 field pages into
; slot 6 and floods it.
; ============================================================
.clearDistanceField:
        ld a, DFIELD_PAGE           ; first field page
        ld b, 6                     ; six pages to clear
.clrPage:
        push bc
        nextreg $56, a              ; page this 8K bank into slot 6 ($C000)
        push af
        ; smear 255 across $C000..$DFFF (8192 bytes)
        ld hl, $C000
        ld (hl), 255
        ld de, $C001
        ld bc, 8192 - 1
        ldir
        pop af
        inc a                       ; next page
        pop bc
        djnz .clrPage


        ld a, (floodTargetY)                        ; get our target cell Y
        ld d, a                                     ; put in D
        ld a, (floodTargetX)                        ; get out target cell X
        ld e, a                                     ; put in E

        ld h, d                                     ; Y also in H
        ld l, e                                     ; X also in L
        xor a                                       ; a = 0
        call putFieldByte                           ; field[target] = 0
        call qPushDE                                ; push target (d = y, e = x)

.mainLoop:
        ld a, (qCount)                              ; get the count of items on the queue
        or a
        ret z                                       ; empty -> done

        ; qPopDE is only called from here
        ; it's effectively the driver for the processing for this tile
        call qPopDE                                 ; DE = current cell (D=y, E=x)
        ld b, e                                     ; b = X    ** note opposite of DE
        ld c, d                                     ; c = Y
        GET_WORLD_VALUE DFIELD_PAGE, USE_BC
        ld (dist), a                                ; save distance
        cp FLOOD_LIMIT
        jr nc, .mainLoop

        ; ----------------------------------------------------------------------------
        ; we've popped a tile of the queue (having previously processed it)
        ; now we want to look at it's neighbours, i.e. x-1, y; x+1, y; x, y-1; x, y+1 
        ; ----------------------------------------------------------------------------
.skip
        ; LEFT
        ld a, e                                     ; get tile X
        or a                                        ; test for 0, lhs of maze
        jr z, .skipL                                ; branch if so, nothing to do
        dec a                                       ; get x - 1
        ld l, a                                     ; set L = X - 1 to test it
        ld h, d                                     ; set H = y  to test it
        call .tryCell                               ; do the test. HL is now x-1, y
.skipL:
        ; RIGHT
        ld a, e                                     ; get tile X
        cp 255                                      ; test for 255, rhs of maze
        jr z, .skipR                                ; branch if so, nothing to do
        inc a                                       ; get X + 1
        ld l, a                                     ; set L = X + 1 to test it
        ld h, d                                     ; set H = y to test it
        call .tryCell                               ; do the test. HL is now x+1, y
.skipR:
        ; UP
        ld a, d                                     ; get tile Y
        or a                                        ; test for 0, top of maze
        jr z, .skipU                                ; branch if so, nothing to do
        dec a                                       ; get y -1
        ld l, e                                     ; set L = X to test it
        ld h, a                                     ; set H = y - 1 to test it
        call .tryCell                               ; do the test, HL is now x, y-1
.skipU:
        ; DOWN
        ld a, d
        cp 191
        jr z, .skipD
        inc a
        ld l, e
        ld h, a
        call .tryCell
.skipD:
        jr .mainLoop

.tryCell:
; test one of the x +/- 1, y+/- 1 tiles
; here DE = yx of the tile taken off the queue
;      HL = tile being tested, i.e. +/- 1 of x or y
        push de

        ld b, h
        ld c, l
;        LD h, b
;        ld l, c

        ; H = y, L = x (of tile being tested, NOT the tile popped of the queue (this is held in DE))
        ; get map byte at this tile position; i.e. return A=0 (path) or A=1 (wall)
        ld a, h
        srl a
        srl a
        srl a
        srl a
        srl a
        ld e, a
        add a, TILEMAP_PAGE
        nextreg $56, a
        ld a, h
        and $1F
        ld h, a
        add hl, $C000
        ld a, (hl)

        cp MAP_WALL                                 ; is it a wall?
        jr z, .tcDone                               ; wall, the distance value is left as default 255 value

        ; H = y, L = x
        ; get distance value for this tile
        ld h, b
        ld l, c
        
        ld a, e
        add a, DFIELD_PAGE
        nextreg $56, a
        ld a, h
        and $1F
        ld h, a
        add hl, $C000
        ld a, (hl)

        ld h, b
        ld l, c
        
        cp 255
        jr nz, .tcDone                              ; branch if we've already visited this tile

        ld a, (dist)                                ; get distance for original tile XY (from mainloop)
        cp 254
        jr nc, .clampMax                            ; C >= 254 -> store 254
        inc a                                       ; C+1
        jr .storeDist
.clampMax:
        ld a, 254
.storeDist:
        call putFieldByte                           ; put this tested tile into the distance map
        ld d, b
        ld e, c
        ;ex de, hl                                   ; we want to push this tested tile onto the queue, but need it in DE
        call qPushDE
.tcDone:

        pop de
        ret

putFieldByte:
; HL = YX tile into our distance map
; we set distanceMap(x,y) = A
;        push hl                                     ; preserve HL
        push af                                     ; preserve AF, we need A to set the value
        ld a, h
        srl a
        srl a
        srl a
        srl a
        srl a
        add a, DFIELD_PAGE
        nextreg $56, a
        ld a, h
        and $1F
        ld h, a
        add hl, $C000
        pop af                                      ; restore A to set value
        ld (hl), a
;        pop hl
        ret


; ---- push cell offset in DE onto queue ----
; DE = YX
; add this to our ring buffer for processing
qPushDE:
; DE = YX, add to ring buffer
        ld a, (qTailIdx)            ; tail index (byte, 0-255)
        ld l, a
        ld h, 0
        add hl, hl                  ; *2 (word entries)
        add hl, floodQueue                  ; HL -> slot
        ld (hl), e
        inc hl
        ld (hl), d
        ld a, (qTailIdx)
        inc a                       ; tail+1, wraps 255->0 automatically (byte)
        ld (qTailIdx), a
        ld a, (qCount)
        inc a
        ld (qCount), a
        ret

; ---- pop cell offset from queue into DE ----
qPopDE:
        ld a, (qHeadIdx)            ; head index (byte)
        ld l, a
        ld h, 0
        add hl, hl                  ; *2
        add hl, floodQueue                  ; HL -> slot
        ld e, (hl)
        inc hl
        ld d, (hl)
        ld a, (qHeadIdx)
        inc a                       ; head+1, wraps automatically
        ld (qHeadIdx), a
        ld a, (qCount)
        dec a
        ld (qCount), a
        ret


buildMapImage:
        ld c, 0                                     ; Y tile co-ord
.rowLoop:
        ld b, 0                                     ; X tile co-ord
.colLoop:
        ld h, c                                     ; get Y
        ld l, b                                     ; get X
 
        ; calculate map page
        ld a, h
        srl a
        srl a
        srl a
        srl a
        srl a
        ld e, a                                     ; keep the page offset
        add a, MAP_PAGE                             
        nextreg $56, a                              ; page in the map page
        ld a, h
        and $1F
        ld h, a
        add hl, $C000
        ld a, (hl)                                  ; get map tile at this cell
        cp 1                                        ; test for 1 (wall)
        jr nz, .checkFlood                          ; path or something else -> check flood field
        ld d, L2_WALL                               ; wall -> red
        jr .haveColour                              ; walls never flooded
 
.checkFlood:
        ; HL still points at the cell's slot-6 address. The field uses the
        ; same layout, so the SAME HL is correct once we page the field bank in.
        ld d, L2_PATH
        ld a, e                                     ; page offset (y/32) saved earlier
        add a, DFIELD_PAGE                          ; field base page
        nextreg $56, a                              ; page field bank into slot 6
        ld a, (hl)                                  ; A = distance value at this cell
        cp 255                             ; <= FLOOD_LIMIT ?
        jr Z, .haveColour                          ; 255 (or > limit) -> not flooded, keep white
        ld d, L2_FLOOD                              ; flooded -> yellow
 
.haveColour:
        ; the offsets etc into the radar map will be the same
        ; we just need to page in the correct page and set the pixel
        ld a, e                                     ; retrieve the page offset from earlier
        add a, L2_PAGE                              ; add in the radar base
        nextreg $56, a                              ; page in the radar page
 
        ld a, d                                     ; get pixel colour from above
        ld (hl), a                                  ; put into radar map
        inc b
        jr nz, .colLoop
        inc c
        ld a, c
        cp 192
        jr nz, .rowLoop
        ret





vdirTable: db 1, 2, 4, 8             ; vdir_left, right, down, up
initBaddies:
; ============================================================
; initBaddies - place baddieCount baddies at random valid 2x2
; positions in the maze. Each needs its 2x2 tile footprint clear.
; Sets world pixel position, tile position, a random direction,
; sprite index (1..N, player is sprite 0), and pattern 0.
; Setup-time only: uses rejection loops freely (timing irrelevant).
; Assumes: rnd8 returns raw 0-255 in A; GET_WORLD_VALUE takes
;          B=tileX, C=tileY, returns tile byte in A (0 = open).
; ============================================================
        ld ix, baddieData
        ld b, baddieCount           ; loop counter (B not used by inner logic until call)
.nextBaddie:
        push bc                     ; preserve outer counter

        ; --- find a random clear 2x2 tile (tx in C-ish, ty) ---
.tryPos:
        ; random tile X 0..254
.rx:    call rnd8
        cp 255
        jr z, .rx                   ; reject 255 (no room for tx+1)
        ld d, a                     ; D = candidate tileX

        ; random tile Y 0..190
.ry:    call rnd8
        cp 8
        jr c, .ry
        cp 191
        jr nc, .ry                  ; reject 191..255 (need ty in 0..190)
        ld e, a                     ; E = candidate tileY

.loop
        ; --- test all four tiles of the 2x2 footprint are open ---
        ld b, d
        ld c, e
        GET_WORLD_VALUE TILEMAP_PAGE, USE_BC              ; (tx, ty)
        and a
        jr nz, .tryPos              ; wall -> reject, draw again

        ld b, d
        ld c, e
        inc b
        GET_WORLD_VALUE TILEMAP_PAGE, USE_BC              ; (tx+1, ty)
        and a
        jr nz, .tryPos

        ld b, d
        ld c, e        
        inc c
        GET_WORLD_VALUE TILEMAP_PAGE, USE_BC              ; (tx, ty+1)
        and a
        jr nz, .tryPos

        ld b, d
        inc b
        ld c, e
        inc c
        GET_WORLD_VALUE TILEMAP_PAGE, USE_BC              ; (tx+1, ty+1)
        and a
        jp nz, .tryPos

        ; --- position is valid: D=tileX, E=tileY. Fill the record ---
        ld a, d
        ld (ix + baddieRecord.tileX), a
        ld a, e
        ld (ix + baddieRecord.tileY), a

        ; world pixel X = tileX * 8  (HL = D*8)
        ld h, 0
        ld l, d
        add hl, hl
        add hl, hl
        add hl, hl                  ; HL = tileX * 8
        ld a, l
        ld (ix + baddieRecord.lowX), a
        ld a, h
        ld (ix + baddieRecord.highX), a

        ; world pixel Y = tileY * 8
        ld h, 0
        ld l, e
        add hl, hl
        add hl, hl
        add hl, hl                  ; HL = tileY * 8
        ld a, l
        ld (ix + baddieRecord.lowY), a
        ld a, h
        ld (ix + baddieRecord.highY), a

        ; random initial direction 0..3 (bit-number form, as your dir uses)
        call rnd8
        and %00000011
        ld hl, vdirTable
        add hl, a                    ; Z80N
        ld a, (hl)
        ld (ix + baddieRecord.dir), a

        ld a, 1
        ld (ix + baddieRecord.pattern), a
        ld a, mode_auto
        ld (ix +baddieRecord.mode), a

        ; sprite index: baddies are sprites 1..N.
        ; recover which baddie we're on: outer counter still on stack.
        pop bc                      ; B = remaining count (baddieCount..1)
        ld a, baddieCount
        sub b                       ; A = 0..N-1 (how many done so far)
        inc a                       ; A = 1..N  (sprite slot, player is 0)
        ld (ix + baddieRecord.index), a
        push bc                     ; restore for the djnz below

        ; advance IX to next record
        ld de, baddieRecord
        add ix, de

        pop bc
        dec b
        jp nz, .nextBaddie
        ret

setClipping:
        nextreg $1C, %00001000                      ; Reset tilemap clip window index (bit 3 = 1)

    ; Write the four clip coordinates to register $1B
    ; X values are in 2-pixel units (0-159 = full 320px width)
    ; Y values are 1:1 pixels (0-255)
    ; 4px border = inset of 2 X-units and 4 Y-pixels
        nextreg $1B, 2                              ; X1 = 2   → left edge  = pixel 4
        nextreg $1B, 157                            ; X2 = 157 → right edge = pixel 315 (319-4)
        nextreg $1b, 64                             ; Y1 = 64, top 4 border lines + top 4 ULA lines
        nextreg $1B, 251                            ; Y2 = 251 → bottom edge= pixel 251 (255-4)

    ; setSpriteClip - clip sprites to the play area (below the HUD).
    ; Over-border mode is active, so:
    ;   - X coords use the SAME doubling as the tilemap clip (copy 2,157)
    ;   - Y coords are in sprite space: ULA-origin pixel + 32
    ;       tilemap top  pixel 64  -> 64+32 = 96
    ;       tilemap bot  pixel 251 -> 283 (overflows) -> clamp to 255
    ; Requires $15 bit 5 (clip-over-border) set - see note.
        NEXTREG $15, %00100011                      ; was %00010111; bit 5 = enable sprite clip over border

        nextreg $1C, 2                              ; bit 1 = reset the SPRITE clip index
        nextreg $19, 0                              ; X1 (doubled units, same as tilemap) -> pixel 4
        nextreg $19, 159                            ; X2 -> pixel 315
        nextreg $19, 64                             ; Y1 = 64 -> top of play area
        nextreg $19, 255                            ; Y2 = clamp (283 overflows a byte; screen edge handles bottom)
        ret
