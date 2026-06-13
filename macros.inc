DEVICE ZXSPECTRUMNEXT

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
