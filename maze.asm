INCLUDE "maze.inc"
device ZXSPECTRUMNEXT
DIV_HL_8 MACRO
; simple 16-bit divide without the CALL/RET overhead
        srl h                                       ; divide by 2
        rr l
        srl h                                       ; divide by 4
        rr l
        srl h                                       ; divide by 8
        rr l
        ENDM

GET_WORLD_TILE MACRO
; given B= tile X, C= tile Y, return tile at this position in the world map
        ld h, c                                     ; read the Y tile coordinate of the top-left corner we want
                                                    ; put it in H (this is the same as multiplying cam_tile_y by 256)
        ld l, b                                     ; read the X tile coordinate into L
                                                    ; Result: HL now holds  cam_tile_y * 256 + cam_tile_x
                                                    ; This is the byte offset into "world" map.

    ; STEP 2: Calculate which 8K physical page the data lives in
        ld   a,h                                    ; take the high byte of the offset (which is cam_tile_y)
        srl  a                                      ; divide by 2
        srl  a                                      ; divide by 2 again  → now /4
        srl  a                                      ; /8
        srl  a                                      ; /16
        srl  a                                      ; /32   ← this is the same as cam_tile_y ÷ 32
                                                    ; Why divide by 32?
                                                    ;   Each page is 8192 bytes.
                                                    ;   Each row is 256 bytes.
                                                    ;   8192 ÷ 256 = exactly 32 rows per page.
                                                    ;   Therefore page number = 40 + (cam_tile_y ÷ 32)
        add  a,TILEMAP_PAGE                         ; add the starting page number
        nextreg $56,a                               ; set MMU slot 6 ($C000-$DFFF) to that page


    ; STEP 3: Keep only the part of the address that fits inside one 8K page
        ld   a,h                                    ; get the high byte again
        and  $1F                                    ; $1F is binary 00011111 → keeps only the lowest 5 bits
                                                    ; This is exactly the same as (cam_tile_y * 256 + cam_tile_x) modulo 8192
                                                    ; (because 8192 = 2^13 and we are discarding everything above bit 12)
        ld   h,a                                    ; HL now holds the offset *inside* the current 8K page

    ; STEP 4: add the page offset so we can read it
        add  hl, $C000                              ; HL = $C000 + offset_inside_page
                                                    ; HL now points directly at the first byte we want to copy
        ld a, (hl)                                  ; so get the byte
        ENDM

cam_px              equ 19*8
cam_py              equ 15*8
cam_tx              equ 19
cam_ty              equ 15

tilemapPage         db 0

player_px           dw 472                          ; world pixel position of sprite
player_py           dw 376
player_tile_x       db 0
player_tile_y       db 0
lastMove            db 1

move_delta          equ 1

min_px              equ 19 * 8
max_px              equ (255 - 20) * 8
min_py              equ 15 * 8
max_py              equ (191 - 16) * 8

dir_left            equ 0
dir_right           equ 1
dir_down            equ 2
dir_up              equ 3
vdir_left           equ 1
vdir_right          equ 2
vdir_down           equ 4
vdir_up             equ 8


    struct baddieRecord
index               byte
lowX                byte
highX               byte
lowY                byte
highY               byte
tileX               byte
tileY               byte
dir                 byte
pattern             byte
    ENDS

baddieCount         equ 20
baddieData          defs baddieRecord * baddieCount

; working x/y pixel co-ords to minimise LD N, (IX+N) calls
baddie_x            dw 00
baddie_y            dw 00

progStart:
        call spriteSetup

otherSetup:
        LD A, 0             ; Load speed index (3 = 28 MHz)
        NEXTREG $07, A

        ld a, 0
        out (254), a

        call setClipping
        call copy_visible_window
        call initHUD
        call showSprite

        call initBaddies
        call setupIM2

main:
        call keyProcess

        ld bc, 500
.delay
        dec bc
        ld a, b
        or c
        jr nz, .delay
        jr main


keyProcess:	
	    ld d, 0
chkKeyLeft:	
	    LD BC, $dffe                                ; keys Y U I O P
	    IN A, (C)                                   ; read port
	    BIT 1, A                                    ; check for "O"
	    JR NZ, chkKeyRight                          ; branch if not pressed
	    set dir_left, d
	
chkKeyRight:	
	    BIT 0, A                                    ; check for "P"
	    JR NZ, chkKeyDown                           ; branch if not pressed
	    set dir_right, d
	
chkKeyDown:	
        LD B, $FD                                   ; port is now $FDFE, keys G F D S A
	    IN A, (C)                                   ; read port
	    BIT 0, A                                    ; check "A" key
	    JR NZ, chkKeyUp                             ; branch if not pressed
	    set dir_down, d
	
