device ZXSPECTRUMNEXT
INCLUDE "macros.inc"
INCLUDE "maze2.inc"
INCLUDE "keysroutines.inc"
INCLUDE "initialisation.inc"
INCLUDE "text.inc"
INCLUDE "melody.inc"
INCLUDE "soundEffects.inc"
cam_px              dw  0
cam_py              dw  0
cam_tx              db  0
cam_ty              db  0

CENTRE_X            equ 152
CENTRE_Y            equ 120
CAM_MIN_X           equ 0
CAM_MIN_Y           equ 0
CAM_MAX_X           equ (256 - 40) * 8              ; 1728  (map width - view width)
CAM_MAX_Y           equ (192 - 32) * 8              ; 1280  (map height - visible rows incl partial)


tilemapPage         db 0
curWorldPage        db 0

playerHealth        db 8
healthBlock         db 23
playerLives         db 0
playerKeys          db 0
playerAlive         db 0

score4              db 0
score3              db 0                            ; thousands
score2              db 0                            ; hundreds
score1              db 0                            ; tens
score0              db 0                            ; units

player_px           dw 0                            ; world pixel position of sprite
player_py           dw 0
player_tile_x       db 0                            ; world tile position of sprite, basically px / 256
player_tile_y       db 0
lastMove            db 1                            ; 
playerAnimFrame     db 0                            ; current animation frame 0-3
playerAnimTick      db 0                            ; counts frames to slow the animation

PAT_DOWN            equ 4                           ; facing forward
PAT_RIGHT           equ 8                           ; facing right
PAT_LEFT            equ 12                          ; facing left
PAT_UP              equ 16                          ; facing away
ANIM_SPEED          equ 4                           ; advance frame every N moves (higher = slower)


; tiles used in map
MAP_PATH            EQU 0                           ; path, basically an empty tile
MAP_WALL            EQU 1                           ; wall, simple brick graphic
MAP_KEYTL           EQU 4                           ; key, top left
MAP_KEYTR           EQU 5                           ; key, top right
MAP_KEYBL           EQU 6                           ; key, bottom left
MAP_KEYBR           EQU 7                           ; key, bottom right

move_delta          equ 2                           ; player move pixel increment
move_delta_baddie   equ 1                           ; baddie move pixel increment

dir_left            equ 0
dir_right           equ 1
dir_down            equ 2
dir_up              equ 3
vdir_left           equ 1
vdir_right          equ 2
vdir_down           equ 4
vdir_up             equ 8

mode_auto           equ 0
mode_hunt           equ 1
mode_wander         equ 2

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
mode                byte
lastDist            byte
    ENDS

baddieCount         equ 60
baddieData          defs baddieRecord * baddieCount

; working x/y pixel co-ords to minimise LD N, (IX+N) calls
baddie_x            dw 00
baddie_y            dw 00

COLLIDE_DX      equ 11                              ; X overlap threshold (tune 9-14)
COLLIDE_DY      equ 11                              ; Y overlap threshold

QUEUE_SIZE      equ 256                             ; max wavefront is ~27, so this is ample
floodQueue      ds  QUEUE_SIZE * 2                  ; ring buffer of 16-bit cell offsets (y*256+x)
qHeadIdx        db  0
qTailIdx        db  0
qCount          db  0
floodTargetX    db  0
floodTargetY    db  0
;FLOOD_LIMIT     equ 253
FLOOD_LIMIT     EQU 80

L2_KEY          equ %11111100                       ; yellow (R+G, no blue)
L2_WALL         equ %11100000                       ; red
L2_PATH         equ %00000000                       ; black
L2_FLOOD        EQU %11111111                       ; white

viewMode        db 0                                ; 0 = normal, 1 = radar
yKeyWas         db 0                                ; debounce for Y key


progStart:
        call setupIM2

        call spriteSetup                            ; load sprites, tiles, palettes etc into memory
        call setClipping
        call setUpCamera
        call attractMode

otherSetup:
        LD A, 0                                     ; Load speed index (3 = 28 MHz)
        NEXTREG $07, A

        ld a, 0                                     ; colour black
        out (254), a                                ; set border colour

        call showSprite                             ; show player

        ; Layer 2 setup (configured now, visibility off until Y)
        nextreg $12, L2_BANK16
        nextreg $70, %00000000                      ; 256x192x8bpp
        nextreg $16, 0
        nextreg $17, 0
        nextreg $18, 0
        nextreg $18, 255
        nextreg $18, 0
        nextreg $18, 191
        ; ensure it starts hidden
        ld bc, $123b
        xor a
        out (c), a

        call moveSprite1

main:
        ld a, (playerLives)
        and a
        jp z, progStart

        call keyProcess

        jr main


