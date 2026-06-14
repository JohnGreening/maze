DEVICE ZXSPECTRUMNEXT

USE_BC              EQU 0                           ; see GET_WORLD_VALUE macro
USE_HL              EQU 1                           ; see GET_WORLD_VALUE macro

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
        srl  a                                      ; divide by 2
        srl  a                                      ; divide by 2 again  → now /4
        srl  a                                      ; /8
        srl  a                                      ; /16
        srl  a                                      ; /32   ← this is the same as tile_y ÷ 32
                                                    ; Why divide by 32?
                                                    ;   Each page is 8192 bytes.
                                                    ;   Each row is 256 bytes.
                                                    ;   8192 ÷ 256 = exactly 32 rows per page.
                                                    ;   Therefore page number = 40 + (tile_y ÷ 32)

        add  a, arg                                 ; add the starting page number

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