chkKeyUp:	
        LD B, $FB                                   ; port is now $FBFE, keys T R E W Q
    	IN A, (C)                                   ; read port
    	BIT 0, A                                    ; check for "Q"
    	JR NZ, chkVert                              ; branch if not pressed
    	set dir_up, d
	
chkVert:	
    	ld e, 0                                     ; set mask to 0
    	ld a, (player_px)                           ; get player px (low byte   )
    	and 7                                       ; check bits 2-0, if 0 then vertical movement may be allowed
    	jr nz, chkHoriz
    	ld e, %00001100
	
chkHoriz:	
	    ld a, (player_py)                           ; get player px (low byte)
    	and 7                                       ; check bits 2-0 if 0 then horizontal movement may be allowed
    	jr nz, chkEnd
    	ld a, %00000011
    	or e
    	ld e, a
	
chkEnd:	
; d = keys pressed	
; e = vert/horiz potentially allowed	
	
	    ld a, d
	    and e
	    ld d, a
	
; d is keys pressed potentially allowed	
	
	    ld e, 0

.testDirections
    	bit dir_left, d
    	call nz, chkLeft

    	bit dir_right, d
    	call nz, chkRight

    	bit dir_down, d
    	call nz, chkDown

    	bit dir_up, d
    	call nz, chkUp
	
    	ld a, d
    	and e
    	ld d, a
	
; d holds keys pressed where move is allowed	(no collision and boundary ok)
; see if last move still pressed	
    	ld a, (lastMove)                            ; get last move
        ld e, a                                     ; save in e

        ld a, d                                     ; get valid moves bit mask
    	and e                                       ; see if last move still pressed

        jr z, doMove                                ; no previous last move
                                                    ; OR last move not pressed
                                                    ; OR last move disallowed

    ; here last move is stil pressed and allowed
        ld a, d                                     ; get valid moves bit mask again
        xor e                                       ; this time remove last move
        jr z, doMove                                ; last key only pressed, so do it

        ld d, a

	
doMove	
doMoveLeft	
	    bit dir_left, d
	    jr z, doMoveRight

	    ld hl, (player_px)
	    ld bc, move_delta
	    sbc hl, bc 
	    ld (player_px), hl

        ld a, vdir_left
        ld (lastMove), a
	    jp moveSprite

doMoveRight	
	    bit dir_right, d
	    jr z, doMoveDown

	    ld hl, (player_px)
	    ld bc, move_delta
	    adc hl, bc 
	    ld (player_px), hl

        ld a, vdir_right
        ld (lastMove), a
	    jp moveSprite

doMoveDown	
	    bit dir_down, d
	    jr z, doMoveUp

	    ld hl, (player_py)
	    ld bc, move_delta
	    adc hl, bc 
	    ld (player_py), hl

        ld a, vdir_down
        ld (lastMove), a
	    jp moveSprite

doMoveUp	
	    bit dir_up, d
	    jp z, moveSprite

	    ld hl, (player_py)
	    ld bc, move_delta
	    sbc hl, bc 
	    ld (player_py), hl

        ld a, vdir_up
        ld (lastMove), a
	    jp moveSprite

chkLeft	
	    ld hl, (player_px)                          ; get player px
	    ld bc, move_delta                           ; get move delta
	    sbc hl, bc                                  ; "try" move
	
	    ; now test if we have bumped into a wall
	    DIV_HL_8
	    ld b, l
	    ld hl, (player_py)
	    DIV_HL_8
	    ld c, l
	    GET_WORLD_TILE
	    and a
	    ret nz
	    inc c
	    GET_WORLD_TILE
	    and a
	    ret nz
	
	    ; now test if we are at limit of maze
	    ld hl, (player_px)
	    ld bc, min_px + move_delta                  ; get min pixel allowed
	    sbc hl, bc                                  ; test
	    ret c                                       ; return if fail
	
	    set dir_left, e                             ; set ok
        ret                                         ; return

chkRight
	    ld hl, (player_px)                          ; get player px
	    ld bc, move_delta                           ; get move delta
        adc hl, bc

        ; now test if we have bumped into a wall
        add hl, 15                                  ; the sprite extends 0-15px right
        DIV_HL_8
        ld b, l
        ld hl, (player_py)
        DIV_HL_8
        ld c, l
        GET_WORLD_TILE
        and a
        ret nz
        inc c
        GET_WORLD_TILE
        and a
        ret nz

        ; now test if we are at limit of maze
        ld hl, (player_px)
        ld bc, max_px + move_delta
        sbc hl, bc
        ret nc

        set dir_right, e
        ret