keyProcess:	
chkKeyRadar:
        ld bc, $dffe                                ; Y U I O P row
        in a, (c)                                   ; read port
        bit 4, a                                    ; Y key (active low)
        jr nz, .yUp                                 ; not pressed

        ld a, (yKeyWas)                             ; 
        or a
        jr nz, .yEnd                                ; already handled (held) -> ignore
        ld a, 1
        ld (yKeyWas), a

        ; toggle viewMode
        ld a, (viewMode)
        xor 1
        ld (viewMode), a

        jr z, .radarOff                             ; if it's off, jump to radarOff routine
                                                    ; otherwise drop thru to radar on routine below

        ; --- switch to radar: draw all markers, show layer ---
        ; --- switch to radar: hide other layers, show Layer 2 ---
        ; sprites off (clear $15 bit 0, keep your other $15 bits as set at init)
        nextreg $15, %00000011                      ; <-- your init $15 value with bit0 (sprite visible) cleared

        ; tilemap off ($6B bit7 = 0)
        nextreg $6B, %00100001                      ; <-- your init $6B value with bit7 cleared

        ; ULA off ($68 bit7 = 1 disables ULA)
        nextreg $68, %10000000                      ; <-- your init $68 value with bit7 set        

        ; enable Layer 2, the radar view
        ld bc, $123b
        ld a, 2
        out (c), a
        jr .yEnd

.radarOff:
        ; switch off layer 2
        ld bc, $123b
        xor a
        out (c), a

        ; restore the other layers to your init values
        nextreg $15, %00100011                      ; <-- your ACTUAL init $15 value
        nextreg $6B, %10100001                      ; <-- your ACTUAL init $6B value
        nextreg $68, %00000000                      ; <-- your ACTUAL init $68 value
        nextreg $1C, 2                              ; bit 1 = reset the SPRITE clip index
        nextreg $19, 0                              ; X1 (doubled units, same as tilemap) -> pixel 4
        nextreg $19, 159                            ; X2 -> pixel 315
        nextreg $19, 64                             ; Y1 = 64 -> top of play area
        nextreg $19, 255                            ; Y2 = clamp (283 overflows a byte; screen edge handles bottom)

        call showSprite

        jr .yEnd

.yUp:
        xor a
        ld (yKeyWas), a
.yEnd:


; regular left/right/up/down kwyboard processing follows
.chkExit:
        ld bc, $fefe
        in a, (c)
        bit 2, a
        
        jr nz, .yEnd1

.RESET_NEXT:
        DI                                          ; Disable interrupts to prevent glitching
        LD BC, $243B                                ; TBBlue/Next Register Select Port
        LD A, $02                                   ; Select NextReg $02 (Reset Control Register)
        OUT (C), A
    
        INC B                                       ; Move to Port $253B (Next Register Access Port)
        LD A, 1                                     ; Value 1 = Trigger immediate soft/hard reset
        OUT (C), A                                  ; The machine resets instantly right here


.yEnd1:
	    ld d, 0                                     ; initialise D as bitmask showing what keys were pressed
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


; we don't allow movement if partially on a tile for that direction
; so set up another mask here, E, holding whether vertical and/or horizontal movement is actually allowed
chkVert:	
    	ld e, 0                                     ; set mask to 0
    	ld a, (player_px)                           ; get player px (low byte   )
    	and 7                                       ; check bits 2-0, if 0 then vertical movement may be allowed
    	jr nz, chkHoriz
    	ld e, %00001100                             ; set bits to allow vertical movement
	
chkHoriz:	
	    ld a, (player_py)                           ; get player px (low byte)
    	and 7                                       ; check bits 2-0 if 0 then horizontal movement may be allowed
    	jr nz, chkEnd
    	ld a, %00000011                             ; set bits to allow horizontal movement
    	or e                                        ; add to existing mask
    	ld e, a                                     ; set mask
	
chkEnd:	
; d = keys pressed	
; e = vert/horiz potentially allowed	
	
	    ld a, d                                     ; get the keys pressed
;        and a                                       ; anything?
;        jp z, moveSprite                            ; jp if not


	    and e                                       ; mask with what is allowed
	    ld d, a                                     ; save back in D, key pressed and direction possibly allowed

	
; d is keys pressed potentially allowed	
; e is set to bitmask checking if desired movement is permitted, i.e. not blocked by a wall	
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
	
    	ld a, d                                     ; get the potential moves again
    	and e                                       ; mask with actually allowed, i.e. not blocked by a wall
    	ld d, a                                     ; save back into D
	
