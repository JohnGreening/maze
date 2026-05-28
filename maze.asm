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
        
org $4000

tileMap:
DEFS 1280, 1

TilePatterns:
; Tile000
DB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
DB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile001
DB $00,$00,$01,$00,$00,$00,$01,$00,$11,$11,$11,$11,$00,$10,$00,$00
DB $00,$10,$00,$00,$11,$11,$11,$11,$00,$00,$01,$00,$00,$00,$01,$00

TilePalette0:
DB $E0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
TilePalette0Len EQU ($ - TilePalette0) / 2

SpritePalette0:
DB $03,$01,$E3,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
SpritePalette0Len EQU ($ - SpritePalette0) / 2

SpritePatterns:
; Sprite000
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$00,$00
DB $00,$E3,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$00,$E3,$00,$00,$E3,$E3,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$00,$E3,$E3,$00
DB $00,$E3,$E3,$E3,$00,$E3,$E3,$E3,$E3,$E3,$E3,$00,$E3,$E3,$E3,$00,$00,$E3,$E3,$E3,$E3,$00,$E3,$E3,$E3,$E3,$00,$E3,$E3,$E3,$E3,$00
DB $00,$E3,$E3,$E3,$E3,$E3,$00,$E3,$E3,$00,$E3,$E3,$E3,$E3,$E3,$00,$00,$E3,$E3,$E3,$E3,$E3,$E3,$00,$00,$E3,$E3,$E3,$E3,$E3,$E3,$00
DB $00,$E3,$E3,$E3,$E3,$E3,$E3,$00,$00,$E3,$E3,$E3,$E3,$E3,$E3,$00,$00,$E3,$E3,$E3,$E3,$E3,$00,$E3,$E3,$00,$E3,$E3,$E3,$E3,$E3,$00
DB $00,$E3,$E3,$E3,$E3,$00,$E3,$E3,$E3,$E3,$00,$E3,$E3,$E3,$E3,$00,$00,$E3,$E3,$E3,$00,$E3,$E3,$E3,$E3,$E3,$E3,$00,$E3,$E3,$E3,$00
DB $00,$E3,$E3,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$00,$E3,$E3,$00,$00,$E3,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$00,$E3,$00
DB $00,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
endofSprites:



cam_centre_x        equ 19
cam_centre_y        equ 15
CENTER_SCREEN_X     equ cam_centre_x * 8   ; 152
CENTER_SCREEN_Y     equ cam_centre_y * 8   ; 120
cam_px              dw 19*8
cam_py              dw 15*8

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

baddieCount         equ 1
baddieData          defs baddieRecord * baddieCount

progStart:
; *****************************************
; call to initialise the graphics
; *****************************************

; Configure tilemap control
        NEXTREG $6b, %10100001
; bit 7 1= enable tilemap
; bit 6 1= 80x32, 0=40x32
; bit 5 1= use 6c for attributes (i.e. 1 byte tilemap mode)
; bit 4 1= 2nd tilemap palette, 0= first
; bit 3 1= activate text mode
; bit 2 reserved, set to 0
; bit 1 1=512, 0=256 tilemap mode
; bit 0 1= force tilemap ontop of ULA

; Default tilemap attribute for 8bit maps
; i.e. when using 1 byte tilemap mode
; NB limits colours to 0-15
        NEXTREG $6c, $0
; bit 7-4 Palette offset
; bit 3 1=mirror in X direction
; bit 2 1=mirror in Y direction
; bit 1 1=rotate 90deg clockwise
; bit 0 1=ula overtilemap, 0=tilemap over ULA

; ULA control
        NEXTREG $68, $0
; bit 7 1=disable ULA output
; bit 6 concerned with blending in SLU modes 6/7
;       1=select ULA/tilemap mix
;       0=select ULA colour
; bits 5-1 reserved, always 0
; bit 0 1=enable stencil mode when ULA & tilemap enabled

; point to the tilemap and tile pattern data
        NEXTREG $6e, tileMap / 256
        NEXTREG $6f, TilePatterns / 256

; Palette Control
; set values for Tilemap palette 0
        NEXTREG $43, %00110000
; bit 7 1=disable palette auto inc
; bit 6-4 select palette for r/w
; 000 = ULA palette 1
; 100 = ULA palette 2
; 001 = Layer 2 palette 1
; 101 = Layer 2 palette 2
; 010 = Sprites palette 1
; 110 = Sprites palette 2
; 011 = Tilemap palette 1
; 111 = Tilemap palette 2
; bit 3
; bit 2
; bit 1
; bit 0