chkDown
        ld hl, (player_py)
        ld bc, move_delta                           ; get pixel delta
        adc hl, bc                                  ; do move

        ; now test if we have bumped into a wall
        add hl, 15                                  ; the sprite extends 0-15px down
        DIV_HL_8
        ld c, l
        ld hl, (player_px)
        DIV_HL_8
        ld b, l
        GET_WORLD_TILE
        and a
        ret nz
        inc b
        GET_WORLD_TILE
        and a
        ret nz

        ld hl, (player_py)
        ld bc, max_py + move_delta                  ; get max pixel allowed
        sbc hl, bc                                  ; test
        ret nc

        set dir_down, e
        ret

chkUp
        ld hl, (player_py)                          ; get player y
        ld bc, move_delta                           ; get pixel delta
        sbc hl, bc                                  ; do move

        ; now test if we have bumped into a wall
        DIV_HL_8
        ld c, l
        ld hl, (player_px)
        DIV_HL_8
        ld b, l
        GET_WORLD_TILE
        and a
        ret nz
        inc b
        GET_WORLD_TILE
        and a
        ret nz

        ; now test if we are at limit of maze
        ld hl, (player_py)
        ld bc, min_py + move_delta                  ; get min pixel allowed
        sbc hl, bc                                  ; test
        ret c

        set dir_up, e
        ret


keyEnd
moveSprite
        call processBaddies

; ================================================
    ; FINE SCROLLING (pixel-level smooth scroll)
    ; Set hardware tilemap scroll registers using player_px/py
    ; ================================================
        call wait_vblank

        ld a, (player_px)                           ; get LOW byte of player X position
        and 7                                       ; keep only the bottom 3 bits (0-7 pixels)
        nextreg $30, a                              ; ← X fine offset (MUST be every frame)

        ld a, (player_py)                           ; get LOW byte of player Y position
        and 7                                       ; keep only the bottom 3 bits (0-7 pixels)
        nextreg $31, a                              ; ← Y fine offset (MUST be every frame)

; ================================================
    ; COPY DECISION - copy ONLY when X or Y is aligned to tile boundary
    ; ================================================
        ld hl, (player_px)
        DIV_HL_8
        ld b, l
        ld hl, (player_py)
        DIV_HL_8
        ld c, l
        
        ld a, (player_tile_x)                       ; get last player tile X
        cp b                                        ; compare with current
        jr nz, copy_visible_window                  ; branch if different

        ld a, (player_tile_y)                       ; get last player tile Y
        cp c                                        ; compare with current
        jr nz, copy_visible_window                  ; branch if different

        ret                                         ; otherwise return, hardware scroll is enough

copy_visible_window:
        ld a, b                                     ; get current player tile X
        ld (player_tile_x), a                       ; save it away
        sub cam_tx                                  ; - 19 for lhs of screen
        ld b, a                                     ; save
        
        ld a, c                                     ; get current player tile Y
        ld (player_tile_y), a                       ; save it away
        sub cam_ty                                  ; - 15 for top of screen
        ld c, a                                     ; save

    ; STEP 1: Build the starting linear offset in the world map
        ld h, c                                     ; read the Y tile coordinate of the top-left corner we want
                                                    ; put it in H (this is the same as multiplying cam_tile_y by 256)
        ld l, b                                     ; read the X tile coordinate into L
                                                    ; Result: HL now holds  cam_tile_y * 256 + cam_tile_x
                                                    ; This is the byte offset into "world" map.

    ; STEP 2: Calculate which 8K physical page the data lives in
        ld   a,h                                    ; take the high byte of the offset (which is cam_tile_y)
        srl  a                                      ; divide by 2
        srl  a                                      ; divide by 2 again  → now /4
        srl  a                                      ; /8
        srl  a                                      ; /16
        srl  a                                      ; /32   ← this is the same as cam_tile_y ÷ 32
                                                    ; Why divide by 32?
                                                    ;   Each page is 8192 bytes.
                                                    ;   Each row is 256 bytes.
                                                    ;   8192 ÷ 256 = exactly 32 rows per page.
                                                    ;   Therefore page number = 40 + (cam_tile_y ÷ 32)
        add  a,40                                   ; add the starting page number (your world map begins at page 40)
        ld   (tilemapPage), a                       ; save the page number in register C for later

    ; STEP 3: Keep only the part of the address that fits inside one 8K page
        ld   a,h                                    ; get the high byte again
        and  $1F                                    ; $1F is binary 00011111 → keeps only the lowest 5 bits
                                                    ; This is exactly the same as (cam_tile_y * 256 + cam_tile_x) modulo 8192
                                                    ; (because 8192 = 2^13 and we are discarding everything above bit 12)
        ld   h,a                                    ; HL now holds the offset *inside* the current 8K page

    ; STEP 4: Page the correct 8K bank into slot 6 so we can read it
        ld   a, (tilemapPage)                       ; A = page number we want
        nextreg $56,a                               ; set MMU slot 6 ($C000-$DFFF) to that page
        ld   bc,$C000                               ; $C000 is the start of slot 6
        add  hl,bc                                  ; HL = $C000 + offset_inside_page
                                                    ; HL now points directly at the first byte we want to copy

    ; STEP 5: Point DE at the hardware tilemap buffer (fixed location)
        ld   de, tileMap                                ; destination is the hardware tilemap location

    ; STEP 6: Copy all 32 visible rows
        ld   bc,40*32                                   ; we need to copy 32 rows x 40 columns