; d holds keys pressed where move is allowed (no collision)
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

	
doMove:
doMoveLeft:
	    bit dir_left, d
	    jr z, doMoveRight

	    ld hl, (player_px)
	    ld bc, move_delta
        or a
	    sbc hl, bc 
	    ld (player_px), hl

        ld a, vdir_left
        ld (lastMove), a
        jp updateCameraXY

doMoveRight:	
	    bit dir_right, d
	    jr z, doMoveDown

	    ld hl, (player_px)
	    ld bc, move_delta
	    add hl, bc 
	    ld (player_px), hl

        ld a, vdir_right
        ld (lastMove), a
        jp updateCameraXY

doMoveDown:
	    bit dir_down, d
	    jr z, doMoveUp

	    ld hl, (player_py)
	    ld bc, move_delta
        add hl, bc 
	    ld (player_py), hl

        ld a, vdir_down
        ld (lastMove), a
        jp updateCameraXY

doMoveUp:
	    bit dir_up, d
	    jp z, moveSprite

	    ld hl, (player_py)
	    ld bc, move_delta
        or a
	    sbc hl, bc 
	    ld (player_py), hl

        ld a, vdir_up
        ld (lastMove), a
        jp updateCameraXY

; ============================================================
; updateCameraXY - recompute camera from player, clamped to map.
;   cam = player - CENTRE, then clamped to [0 .. CAM_MAX]
; Low clamp: if (player - CENTRE) < 0  -> 0   (sign test)
; High clamp: if value > CAM_MAX       -> CAM_MAX
; ============================================================
updateCameraXY:
        call addScore

        ; ---------- X ----------
        ld hl, (player_px)
        ld bc, CENTRE_X
        or a
        sbc hl, bc                                  ; hl = player_px - CENTRE_X
        jp p, .camXLowOK                            ; >= 0 -> keep
        ld hl, 0                                    ; negative -> clamp to 0
.camXLowOK:
        ld bc, CAM_MAX_X
        or a
        sbc hl, bc                                  ; hl = value - CAM_MAX_X
        jr c, .camXHighOK                           ; carry set => value < max -> keep (after add back)
        ld hl, 0                                    ; value >= max -> result = max (after add back)
.camXHighOK:
        add hl, bc                                  ; add CAM_MAX_X back
        ld (cam_px), hl

        ; ---------- Y ----------
        ld hl, (player_py)
        ld bc, CENTRE_Y
        or a
        sbc hl, bc                                  ; hl = player_py - CENTRE_Y
        jp p, .camYLowOK
        ld hl, 0
.camYLowOK:
        ld bc, CAM_MAX_Y
        or a
        sbc hl, bc
        jr c, .camYHighOK
        ld hl, 0
.camYHighOK:
        add hl, bc
        ld (cam_py), hl
        jp doMoveDone

; --- a move was committed: advance the walk animation (throttled) ---
doMoveDone:
        ld a, (playerAnimTick)
        inc a
        ld (playerAnimTick), a
        cp ANIM_SPEED
        jr c, .noAdvance                            ; not time to advance frame yet
        xor a
        ld (playerAnimTick), a
        ld a, (playerAnimFrame)
        inc a
        and 3                                        ; cycle 0-3
        ld (playerAnimFrame), a
.noAdvance:
        call showSprite                             ; write new pattern (direction + frame)
        jp moveSprite
        
chkLeft:
        checkLeftM player_px, player_py, move_delta

chkRight:
        checkRightM player_px, player_py, move_delta

chkDown:
        checkDownM player_px, player_py, move_delta

chkUp:
        checkUpM player_px, player_py, move_delta

keyEnd:
moveSprite:
        call debugs
;        ld a, 2
;        out (254), a
        call processBaddies
;        xor a
;        out (254), a

moveSprite1:
; ================================================
    ; FINE SCROLLING (pixel-level smooth scroll)
    ; Set hardware tilemap scroll registers using player_px/py
    ; ================================================
        call wait_vblank

        ld a, (cam_px)                              ; get LOW byte of camera X position
        and 7                                       ; keep only the bottom 3 bits (0-7 pixels)
        nextreg $30, a                              ; ← X fine offset (MUST be every frame)

        ld a, (cam_py)                              ; get LOW byte of camera Y position
        and 7                                       ; keep only the bottom 3 bits (0-7 pixels)
        nextreg $31, a                              ; ← Y fine offset (MUST be every frame)

; ================================================
    ; COPY DECISION - copy ONLY when X or Y is aligned to tile boundary
    ; ================================================
        ld hl, (cam_px)
        DIV_HL_8
        ld b, l
        ld hl, (cam_py)
        DIV_HL_8
        ld c, l
        
        ld a, (cam_tx)                              ; get last player tile X
        cp b                                        ; compare with current
        jr nz, copy_visible_window                  ; branch if different

        ld a, (cam_ty)                              ; get last player tile Y
        cp c                                        ; compare with current
        jr nz, copy_visible_window                  ; branch if different

        ret                                         ; otherwise return, hardware scroll is enough