; Set index of transparent colour in Tilemap palette
        NEXTREG $4c, 15

; load the colours into the palette memory
; here we are using 9 bit colours, so use $44 to do the load

; first initialise the palette index to 0
        NEXTREG $40, 0

; set the number of colours
; set location of Tilemap palette data
        LD B, TilePalette0Len
        LD HL, TilePalette0

; write palette data, 2 bytes per colour
tilemapPalette0Loop:
        LD A, (HL)
        INC HL
        NEXTREG $44, A
        LD A, (HL)
        INC HL
        NEXTREG $44, A
        DJNZ tilemapPalette0Loop

; Configure Sprite and Layers System
; NEXTREG $15, %00000011
        NEXTREG $15, %00010111
; bit 7 1=enable lo-res 
; bit 6 1=flip sprite rendering priority
; bit 5 1=change clipping over border mode
; bit 4-2 000=sprites on top, layer 2 under
; bit 1 1=enable sprites over border
; bit 0 1=enable sprite visibility
 
        LD BC, $303b                 ; set port for Sprites
        SUB A, A                     ; Set sprite index to 0
        OUT (C), A                   ; write to port

        LD HL, SpritePatterns; point to sprite patterns
        LD BC, $5b                    ; set port to write patterns to
        LD DE, endofSprites - SpritePatterns

spritePatternLoop:
        LD A, (HL)                    ; get each byte of pattern data
        INC HL                        ; ready for next read
        OUT (C), A                    ; upload to sprite memory
        DEC DE                        ; dec loop count
        LD A, E                       ; test for 0
        OR A, D
        JR NZ, spritePatternLoop      ; loop if more data

; Palette Control
; set values for Sprites palette 1
        NEXTREG $43, %00100000
; bit 7 1=disable palette auto inc
; bit 6-4 select palette for r/w
; 000 = ULA palette 1
; 100 = ULA palette 2
; 001 = Layer 2 palette 1
; 101 = Layer 2 palette 2
; 010 = Sprites palette 1
; 110 = Sprites palette 2
; 011 = Tilemap palette 1
; 111 = Tilemap palette 2
; bit 3
; bit 2
; bit 1
; bit 0

; set global transparency fallback
        NEXTREG $14, 0

; load the colours into the palette memory
; here we are using 9 bit colours, so use $44 to do the load

; first initialise the palette index to 0
        NEXTREG $40, 0

; set the number of colours 
; set location of sprite palette data
        LD B, SpritePalette0Len
        LD HL, SpritePalette0

; write palette data, 2 bytes per colour
spritePalette0Loop:
        LD A, (HL)
        INC HL
        NEXTREG $44, A
        LD A, (HL)
        INC HL
        NEXTREG $44, A
        DJNZ spritePalette0Loop

otherSetup:
  ;      LD A, 3             ; Load speed index (3 = 28 MHz)
        NEXTREG $07, A

        call setTilemapBorder
        call copy_visible_window
        call showSprite

        ld ix, baddieData
        ld a, 1
        ld (ix +baddieRecord.index), a
        ld hl, 472 - 8
        ld (ix +baddieRecord.highX), h
        ld (ix +baddieRecord.lowX), l
        ld hl, 376 - 24
        ld (ix +baddieRecord.highY), h
        ld (ix +baddieRecord.lowY), l
        ld a, 0
        ld (ix +baddieRecord.pattern), a
        ld a, vdir_left
        ld (ix +baddieRecord.dir), a
        ld a, 58
        ld (ix +baddieRecord.tileX), a
        ld a, 44
        ld (ix +baddieRecord.tileY), a


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

        ld hl, (player_px)                          ; get player pixel X
        DIV_HL_8                                    ; divide by 8 to get tile X
        ld b, l                                     ; and save in b for later

        ld hl, (player_py)                          ; get player pixel Y
        DIV_HL_8                                    ; divide by 8 to get tile Y
        ld c, l                                     ; and save in c for later
        
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
        sub cam_centre_x                            ; - 19 for lhs of screen
        ld b, a                                     ; save
        
        ld a, c                                     ; get current player tile Y
        ld (player_tile_y), a                       ; save it away
        sub cam_centre_y                            ; - 15 for top of screen
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
        push bc
.loop        
        ld bc, $243B                                ; register select port
        ld a, $1E
        out (c), a                                  ; select ULA status register
        inc b                                       ; now point to data port $253B
        in a, (c)                                   ; read status
        bit 0, a
        jr z, .loop
        pop bc
        ret