.row_loop:
REPT 40
        LDI
ENDR
    ; STEP 7: Move the source pointer forward by exactly one full world-map row
        ld   a,216                                      ; 256 (full row) minus 40 (what we already copied) = 216
        add  hl,a                                       ; Z80N instruction — adds 8-bit number to HL very quickly

        LD A, H
        CP $E0
        CALL Z, .cross_boundary
    
        ld a, b
        or c
        jp nz, .row_loop
        ret 

.cross_boundary
    ; STEP 8: Did we cross into the next 8K physical page?
        ld   a,h                                        ; look at the high byte of the source pointer
        sub  $20                                        ; $20 is 32 in decimal. $E000 - $2000 = $C000 → subtract 32 from the high byte to wrap back to the start of slot 6
        ld   h,a
        ld a, (tilemapPage)
        inc a
        ld (tilemapPage), a
        nextreg $56, a                                  ; set MMU slot 6 ($C000-$DFFF) to that page
        ret

wait_vblank:
.loop        
        ld bc, $243B                                ; register select port
        ld a, $1E
        out (c), a                                  ; select ULA status register
        inc b                                       ; now point to data port $253B
        in a, (c)                                   ; read status
        bit 0, a
        jr z, .loop
        ret

setClipping:
        nextreg $1C, %00001000                      ; Reset tilemap clip window index (bit 3 = 1)

    ; Write the four clip coordinates to register $1B
    ; X values are in 2-pixel units (0-159 = full 320px width)
    ; Y values are 1:1 pixels (0-255)
    ; 4px border = inset of 2 X-units and 4 Y-pixels
        nextreg $1B, 2                              ; X1 = 2   → left edge  = pixel 4
        nextreg $1B, 157                            ; X2 = 157 → right edge = pixel 315 (319-4)
        nextreg $1b, 64                             ; Y! = 64, top 4 border lines + top 4 ULA lines
        nextreg $1B, 251                            ; Y2 = 251 → bottom edge= pixel 251 (255-4)

    ; setSpriteClip - clip sprites to the play area (below the HUD).
    ; Over-border mode is active, so:
    ;   - X coords use the SAME doubling as the tilemap clip (copy 2,157)
    ;   - Y coords are in sprite space: ULA-origin pixel + 32
    ;       tilemap top  pixel 64  -> 64+32 = 96
    ;       tilemap bot  pixel 251 -> 283 (overflows) -> clamp to 255
    ; Requires $15 bit 5 (clip-over-border) set - see note.
        NEXTREG $15, %00110111                      ; was %00010111; bit 5 = enable sprite clip over border

        nextreg $1C, 2                              ; bit 1 = reset the SPRITE clip index
        nextreg $19, 0                              ; X1 (doubled units, same as tilemap) -> pixel 4
        nextreg $19, 159                            ; X2 -> pixel 315
        nextreg $19, 64                             ; Y1 = 64 -> top of play area
        nextreg $19, 255                            ; Y2 = clamp (283 overflows a byte; screen edge handles bottom)
        ret

showSprite
        LD A, 0                                     ; get the sprite index
        NEXTREG $34, A                              ; set sprite to activate
        ld hl, cam_px
        ld de, cam_py
        LD A, l                                     ; get sprite X lsb
        NEXTREG $35, A                              ; set attr byte 0 of port $0057
        LD A, e                                     ; get sprite Y lsb
        NEXTREG $36, A                              ; set attr byte 1 of port $0057
        LD A, h                                     ; get sprite X msb
        AND 1                                       ; only need bit 0 of X msb
        NEXTREG $37, A                              ; bits 7-4 palette offset

        LD A, 0                                     ; get pattern index to use

        OR %10000000                                ;
        NEXTREG $38, A                              ; bits 7 1=make sprite visible
        RET

processBaddies
        ld ix, baddieData                           ; point to start of baddie data
        ld b, baddieCount

.loop
        push bc
        call processBaddie
        pop bc

        ld de, baddieRecord
        add ix, de
        djnz .loop
        ret

processBaddie:
        ld h, (ix +baddieRecord.highX)              ; get baddie X
        ld l, (ix +baddieRecord.lowX)
        ld (baddie_x), hl
        ld a, l
        and 7
        ld iyh, a
        DIV_HL_8                                    ; div by 8 to get tile Y
        ld b, l                                     ; save in D

        ld h, (ix +baddieRecord.highY)              ; get baddie Y
        ld l, (ix +baddieRecord.lowY)
        ld (baddie_y), hl
        ld a, l
        and 7
        ld iyl, a
        DIV_HL_8                                    ; divide by 8 to get tile Y
        ld c, l                                     ; save in C