copy_visible_window:
        ld a, b                                     ; get current player tile X
        ld (cam_tx), a                              ; save it away
        ld a, c                                     ; get current player tile Y
        ld (cam_ty), a                              ; save it away

    ; STEP 1: Build the starting linear offset in the world map
        ld h, c                                     ; read the Y tile coordinate of the top-left corner we want
                                                    ; put it in H (this is the same as multiplying cam_tile_y by 256)
        ld l, b                                     ; read the X tile coordinate into L
                                                    ; Result: HL now holds  cam_tile_y * 256 + cam_tile_x
                                                    ; This is the byte offset into "world" map.

    ; STEP 2: Calculate which 8K physical page the data lives in
        ld   a, h                                   ; take the high byte of the offset (which is cam_tile_y)
;        srl  a                                      ; divide by 2
;        srl  a                                      ; divide by 2 again  → now /4
;        srl  a                                      ; /8
;        srl  a                                      ; /16
;        srl  a                                      ; /32   ← this is the same as cam_tile_y ÷ 32
; ------------------------------------------------------------------------
; performance fix, 5 shifts is equiv to 3 in opposite direction (with and)
; saves 21 t-state
; ------------------------------------------------------------------------
        rlca
        rlca
        rlca
        and 7
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
        ld   de, tileMap                            ; destination is the hardware tilemap location

    ; STEP 6: Copy all 32 visible rows
        ld   bc,40*32                               ; we need to copy 32 rows x 40 columns
.row_loop:
REPT 40
        LDI
ENDR
    ; STEP 7: Move the source pointer forward by exactly one full world-map row
        ld   a,216                                  ; 256 (full row) minus 40 (what we already copied) = 216
        add  hl,a                                   ; Z80N instruction — adds 8-bit number to HL very quickly

        LD A, H
        CP $E0
        CALL Z, .cross_boundary
    
        ld a, b
        or c
        jp nz, .row_loop
        ret 

.cross_boundary
    ; STEP 8: Did we cross into the next 8K physical page?
        ld   a,h                                    ; look at the high byte of the source pointer
        sub  $20                                    ; $20 is 32 in decimal. $E000 - $2000 = $C000 → subtract 32 from the high byte to wrap back to the start of slot 6
        ld   h,a
        ld a, (tilemapPage)
        inc a
        ld (tilemapPage), a
        nextreg $56, a                              ; set MMU slot 6 ($C000-$DFFF) to that page
        ret

wait_vblank:
        ld bc, $243B                                ; register select port
        ld a, $1E
        out (c), a                                  ; select ULA status register
        inc b                                       ; now point to data port $253B
.loop
        in a, (c)                                   ; read status
        bit 0, a
        jr z, .loop
        ret


showSprite:
; ============================================================
; Returns the floodfill distance for the player's tile in A.
; 255 = wall / unreached. Lower = closer to flood target.
; Trashes: AF, HL, BC
; ============================================================
        ld hl, (player_py)
        DIV_HL_8                                    ; L = tileY (player_py / 8)
        ld a, l
        ld (player_tile_y), a

        ld hl, (player_px)
        DIV_HL_8                                    ; L = tileX (player_px / 8)
        ld a, l
        ld (player_tile_x), a

        ; ... player_tile_x / player_tile_y just stored ...
        call checkKeyCollect
        jr nc, .noKey               ; carry clear -> nothing collected
        ; A = collected key index -> handle it
        call collectKey             ; mark collected, clear tiles, bump count, re-flood
.noKey:
        ; ... rest of showSprite ...

        ld a, (viewMode)                            ; get the view mode, normal or radar
        or a                                        ; see it it is 0 (normal)
        ret nz                                      ; return if Radar (player sprite rendered in process baddie routine)


        xor a                                       ; sprite index = 0
        NEXTREG $34, A
        ld hl, (player_px)
        ld bc, (cam_px)
        sbc hl, bc
        ld e, h

        LD A, l                                     ; set the low byte of player X
        NEXTREG $35, A

        ld hl, (player_py)
        ld bc, (cam_py)
        sbc hl, bc

        LD A, l                                     ; set the low byte of player Y
        NEXTREG $36, A
        LD A, e                                     ; get the high byte of player X
        AND 1                                       ; we only need bit 0
        NEXTREG $37, A                              ; set it

        ; --- choose pattern from facing direction + animation frame ---
        ld a, (lastMove)                            ; vdir flag: 1=L 2=R 4=D 8=U
        ld b, PAT_DOWN                              ; default down
        cp vdir_left
        jr nz, .notL
        ld b, PAT_LEFT
        jr .haveBase