setTilemapBorder:
        nextreg $1C, %00001000                      ; Reset tilemap clip window index (bit 3 = 1)

    ; ------------------------------------------------------------
    ; Write the four clip coordinates to register $1B
    ; X values are in 2-pixel units (0-159 = full 320px width)
    ; Y values are 1:1 pixels (0-255)
    ; 4px border = inset of 2 X-units and 4 Y-pixels
    ; ------------------------------------------------------------
        nextreg $1B, 2                              ; X1 = 2   → left edge  = pixel 4
        nextreg $1B, 157                            ; X2 = 157 → right edge = pixel 315 (319-4)
        nextreg $1B, 4                              ; Y1 = 4   → top edge   = pixel 4
        nextreg $1B, 251                            ; Y2 = 251 → bottom edge= pixel 251 (255-4)

        ret

showSprite
        LD A, 0                                     ; get the sprite index
        NEXTREG $34, A                              ; set sprite to activate
        ld hl, (cam_px)
        ld de, (cam_py)
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

        ld h, (ix +baddieRecord.highX)              ; get baddie X
        ld l, (ix +baddieRecord.lowX)
        ld a, l
        and 7
        ld iyh, a
        DIV_HL_8                                    ; div by 8 to get tile Y
        ld b, l                                     ; save in D

        ld h, (ix +baddieRecord.highY)              ; get baddie Y
        ld l, (ix +baddieRecord.lowY)
        ld a, l
        and 7
        ld iyl, a
        DIV_HL_8                                    ; divide by 8 to get tile Y
        ld c, l                                     ; save in C


        ld a, (ix +baddieRecord.tileX)              ; get last tile X
        cp b                                        ; change from last time
        jr nz, newTile                              ; jump if so

        ld a, (ix +baddieRecord.tileY)              ; get last tile Y
        cp c                                        ; change from last time
        jr nz, newTile                              ; jump if so

        ; baddie is not newly on a new tile, therefore continue in current direction (d)
        ld a, (ix +baddieRecord.dir)                ; get current direction in d
        ld b, a
;        ld a, b
;        cp vdir_left
;        jp z, displayBaddie
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
        jp (hl)

baddieMoveLUT:
defw    0, doMoveLeft1, doMoveRight1, 0, doMoveDown1, 0, 0, 0, doMoveUp1

chkLeft1
        ld a, iyl                                   ; we only want to test horizontal moves if baddie Y is exactly on a tile
        and a                                       ; is it?
        ret nz                                      ; return if not

        ld h, (ix +baddieRecord.highX)
        ld l, (ix +baddieRecord.lowX)
        ld bc, move_delta
        sbc hl, bc

        ; now test if we have bumped into a wall
        DIV_HL_8
        ld b, l
        ld h, (ix +baddieRecord.highY)
        ld l, (ix +baddieRecord.lowY)
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

        ld h, (ix +baddieRecord.highX)
        ld l, (ix +baddieRecord.lowX)
	    ld bc, move_delta                           ; get move delta
        adc hl, bc

        ; now test if we have bumped into a wall
        add hl, 15                                  ; the sprite extends 0-15px right
        DIV_HL_8
        ld b, l
        ld h, (ix +baddieRecord.highY)
        ld l, (ix +baddieRecord.lowY)
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

        ld h, (ix +baddieRecord.highY)
        ld l, (ix +baddieRecord.lowY)
        ld bc, move_delta                           ; get pixel delta
        adc hl, bc                                  ; do move

        ; now test if we have bumped into a wall
        add hl, 15                                  ; the sprite extends 0-15px down
        DIV_HL_8
        ld c, l
        ld h, (ix +baddieRecord.highX)
        ld l, (ix +baddieRecord.lowX)
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

        ld h, (ix +baddieRecord.highY)
        ld l, (ix +baddieRecord.lowY)
        ld bc, move_delta                           ; get pixel delta
        sbc hl, bc                                  ; do move

        ; now test if we have bumped into a wall
        DIV_HL_8
        ld c, l
        ld h, (ix +baddieRecord.highX)
        ld l, (ix +baddieRecord.lowX)
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


;moveBaddie:
doMoveLeft1
;        bit dir_left, d
;        jr z, .doMoveRight

        ld h, (ix +baddieRecord.highX)
        ld l, (ix +baddieRecord.lowX)
        ld bc, move_delta
        sbc hl, bc
        ld (ix +baddieRecord.highX), h
        ld (ix +baddieRecord.lowX), l
        ld a, vdir_left
        ld (ix +baddieRecord.dir), a
        jr displayBaddie 

