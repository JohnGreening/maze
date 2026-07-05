DEVICE ZXSPECTRUMNEXT

USE_BC              EQU 0                           ; see GET_WORLD_VALUE macro
USE_HL              EQU 1                           ; see GET_WORLD_VALUE macro

MACRO SPEED arg
        ld a, arg
        NEXTREG $07, A
        ENDM

MACRO DIV_HL_8
; simple 16-bit divide without the CALL/RET overhead
        srl h                                       ; divide by 2
        rr l
        srl h                                       ; divide by 4
        rr l
        srl h                                       ; divide by 8
        rr l
        ENDM

MACRO GET_WORLD_VALUE arg, arg1
; given B= tile X, C= tile Y, return "world" value at this position in the world map
;
;       arg  is TILEMAP_PAGE
;            or DFIELD_PAGE
;
;       arg1 decides if input comes from BC or directly from HL
;            NB if directly from HL then L = tile X, H = tile Y
;
        if arg1 = 0
        ld h, c                                     ; read the Y tile coordinate of the top-left corner we want
                                                    ; put it in H (this is the same as multiplying by 256)
        ld l, b                                     ; read the X tile coordinate into L
                                                    ; Result: HL now holds tile_y * 256 + tile_x
                                                    ; This is the byte offset into "world" map.
        endif

    ; STEP 2: Calculate which 8K physical page the data lives in
        ld   a,h                                    ; take the high byte of the offset (which is tile_y)
;        srl  a                                      ; divide by 2
;        srl  a                                      ; divide by 2 again  → now /4
;        srl  a                                      ; /8
;        srl  a                                      ; /16
;        srl  a                                      ; /32   ← this is the same as tile_y ÷ 32
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
                                                    ;   Therefore page number = 40 + (tile_y ÷ 32)

        add  a, arg                                 ; add the starting page number
        ld (curWorldPage), a                        ; save page for subsequent reads - likely no need to reload
        nextreg $56,a                               ; set MMU slot 6 ($C000-$DFFF) to that page


    ; STEP 3: Keep only the part of the address that fits inside one 8K page
        ld   a,h                                    ; get the high byte again
        and  $1F                                    ; $1F is binary 00011111 → keeps only the lowest 5 bits
                                                    ; This is exactly the same as (tile_y * 256 + tile_x) modulo 8192
                                                    ; (because 8192 = 2^13 and we are discarding everything above bit 12)
        ld   h,a                                    ; HL now holds the offset *inside* the current 8K page

    ; STEP 4: add the page offset so we can read it
        add  hl, $C000                              ; HL = $C000 + offset_inside_page
                                                    ; HL now points directly at the first byte we want to copy
        ld a, (hl)                                  ; so get the byte
        ENDM

MACRO checkLeftM argX, argY, argMoveDelta
        ld hl, (argX)                               ; get X pixel
        ld bc, argMoveDelta                         ; move pixel delta
        or a                                        ; clear carry
        sbc hl, bc                                  ; simulate move left
        DIV_HL_8                                    ; divide by 8 to get tile X
        ld b, l                                     ; B = tile X

        ld hl, (argY)                               ; get Y pixel
        DIV_HL_8                                    ; divide by 8 to get tile Y
        ld c, l                                     ; C = tile Y

        GET_WORLD_VALUE TILEMAP_PAGE, USE_BC        ; see what tile is here
        cp MAP_WALL                                 ; is it a wall?
        ret z                                       ; return if so, do nothing

; ----------------------------------------------------------------
; worldBelow - read the map/field byte one tile-row below the byte
; GET_WORLD_VALUE just fetched. HL still points at that byte.
; Handles the (rare) 8K page cross. Returns tile in A.
; ----------------------------------------------------------------
.worldBelow:
        inc  h                                      ; +256 bytes = one map row down
        ld   a, h                                   ; put in a for compare
        cp   $E0                                    ; walked past the end of slot 6 ($C000-$DFFF)?
        jr   nz, .same                              ; branch if not
        ld   h, $C0                                 ; wrap back to slot-6 base
        ld   a, (curWorldPage)                      ; get last saved page
        inc  a                                      ; advance it
        ld   (curWorldPage), a                      ; save it back
        nextreg $56, a                              ; page in new block
.same:
        ld   a, (hl)                                ; see what tile is here
        cp MAP_WALL                                 ; is it a wall?
        ret z                                       ; return if so, do nothing

        set dir_left, e                             ; set bit in E indicating move is allowed
        ret
        ENDM