.notL:
        cp vdir_right
        jr nz, .notR
        ld b, PAT_RIGHT
        jr .haveBase
.notR:
        cp vdir_up
        jr nz, .haveBase                            ; else stays PAT_DOWN
        ld b, PAT_UP
.haveBase:
        ld a, (playerAnimFrame)                     ; 0-3
        add a, b                                    ; base + frame = pattern

        OR %10000000                                ; bit 7 = visible
        NEXTREG $38, A
        RET

; ============================================================
; checkKeyCollect
; Tests whether the player's 2x2 footprint overlaps any
; AVAILABLE key's 2x2 block.
; Returns: A = key index (0..KEY_COUNT-1) and carry SET if a
;          key was collected; carry CLEAR (A undefined) if none.
; Uses player_tile_x / player_tile_y (must be current).
; Trashes: AF, BC, DE, HL
; ============================================================
checkKeyCollect:
        ld hl, KEY_DATA
        ld b, 0                                     ; B = key index
.loop:
        ld a, (hl)                                  ; key tileX
        inc hl
        ld c, (hl)                                  ; key tileY
        inc hl
        ld e, (hl)                                  ; status
        inc hl                                      ; HL -> next key record

        ; skip keys that aren't available
        ld d, a                                     ; save key tileX in D (A about to be reused)
        ld a, e
        cp KEY_AVAILABLE
        jr nz, .next                                ; not available -> skip

        ; --- X overlap: abs(player_tile_x - keyX) <= 1 ? ---
        ld a, (player_tile_x)
        sub d                                       ; A = px - kx
        jr nc, .xpos
        neg                                         ; A = |px - kx|
.xpos:
        cp 2
        jr nc, .next                                ; |dx| >= 2 -> no overlap

        ; --- Y overlap: abs(player_tile_y - keyY) <= 1 ? ---
        ld a, (player_tile_y)
        sub c                                       ; A = py - ky
        jr nc, .ypos
        neg
.ypos:
        cp 2
        jr nc, .next                                ; |dy| >= 2 -> no overlap

        ; overlap on both axes -> collected this key
        ld a, b                                     ; A = key index
        scf                                         ; carry set = collected
        ret

.next:
        inc b
        ld a, b
        cp KEY_COUNT
        jr nz, .loop
        or a                            ; clear carry = nothing collected
        ret


; point to end of skull data. We will use this to test if finished processing all the skulls
; saves having a register holding the processed count
baddieEnd equ baddieData + (baddieRecord * baddieCount)

processBaddies:
        ld ix, baddieData                           ; point to start of baddie data
 
.loop:
        call processBaddie                          ; process each baddie in turn
;        call checkBaddieCollision                   ; check collision
;        call c, .hit

        ld de, baddieRecord                         ; get baddie record length
        add ix, de                                  ; point ix to next baddie
        ld a, ixl
        cp low baddieEnd
        jr nz, .loop
        ld a, ixh
        cp high baddieEnd
        jr nz, .loop

        ld a, (viewMode)                            ; get view mode
        or a                                        ; is it 0 (normal map view)
        ret z                                       ; return if normal

        ; -------------------------------------------------------
        ; here we just display the player if we are in Radar mode
        ; -------------------------------------------------------

        ; tile x/y already calculated, just use them
        ld a, (player_tile_x)                       
        ld l, a
        ld h, 0
        add hl, 32

        ld a, (player_tile_y)
        add 32
        ld e, a

        xor a
        NEXTREG $34, a                              ; select sprite slot 0 (player)
        ld a, l
        NEXTREG $35, a                              ; attr 0: X low 8 bits
        ld a, e
        NEXTREG $36, a                              ; attr 1: Y (8-bit)
        ld a, h
        and 1                                       ; X is 9-bit; keep only bit 8
        NEXTREG $37, a                              ; attr 2: X MSB in bit 0
        ld a, 2
        or %10000000                                ; bit 7 = visible
        NEXTREG $38, a                              ; attr 3: pattern + visible flag

        ret

.hit:
       ; collision routine
        ld A, soundHitskull                         ; ready the skull hit sound
        call playsound                              ; play it
        jp takeDamage                               ; update health bar.
                                                    ; the RET in takeDamage will return us to processBaddies 