; Decide only when grid-aligned (iyh==0 AND iyl==0) - the only
        ; moment a turn is possible. "Tile changed" fired at the far tile
        ; edge when moving up/left, where the turn check is gated out.
        ld a, iyh
        or iyl                                      ; both zero => on grid intersection
        jr z, newTile                               ; aligned -> run the decision

        ld a, (ix +baddieRecord.dir)                ; not aligned -> continue current dir
        ld b, a
        jp reverse
        
newTile:
        ld (ix +baddieRecord.tileX), b              ; save the tile X
        ld (ix +baddieRecord.tileY), c              ; save the tile Y

        ; get reverse direction
        ld a, (ix + baddieRecord.dir)               ; Load current direction
        ld b, a                                     ; Backup original direction to B
        and %00000011                               ; Check for Left (1) / Right (2)
        jr z, .vertMask                             ; If 0, it must be vertical (Up/Down)

        ; Horizontal Path: Swap 1 <-> 2
        ; 'A' already contains ONLY the horizontal bits here
        xor %00000011                               ; 1 becomes 2, 2 becomes 1
        ld b, a                                     ; Store final result in B
        jr .done

.vertMask:
        ; Vertical Path: Swap 4 <-> 8
        ; Because 'A' was 0, 'B' still holds the unaltered original vertical value
        ld a, b                                     ; Bring original back to A to process
        xor %00001100                               ; 4 becomes 8, 8 becomes 4
        ld b, a                                     ; Store final result in B

.done:
        ; d holds current direction (bitmask)
        push bc                                     ; save reverse on stack for use later
        ld a, %00001111                             ; start with all directions
        xor b                                       ; mask out reverse

; -----------------------------------------------
; Test each direction to see if a move is allowed
; -----------------------------------------------
        ld d, a                                     ; D = directions to test (all except reverse)
        ld e, 0                                     ; E = available directions found

        bit dir_left, d
        call nz, chkLeft1

        bit dir_right, d
        call nz, chkRight1

        bit dir_down, d
        call nz, chkDown1

        bit dir_up, d
        call nz, chkUp1

;-----------------------
; pick direction to take
; ----------------------
        pop bc                                      ; retrieve the saved reverse direction
        ld a, e                                     ; get what moves were possible
        and a                                       ; are there any?
        jr z, reverse
moveAvailable
        call random                                ; pick one if so
        ld b, a

reverse:
        ld a, b                                     ; set d to be the reverse direction

        add a, a
        ld hl, baddieMoveLUT
        add hl, a
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        jp (hl)

baddieMoveLUT:
defw    0, doMoveLeft1, doMoveRight1, 0, doMoveDown1, 0, 0, 0, doMoveUp1

chkLeft1
        ld a, iyl                                   ; we only want to test horizontal moves if baddie Y is exactly on a tile
        and a                                       ; is it?
        ret nz                                      ; return if not

        ld hl, (baddie_x)
        ld bc, move_delta
        sbc hl, bc

        ; now test if we have bumped into a wall
        DIV_HL_8
        ld b, l
        ld hl, (baddie_y)
        DIV_HL_8
        ld c, l
        GET_WORLD_TILE
        and a
        ret nz

        inc c
        GET_WORLD_TILE
        and a
        ret nz

        set dir_left, e
        ret

chkRight1
        ld a, iyl                                   ; we only want to test horizontal moves if baddie Y is exactly on a tile
        and a                                       ; is it?
        ret nz                                      ; return if not

        ld hl, (baddie_x)
	    ld bc, move_delta                           ; get move delta
        adc hl, bc

        ; now test if we have bumped into a wall
        add hl, 15                                  ; the sprite extends 0-15px right
        DIV_HL_8
        ld b, l
        ld hl, (baddie_y)
        DIV_HL_8
        ld c, l
        GET_WORLD_TILE
        and a
        ret nz
        inc c
        GET_WORLD_TILE
        and a
        ret nz

        set dir_right, e
        ret

chkDown1
        ld a, iyh                                   ; we only want to test vertical moves if baddie X is exactly on a tile
        and a                                       ; is it?
        ret nz                                      ; return if not

        ld hl, (baddie_y)
        ld bc, move_delta                           ; get pixel delta
        adc hl, bc                                  ; do move

        ; now test if we have bumped into a wall
        add hl, 15                                  ; the sprite extends 0-15px down
        DIV_HL_8
        ld c, l
        ld hl, (baddie_x)
        DIV_HL_8
        ld b, l
        GET_WORLD_TILE
        and a
        ret nz
        inc b
        GET_WORLD_TILE
        and a
        ret nz

        set dir_down, e
        ret