MACRO checkRightM argX, argY, argMoveDelta
        ld hl, (argX)                               ; get X pixel
        ld bc, argMoveDelta                         ; move pixel delta
        add hl, bc                                  ; simulate move Right
        add hl, 15                                  ; the sprite extends 0-15px right

        DIV_HL_8                                    ; divide by 8 to get tile X
        ld b, l                                     ; B = tile X

        ld hl, (argY)                               ; get Y pixel
        DIV_HL_8                                    ; divide by 8 to get tile Y
        ld c, l                                     ; C = tile Y

        GET_WORLD_VALUE TILEMAP_PAGE, USE_BC        ; see what tile is here
        cp MAP_WALL                                 ; is it a wall?
        ret z                                       ; return if so, do nothing

; ----------------------------------------------------------------
; worldBelow - read the map/field byte one tile-row below the byte
; GET_WORLD_VALUE just fetched. HL still points at that byte.
; Handles the (rare) 8K page cross. Returns tile in A.
; ----------------------------------------------------------------
.worldBelow:
        inc  h                                      ; +256 bytes = one map row down
        ld   a, h                                   ; put in a for compare
        cp   $E0                                    ; walked past the end of slot 6 ($C000-$DFFF)?
        jr   nz, .same                              ; branch if not
        ld   h, $C0                                 ; wrap back to slot-6 base
        ld   a, (curWorldPage)                      ; get last saved page
        inc  a                                      ; advance it
        ld   (curWorldPage), a                      ; save it back
        nextreg $56, a                              ; page in new block
.same:
        ld   a, (hl)                                ; see what tile is here
        cp MAP_WALL                                 ; is it a wall?
        ret z                                       ; return if so, do nothing

        set dir_right, e                            ; set bit in E indicating move is allowed
        ret
        ENDM

MACRO checkDownM argX, argY, argMoveDelta
        ld hl, (argY)                               ; get Y pixel
        ld bc, argMoveDelta                         ; move pixel delta
        add hl, bc                                  ; simulate move Down
        add hl, 15                                  ; the sprite extends 0-15px down

        DIV_HL_8                                    ; divide by 8 to get tile Y
        ld c, l                                     ; C = tile Y

        ld hl, (argX)                               ; get X pixel
        DIV_HL_8                                    ; divide by 8 to get tile X
        ld b, l                                     ; B = tile X

        GET_WORLD_VALUE TILEMAP_PAGE, USE_BC        ; see what tile is here
        cp MAP_WALL                                 ; is it a wall?
        ret z                                       ; return if so, do nothing

; ----------------------------------------------------------------
; worldAdjacent - read the map/field byte one tile to the right
; GET_WORLD_VALUE just fetched. HL still points at that byte.
; guaranteed to be on same page, so just inc HL
; ----------------------------------------------------------------
        inc hl                                      ; point to adjacent tile right
        ld a, (hl)                                  ; see what tile is here
        cp MAP_WALL                                 ; is it a wall?
        ret z                                       ; return if so, do nothing

        set dir_down, e                             ; set bit in E indicating move is allowed
        ret
        ENDM

MACRO checkUpM argX, argY, argMoveDelta
        ld hl, (argY)                               ; get Y pixel
        ld bc, argMoveDelta                         ; move pixel delta
        or a                                        ; clear carry
        sbc hl, bc                                  ; simulate move Down

        DIV_HL_8                                    ; divide by 8 to get tile Y
        ld c, l                                     ; C = tile Y

        ld hl, (argX)                               ; get X pixel
        DIV_HL_8                                    ; divide by 8 to get tile X
        ld b, l                                     ; B = tile X

        GET_WORLD_VALUE TILEMAP_PAGE, USE_BC        ; see what tile is here
        cp MAP_WALL                                 ; is it a wall?
        ret z                                       ; return if so, do nothing

; ----------------------------------------------------------------
; worldAdjacent - read the map/field byte one tile to the right
; GET_WORLD_VALUE just fetched. HL still points at that byte.
; guaranteed to be on same page, so just inc HL
; ----------------------------------------------------------------
        inc hl                                      ; point to adjacent tile right
        ld a, (hl)                                  ; see what tile is here
        cp MAP_WALL                                 ; is it a wall?
        ret z                                       ; return if so, do nothing

        set dir_up, e                               ; set bit in E indicating move is allowed
        ret
        ENDM