; IX -> baddie record. Returns carry SET if player overlaps this baddie.
; Trashes AF, DE, HL
checkBaddieCollision:
        ; --- X: |player_px - baddie_x| < COLLIDE_DX ? ---
        ld hl, (player_px)
        ld e, (ix + baddieRecord.lowX)
        ld d, (ix + baddieRecord.highX)
        or a
        sbc hl, de                                  ; HL = player_px - baddie_x
        bit 7, h                                    ; negative?
        jr z, .xAbs
        ex de, hl
        ld hl, 0
        or a
        sbc hl, de                                  ; HL = |dx|
.xAbs:
        ld de, COLLIDE_DX
        or a
        sbc hl, de
        ret nc                                      ; |dx| >= threshold -> no hit (carry clear)

        ; --- Y: |player_py - baddie_y| < COLLIDE_DY ? ---
        ld hl, (player_py)
        ld e, (ix + baddieRecord.lowY)
        ld d, (ix + baddieRecord.highY)
        or a
        sbc hl, de
        bit 7, h
        jr z, .yAbs
        ex de, hl
        ld hl, 0
        or a
        sbc hl, de
.yAbs:
        ld de, COLLIDE_DY
        or a
        sbc hl, de
        ret                                         ; carry set if |dy| < threshold -> HIT



processBaddie:
        ld h, (ix +baddieRecord.highX)              ; get baddie X
        ld l, (ix +baddieRecord.lowX)
        ld (baddie_x), hl
        ld a, l
        and 7
        ld iyh, a
        DIV_HL_8                                    ; div by 8 to get tile Y
        ld b, l                                     ; save in B, see newTile below

        ld h, (ix +baddieRecord.highY)              ; get baddie Y
        ld l, (ix +baddieRecord.lowY)
        ld (baddie_y), hl
        ld a, l
        and 7
        ld iyl, a
        DIV_HL_8                                    ; divide by 8 to get tile Y
        ld c, l                                     ; save in C, see newTile below

; Decide only when grid-aligned (iyh==0 AND iyl==0) - the only
        ; moment a turn is possible. "Tile changed" fired at the far tile
        ; edge when moving up/left, where the turn check is gated out.
        ld a, iyh
        or iyl                                      ; both zero => on grid intersection
        jr z, newTile                               ; aligned -> run the decision

        ld a, (ix +baddieRecord.dir)                ; not aligned -> continue current dir
        jp gotDir                                   ; jump to do the move
        
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

moveAvailable:
        ; E = available-direction mask. Choose pick method by mode.
        ; Read own-cell distance first (one field read) -> sets lastDist.
        ld b, (ix + baddieRecord.tileX)             ; B = tileX
        ld c, (ix + baddieRecord.tileY)             ; C = tileY
        GET_WORLD_VALUE DFIELD_PAGE, USE_BC

        ld (ix + baddieRecord.lastDist), a
        ld c, a                                     ; keep own distance in C for the mode test
                                                    ; (B no longer needed; pickByField re-reads tileX/Y)

        ld a, (ix + baddieRecord.mode)
        cp mode_wander
        jr z, .pickWander                           ; forced wander

        cp mode_hunt
        jr z, .pickHunt                             ; forced hunt

        ; mode_auto: hunt only if own distance <= 253 (scent present)
        ld a, c
        cp 254
        jr nc, .pickWander                          ; >=254 -> no scent -> wander

.pickHunt:
        call pickByField                            ; A = chosen vdir, or 0 if none
        and a
        jr nz, gotDir                               ; got a direction
        ; fall through to wander if field gave nothing

.pickWander:
        ld a, e
        call random

gotDir:
        ld b, a                                     ; B = chosen direction (vdir flag)

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

; ============================================================
; pickByField - of the available directions (mask in E), choose the
; neighbour with the lowest field distance. Returns vdir flag in A,
; or 0 if none usable. Reads tileX/tileY from the record.
; ============================================================
pickByField:
        ld b, (ix + baddieRecord.tileX)             ; get baddie tile X
        ld c, (ix + baddieRecord.tileY)             ; get baddie tile Y
        ld a, (ix + baddieRecord.lastDist)          ; own-cell distance
        ld (pf_best), a                             ; save best found

        xor a                                       ; A = 0
        ld (pf_dir), a                              ; current direction is nothing

        bit dir_left, e                             ; is a turn left permitted
        jr z, .noL                                  ; branch if not
        ld a, b                                     ; get tile X
        dec a                                       ; look left
        ld l, a                                     ; put test tile X in H for lookup
        ld h, c                                     ; put tile Y in L for lookup
        GET_WORLD_VALUE DFIELD_PAGE, USE_HL         ; get (in A) the flood value
        ld d, vdir_left                             ; mark that we are considering left
        call .consider                              ; see if its the best move