chkUp1
        ld a, iyh                                   ; we only want to test vertical moves if baddie X is exactly on a tile
        and a                                       ; is it?
        ret nz                                      ; return if not

        ld hl, (baddie_y)
        ld bc, move_delta                           ; get pixel delta
        sbc hl, bc                                  ; do move

        ; now test if we have bumped into a wall
        DIV_HL_8
        ld c, l
        ld hl, (baddie_x)
        DIV_HL_8
        ld b, l
        GET_WORLD_TILE
        and a
        ret nz
        inc b
        GET_WORLD_TILE
        and a
        ret nz

        set dir_up, e
        ret


doMoveLeft1
        ld hl, (baddie_x)
        ld bc, move_delta
        sbc hl, bc
        ld (ix +baddieRecord.highX), h
        ld (ix +baddieRecord.lowX), l
        ld a, vdir_left
        ld (ix +baddieRecord.dir), a
        jr displayBaddie 

doMoveRight1
        ld hl, (baddie_x)
        ld bc, move_delta
        adc hl, bc
        ld (ix +baddieRecord.highX), h
        ld (ix +baddieRecord.lowX), l
        ld a, vdir_right
        ld (ix +baddieRecord.dir), a

        jr displayBaddie 

doMoveDown1
        ld hl, (baddie_y)
        ld bc, move_delta
        adc hl, bc
        ld (ix +baddieRecord.highY), h
        ld (ix +baddieRecord.lowY), l
        ld a, vdir_down
        ld (ix +baddieRecord.dir), a

        jr displayBaddie 

doMoveUp1
        ld hl, (baddie_y)
        ld bc, move_delta
        sbc hl, bc
        ld (ix +baddieRecord.highY), h
        ld (ix +baddieRecord.lowY), l
        ld a, vdir_up
        ld (ix +baddieRecord.dir), a