doMoveRight1
;        bit dir_right, d
;        jr z, .doMoveDown

        ld h, (ix +baddieRecord.highX)
        ld l, (ix +baddieRecord.lowX)
        ld bc, move_delta
        adc hl, bc
        ld (ix +baddieRecord.highX), h
        ld (ix +baddieRecord.lowX), l
        ld a, vdir_right
        ld (ix +baddieRecord.dir), a

        jr displayBaddie 

doMoveDown1
;        bit dir_down, d
;        jr z, .doMoveUp

        ld h, (ix +baddieRecord.highY)
        ld l, (ix +baddieRecord.lowY)
        ld bc, move_delta
        adc hl, bc
        ld (ix +baddieRecord.highY), h
        ld (ix +baddieRecord.lowY), l
        ld a, vdir_down
        ld (ix +baddieRecord.dir), a

        jr displayBaddie 

doMoveUp1
;        bit dir_up, d
;        jp z, .displayBaddie

        ld h, (ix +baddieRecord.highY)
        ld l, (ix +baddieRecord.lowY)
        ld bc, move_delta
        sbc hl, bc
        ld (ix +baddieRecord.highY), h
        ld (ix +baddieRecord.lowY), l
        ld a, vdir_up
        ld (ix +baddieRecord.dir), a


displayBaddie:
        ; IX already points at the baddie record (from processBaddies)
        ; ------------------------------------------------------------
        ; Compute screen X = baddie_x - player_px + CENTER_SCREEN_X
        ld l, (ix + baddieRecord.lowX)
        ld h, (ix + baddieRecord.highX)
        ld bc, (player_px)
        or a
        sbc hl, bc
        ld bc, CENTER_SCREEN_X
        add hl, bc                  ; HL = screen_x

        ; Check if in view (0 ≤ X ≤ 319)
        bit 7, h
        jr nz, .hideBaddie          ; off left
        ld a, h
        or a
        jr nz, .hideBaddie          ; way off right
        ld a, l
        cp 255
        jr nc, .hideBaddie          ; off right

        push hl                     ; save screen X

        ; ------------------------------------------------------------
        ; Compute screen Y = baddie_y - player_py + CENTER_SCREEN_Y
        ld l, (ix + baddieRecord.lowY)
        ld h, (ix + baddieRecord.highY)
        ld bc, (player_py)
        or a
        sbc hl, bc
        ld bc, CENTER_SCREEN_Y
        add hl, bc                  ; HL = screen_y

        ; Check if in view (0 ≤ Y ≤ 255)
        bit 7, h
        jr nz, .hidePop
        ld a, h
        or a
        jr nz, .hidePop

        ; ============================================================
        ; BADDIE IS ON SCREEN → show sprite 1
        pop de                      ; DE = screen_x (E=LSB, D=MSB)
        ld a, 1                     ; sprite index 1
        NEXTREG $34, a
        ld a, e
        NEXTREG $35, a              ; X LSB
        ld a, l                     ; Y LSB (still in L)
        NEXTREG $36, a
        ld a, d
        and 1
        NEXTREG $37, a              ; X MSB (matches your player sprite style)
        ld a, (ix + baddieRecord.pattern)
        or %10000000                ; visible bit
        NEXTREG $38, a
        ret

.hidePop:
        pop hl
.hideBaddie:
        ; hide sprite 1 (just clear visible bit)
        ld a, 1
        NEXTREG $34, a
        NEXTREG $38, 0              ; visible = off
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
        PUSH HL
        LD HL, (seed)        ; Load 16-bit seed
        LD D, H
        LD E, L              ; Save original seed in DE
        ADD HL, HL           ; HL = seed * 2
        SBC A, A             ; A = 0 or 255 (based on carry)
        AND 0FDH             ; Mask for constant 253 (for Galois LFSR)
        XOR E                ; Combine with L
        LD C, A              ; Store in C
        SBC HL, BC           ; Subtract from seed
        JR NC, RND_OK        ; Check for underflow
        INC HL               ; Handle underflow
RND_OK:
        LD (seed), HL        ; Save the new seed
        LD A, H              ; Return the high byte of the result in A
        POP HL
        AND %00000011                               ; restrict rnd to 0-3
        ADD HL, A
        LD A, (HL)

        RET

seed:
    DW 1                 ; Initial 16-bit seed (Must not be zero!)        ld a, (hl)

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