.noL:
        bit dir_right, e                            ; is a turn right permitted
        jr z, .noR                                  ; branch if not
        ld a, b                                     ; get tile X
        inc a                                       ; sprites are 2x2 so we need to look right +2
        inc a
        ld l, a                                     ; put test tile X in H for lookup
        ld h, c                                     ; put tile Y in L for lookup
        GET_WORLD_VALUE DFIELD_PAGE, USE_HL         ; get (in A) the flood value here
        ld d, vdir_right                            ; mark that we are considering right
        call .consider                              ; see if its the best move
.noR:
        bit dir_down, e
        jr z, .noD
        ld l, b
        ld a, c
        inc a
        inc a
        ld h, a
        GET_WORLD_VALUE DFIELD_PAGE, USE_HL
        ld d, vdir_down
        call .consider
.noD:
        bit dir_up, e
        jr z, .noU
        ld l, b
        ld a, c
        dec a
        ld h, a
        GET_WORLD_VALUE DFIELD_PAGE, USE_HL
        ld d, vdir_up
        call .consider
.noU:
        ld a, (pf_dir)
        ret

.consider:
        ld hl, pf_best                              ; point to store of best move
        cp (hl)                                     ; compare with current tile value
        ret nc                                      ; return if no better
        ld (hl), a                                  ; otherwise store new best
        ld a, d                                     ; get the tested direction
        ld (pf_dir), a                              ; store as the one to use
        ret

pf_best     db 0
pf_dir      db 0


baddieMoveLUT:
defw    0, doMoveLeft1, doMoveRight1, 0, doMoveDown1, 0, 0, 0, doMoveUp1

chkLeft1
        ld a, iyl                                   ; we only want to test horizontal moves if baddie Y is exactly on a tile
        and a                                       ; is it?
        ret nz                                      ; return if not

        checkLeftM baddie_x, baddie_y, move_delta_baddie

chkRight1
        ld a, iyl                                   ; we only want to test horizontal moves if baddie Y is exactly on a tile
        and a                                       ; is it?
        ret nz                                      ; return if not

        checkRightM baddie_x, baddie_y, move_delta_baddie

chkDown1
        ld a, iyh                                   ; we only want to test vertical moves if baddie X is exactly on a tile
        and a                                       ; is it?
        ret nz                                      ; return if not

        checkDownM baddie_x, baddie_y, move_delta_baddie

chkUp1
        ld a, iyh                                   ; we only want to test vertical moves if baddie X is exactly on a tile
        and a                                       ; is it?
        ret nz                                      ; return if not

        checkUpM baddie_x, baddie_y, move_delta_baddie

doMoveLeft1
        ld hl, (baddie_x)
        ld bc, move_delta_baddie
        or a
        sbc hl, bc
        ld (ix +baddieRecord.highX), h
        ld (ix +baddieRecord.lowX), l
        ld a, vdir_left
        ld (ix +baddieRecord.dir), a
        jr displayBaddie 

doMoveRight1
        ld hl, (baddie_x)
        ld bc, move_delta_baddie
        add hl, bc
        ld (ix +baddieRecord.highX), h
        ld (ix +baddieRecord.lowX), l
        ld a, vdir_right
        ld (ix +baddieRecord.dir), a

        jr displayBaddie 

doMoveDown1
        ld hl, (baddie_y)
        ld bc, move_delta_baddie
        add hl, bc
        ld (ix +baddieRecord.highY), h
        ld (ix +baddieRecord.lowY), l
        ld a, vdir_down
        ld (ix +baddieRecord.dir), a

        jr displayBaddie 

doMoveUp1
        ld hl, (baddie_y)
        ld bc, move_delta_baddie
        or a
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

        ld a, (viewMode)
        or a
        jp nz, radarBaddie

    ; ---------- SCREEN X ----------
        ; HL = baddie world X
        ld l, (ix + baddieRecord.lowX)
        ld h, (ix + baddieRecord.highX)
        ld bc, (cam_px)                             ; BC = player world X
        or a                                        ; clear carry for a clean subtract
        sbc hl, bc                                  ; HL = baddieX - playerX  (signed)
    ; add screen centre AND the 15px overhang bias in one go.
    ; CENTER_SCREEN_X + 15 = 152 + 15 = 167, which fits in 8 bits,
    ; so we can use the Z80N "add hl,a" (cheaper to set up than add hl,bc).
        ld a,  15                                   ; A = 167  (centre + bias)
        add hl, a                                   ; Z80N: HL = biased screen X
    ; HL now holds (screenX + 15). Visible-with-overhang means the
    ; UN-biased X is in -15..319, i.e. the BIASED value is in 0..334.
    ; Reject anything outside 0..334 with an unsigned range test.
        ld a, h                                     ; look at high byte of biased X
        cp 1                                        ; H = 0 ?  (biased X = 0..255)
        jr c, .xInRange                             ; H = 0 -> definitely <= 334, in range
        jr nz, .hideBaddie                          ; H >= 2 -> biased X >= 512 -> off right
    ; H = 1 here, so biased X = 256..511; allowed only up to 334 ($014E),
    ; meaning the low byte must be < 79 (334 - 256 = 78).
        ld a, l
        cp 79
        jr nc, .hideBaddie                          ; low byte >= 79 -> off right edge