displayBaddie:
    ; ============================================================
    ; Draw baddie sprite (sprite #1) relative to the centred player.
    ; Player is locked to screen centre, so:
    ;     screenPos = baddieWorldPos - playerWorldPos + screenCentre
    ; A 16x16 sprite is shown whenever ANY part overlaps the display,
    ; so we allow up to 15px of overhang at each edge before hiding.
    ; IX already points at the baddie record (set by processBaddies).
    ; ============================================================

    ; ---------- SCREEN X ----------
        ; HL = baddie world X
        ld l, (ix + baddieRecord.lowX)
        ld h, (ix + baddieRecord.highX)
        ld bc, (player_px)              ; BC = player world X
        or a                           ; clear carry for a clean subtract
        sbc hl, bc                     ; HL = baddieX - playerX  (signed)
    ; add screen centre AND the 15px overhang bias in one go.
    ; CENTER_SCREEN_X + 15 = 152 + 15 = 167, which fits in 8 bits,
    ; so we can use the Z80N "add hl,a" (cheaper to set up than add hl,bc).
        ld a, cam_px + 15                               ; A = 167  (centre + bias)
        add hl, a                      ; Z80N: HL = biased screen X
    ; HL now holds (screenX + 15). Visible-with-overhang means the
    ; UN-biased X is in -15..319, i.e. the BIASED value is in 0..334.
    ; Reject anything outside 0..334 with an unsigned range test.
        ld a, h                        ; look at high byte of biased X
        cp 1                           ; H = 0 ?  (biased X = 0..255)
        jr c, .xInRange                ; H = 0 -> definitely <= 334, in range
        jr nz, .hideBaddie             ; H >= 2 -> biased X >= 512 -> off right
    ; H = 1 here, so biased X = 256..511; allowed only up to 334 ($014E),
    ; meaning the low byte must be < 79 (334 - 256 = 78).
        ld a, l
        cp 79
        jr nc, .hideBaddie             ; low byte >= 79 -> off right edge
.xInRange:
        push hl                        ; save biased X (we still need it later)

    ; ---------- SCREEN Y ----------
    ; HL = baddie world Y
        ld l, (ix + baddieRecord.lowY)
        ld h, (ix + baddieRecord.highY)
        ld bc, (player_py)             ; BC = player world Y
        or a                           ; clear carry
        sbc hl, bc                     ; HL = baddieY - playerY  (signed)
    ; centre + bias again: CENTER_SCREEN_Y + 15 = 120 + 15 = 135, fits in 8 bits.
        ld a, cam_py + 15     ; A = 135
        add hl, a                      ; Z80N: HL = biased screen Y
    ; Visible-with-overhang: un-biased Y in -15..255, i.e. biased Y in 0..270.
        ld a, h                        ; high byte of biased Y
        cp 1                           ; H = 0 ?
        jr c, .yInRange                ; H = 0 -> <= 270, in range
        jr nz, .hidePop                ; H >= 2 -> off bottom
    ; H = 1: biased Y = 256..511, allowed only up to 270 ($010E),
    ; so low byte must be < 15 (270 - 256 = 14).
        ld a, l
        cp 15
        jr nc, .hidePop                ; low byte >= 15 -> off bottom edge
.yInRange:
    ; ---------- BADDIE IS ON SCREEN ----------
    ; Un-bias Y by 15 to get the real Y the hardware wants.
    ; The sprite Y register is 8-bit and takes the value mod 256,
    ; which is exactly what we need: a baddie 15px above the top
    ; (real Y = -15) writes 241, and the hardware draws it overhanging.
        ld a, l                        ; low byte of biased Y
        sub 15                         ; A = real screen Y (mod 256)
        ld e, a                        ; stash Y in E for the moment

        pop hl                         ; recover biased X
        ld bc, 15
        or a                           ; clear carry
        sbc hl, bc                     ; HL = real screen X (full 9-bit value)

    ; ---------- WRITE SPRITE 1 ----------
        ld a, (ix +baddieRecord.index)
        NEXTREG $34, a                 ; select sprite slot 1
        ld a, l
        NEXTREG $35, a                 ; attr 0: X low 8 bits
        ld a, e
        NEXTREG $36, a                 ; attr 1: Y (8-bit)
        ld a, h
        and 1                          ; X is 9-bit; keep only bit 8
        NEXTREG $37, a                 ; attr 2: X MSB in bit 0
        ld a, (ix + baddieRecord.pattern)
        or %10000000                   ; bit 7 = visible
        NEXTREG $38, a                 ; attr 3: pattern + visible flag
        ret

.hidePop:
        pop hl                         ; balance the stack (biased X was pushed)
.hideBaddie:
        ld a, (ix +baddieRecord.index)
        NEXTREG $34, a                 ; select sprite slot 1
        NEXTREG $38, 0                 ; clear visible bit -> sprite hidden
        ret


HUD_ATTR        equ %01110000               ; BRIGHT yellow paper, black ink

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
        ret

random:
        and $0f                                     ; limit to 0-15, this is the available directions bitmask
        ld l, a                                     ; l = 0-15
        ld h, 0                                     ; h = 0
        add hl, hl                                  ; 2 * hl
        add hl, hl                                  ; 4 * hl
        ld de, lut_base                             ; add lut base
        add hl, de                                  ; hl now points to row applicable for available directions
        
RND_GEN:
        ld a, (rseed)
        ld d, a
        add a, a            ; *2
        add a, a            ; *4
        add a, d            ; *5
        add a, 7            ; + odd constant
        ld (rseed), a       ; save new seed
        rlca                ; bring the high (well-mixed) bits down
        rlca
        and %00000011       ; keep 2 bits -> 0-3        
        ADD HL, A
        LD A, (HL)

        RET

rnd8:
        ld a, (rseed)
        ld d, a
        add a, a            ; *2
        add a, a            ; *4
        add a, d            ; *5
        add a, 7            ; + odd constant
        ld (rseed), a       ; save new seed
        rlca                ; bring the high (well-mixed) bits down
        rlca
        RET

rseed:
    db 1                 ; Initial 16-bit seed (Must not be zero!)        ld a, (hl)

lut_base:
        db 0, 0, 0, 0                               ;  0  0000 no bits set
        db 1, 1, 1, 1                               ;  1  0001 only bit 0 set
        db 2, 2, 2, 2                               ;  2  0010 only bit 1 set
        db 1, 2, 1, 2                               ;  3  0011 bits 0, 1 set
        db 4, 4, 4, 4                               ;  4  0100 only bit 2 set
        db 1, 4, 1, 4                               ;  5  0101
        db 2, 4, 2, 4                               ;  6  0110
        db 1, 2, 4, 1                               ;  7  0111
        db 8, 8, 8, 8                               ;  8  1000
        db 1, 8, 1, 8                               ;  9  1001
        db 2, 8, 2, 8                               ; 10  1010
        db 1, 2, 8, 1                               ; 11  1011
        db 4, 8, 4, 8                               ; 12  1100
        db 1, 4, 8, 1                               ; 13  1101
        db 2, 4, 8, 2                               ; 14  1110
        db 1, 2, 4, 8                               ; 15  1111 


initBaddies:
; ============================================================
; initBaddies - place baddieCount baddies at random valid 2x2
; positions in the maze. Each needs its 2x2 tile footprint clear.
; Sets world pixel position, tile position, a random direction,
; sprite index (1..N, player is sprite 0), and pattern 0.
; Setup-time only: uses rejection loops freely (timing irrelevant).
; Assumes: rnd8 returns raw 0-255 in A; GET_WORLD_TILE takes
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
        cp 191
        jr nc, .ry                  ; reject 191..255 (need ty in 0..190)
        ld e, a                     ; E = candidate tileY

.loop
        ; --- test all four tiles of the 2x2 footprint are open ---
        ld b, d
        ld c, e
        GET_WORLD_TILE              ; (tx, ty)
        and a
        jr nz, .tryPos              ; wall -> reject, draw again

        ld b, d
        ld c, e
        inc b
        GET_WORLD_TILE              ; (tx+1, ty)
        and a
        jr nz, .tryPos

        ld b, d
        ld c, e        
        inc c
        GET_WORLD_TILE              ; (tx, ty+1)
        and a
        jr nz, .tryPos

        ld b, d
        inc b
        ld c, e
        inc c
        GET_WORLD_TILE              ; (tx+1, ty+1)
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

vdirTable: db 1, 2, 4, 8             ; vdir_left, right, down, up


setupIM2:
; sub routine to set-up IM2 to point to BB
        DI 
        LD HL, IM2Tab
        LD DE, IM2Tab +1
        LD A, H
        LD I , A
        LD A, $f0
        LD (HL), A
        LD BC, 256
        LDIR 

        IM 2
        EI
        RET

AYSelect        EQU $FFFD
AYrw            EQU $bffd
AYPortC         EQU $FD                     ; Port low byte, stays in C
AYPortSelectB   EQU $FF                     ; B value for AYSelect port ($FFFD)
AYPortWriteB    EQU $BF                     ; B value for AYrw port ($BFFD)
channel1ToneL   equ 0
channel1ToneH   equ 1
channel2ToneL   equ 2
channel2ToneH   equ 3
channel3ToneL   equ 4
channel3ToneH   equ 5
channel1Volume  equ 8
channel2Volume  equ 9
channel3Volume  equ 10
mixerFlag       equ 7
frameCount   DB $01                         ; interrupt count for note set
framePointer DW frameTable                  ; pointer to the ic and note set
volume       DB %00001111                   ; volume
Ch1:
Ch1Pitch:    DW 0
Ch1PitchD:   DW 0
Ch1Volume    DW 00
Ch1VolumeD:  DW 00
Ch1Flags:    DB 0
Ch1Length:   DB 0

Ch2:
Ch2Pitch:    DW 00
Ch2PitchD:   DW 00
Ch2Volume    DW 00
Ch2VolumeD:  DW 00
Ch2Flags:    DB 0
Ch2Length:   DB 0

Ch3:
Ch3Pitch:    DW 00
Ch3PitchD:   DW 00
Ch3Volume    DW 00
Ch3VolumeD:  DW 00
Ch3Flags:    DB 0
Ch3Length:   DB 0

mixerFlags  
                db %11111111, %11111110, %11110111, %11110110
                db %11111111, %11111101, %11101111, %11101101
                db %11111111, %11111011, %11011111, %11011011

INCLUDE "inspectorclouseau.inc"

ALIGN 256
IM2Tab:
        DEFS 257, 0

ORG $f0f0
im2Routine
        PUSH AF
        PUSH BC
        PUSH DE
        PUSH HL

INCLUDE "im2Routine.inc"

        POP HL
        POP DE
        POP BC
        POP AF

        EI
        RETI 


; ----------------------------------------------------------------
; Tilemap data - 48 KB stored directly in Pages 40 - 45
; ----------------------------------------------------------------
TILEMAP_PAGE    EQU     40

; === Chunk 1 (bytes 0-16383) -> 8 KB Page 40/41 ===
MMU     6, TILEMAP_PAGE                             ; map page 40 into slot 6
MMU     7, TILEMAP_PAGE + 1                         ; map page 41 into slot 7
ORG     $C000
tilemap_part1:
INCBIN  "testmaze.map", 0, 16384                    ; first 16 KB

; === Chunk 2 (bytes 16384-32767) -> 8 KB Page 42/43 ===
MMU     6, TILEMAP_PAGE + 2
MMU     7, TILEMAP_PAGE + 3
ORG     $C000
tilemap_part2:
INCBIN  "testmaze.map", 16384, 16384

; === Chunk 3 (bytes 32768-49151) -> 8 KB Page 44/45 ===
MMU     6, TILEMAP_PAGE + 4
MMU     7, TILEMAP_PAGE + 5
ORG     $C000
tilemap_part3:
INCBIN  "testmaze.map", 32768, 16384

; ----------------------------------------------------------------
; Build the .nex file (automatically includes all used banks)
; ----------------------------------------------------------------
SAVENEX OPEN "maze.nex", progStart, $FF40           ; entry point + stack
SAVENEX AUTO                                        ; include all pages we used
SAVENEX CLOSE