.xInRange:
        push hl                                     ; save biased X (we still need it later)

    ; ---------- SCREEN Y ----------
    ; HL = baddie world Y
        ld l, (ix + baddieRecord.lowY)
        ld h, (ix + baddieRecord.highY)
        ld bc, (cam_py)             ; BC = player world Y
        or a                           ; clear carry
        sbc hl, bc                     ; HL = baddieY - playerY  (signed)
    ; centre + bias again: CENTER_SCREEN_Y + 15 = 120 + 15 = 135, fits in 8 bits.
        ld a, 15     ; A = 135
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

radarBaddie:
        ld a, 32

        ld l, (ix +baddieRecord.tileX)
        ld h, 0
        add hl, a

        ld e, (ix +baddieRecord.tileY)
        add a, e
        ld e, a

        ld a, (ix +baddieRecord.index)
        NEXTREG $34, a                 ; select sprite slot 1
        ld a, l
        NEXTREG $35, a                 ; attr 0: X low 8 bits
        ld a, e
        NEXTREG $36, a                 ; attr 1: Y (8-bit)
        ld a, h
        and 1                          ; X is 9-bit; keep only bit 8
        NEXTREG $37, a                 ; attr 2: X MSB in bit 0
        ld a, 3
        or %10000000                   ; bit 7 = visible
        NEXTREG $38, a                 ; attr 3: pattern + visible flag

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
    db 1                 ; Initial 16-bit seed (Must not be zero!)

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
INCBIN  "testmaze2.map", 0, 16384                    ; first 16 KB

; === Chunk 2 (bytes 16384-32767) -> 8 KB Page 42/43 ===
MMU     6, TILEMAP_PAGE + 2
MMU     7, TILEMAP_PAGE + 3
ORG     $C000
tilemap_part2:
INCBIN  "testmaze2.map", 16384, 16384

; === Chunk 3 (bytes 32768-49151) -> 8 KB Page 44/45 ===
MMU     6, TILEMAP_PAGE + 4
MMU     7, TILEMAP_PAGE + 5
ORG     $C000
tilemap_part3:
INCBIN  "testmaze2.map", 32768, 16384

; ----------------------------------------------------------------
; Distance field - 48 KB, one byte per maze cell (256x192).
; Same layout as the map (256-byte rows) but in pages 46-51, so the
; tile (x,y) -> address arithmetic is identical to GET_WORLD_VALUE
; with base page DFIELD_PAGE instead of TILEMAP_PAGE.
; Filled by the flood-fill; 255 = wall/unvisited/unreachable.
; ----------------------------------------------------------------
DFIELD_PAGE     EQU     TILEMAP_PAGE + 6

; reserve the six pages so they exist in the .nex (contents set at runtime)
MMU     6, DFIELD_PAGE
MMU     7, DFIELD_PAGE + 1
ORG     $C000
dfield_part1:
DEFS    16384

MMU     6, DFIELD_PAGE + 2
MMU     7, DFIELD_PAGE + 3
ORG     $C000
dfield_part2:
DEFS    16384

MMU     6, DFIELD_PAGE + 4
MMU     7, DFIELD_PAGE + 5
ORG     $C000
dfield_part3:
DEFS    16384

; --- radar / Layer 2 ---
L2_PAGE         equ DFIELD_PAGE + 6     ; Layer 2 image pages (52-57), after the field
L2_BANK16       equ L2_PAGE / 2         ; 16K bank number for reg $12 (=26)

MMU 6, L2_PAGE
MMU 7, L2_PAGE + 1
org $C000
DEFS 16384

MMU 6, L2_PAGE + 2
MMU 7, L2_PAGE + 3
org $C000
DEFS 16384

MMU 6, L2_PAGE + 4
MMU 7, L2_PAGE + 5
org $C000
DEFS 16384

; ----------------------------------------------------------------
; Build the .nex file (automatically includes all used banks)
; ----------------------------------------------------------------
SAVENEX OPEN "maze.nex", progStart, $FF40           ; entry point + stack
SAVENEX AUTO                                        ; include all pages we used
SAVENEX CLOSE