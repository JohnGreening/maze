; ============================================================
; maptest.asm - standalone test
; Load testmaze.map, render it to Layer 2 (256x192x8bpp),
; red walls / white paths, show it, wait for a key, exit.
; ============================================================
        device ZXSPECTRUMNEXT

; --- page layout ---
MAP_PAGE        equ 40              ; map data: 8K pages 40-45 (48K)
L2_PAGE         equ 52              ; Layer 2 image: 8K pages 52-57 (48K)
L2_BANK16       equ L2_PAGE / 2     ; = 26, the 16K bank number for reg $12

; --- Layer 2 8bpp colours (default palette = RRRGGGBB) ---
L2_WALL         equ %11100000       ; red
L2_PATH         equ %11111111       ; white

        org $8000
progStart:
        di

        ; ----- build the Layer 2 image from the map -----
        call buildMapImage

        ; ----- set up and show Layer 2 -----
        nextreg $12, L2_BANK16      ; Layer 2 main screen base bank
        nextreg $70, %00000000      ; 256x192x8bpp, palette offset 0
        nextreg $16, 0              ; L2 X scroll = 0
        nextreg $17, 0              ; L2 Y scroll = 0
        nextreg $18, 0              ; clip X1
        nextreg $18, 255            ; clip X2
        nextreg $18, 0              ; clip Y1
        nextreg $18, 191            ; clip Y2

        ld bc, $123b                ; Layer 2 control port
        ld a, 2                     ; bit 1 = enable/visible
        out (c), a

        ; ----- wait for any key, then exit -----
        call waitKey

        ; hide Layer 2 and return to BASIC/loader
        ld bc, $123b
        xor a
        out (c), a
        ei
        ret

; ============================================================
; buildMapImage - for every tile (x,y) read the map (0=path,
; nonzero=wall) and write a colour byte to the matching Layer 2
; pixel. Both map and L2 use the same layout (256-byte rows,
; 32 rows per 8K page), differing only by base page.
; ============================================================
buildMapImage:
        ld c, 0                     ; C = y
.rowLoop:
        ld b, 0                     ; B = x
.colLoop:
        ; --- read map tile (B=x, C=y) ---
        ld h, c
        ld l, b
        ld a, h
        srl a
        srl a
        srl a
        srl a
        srl a                       ; A = y / 32  (page within block)
        add a, MAP_PAGE
        nextreg $56, a              ; page map bank into slot 6
        ld a, h
        and $1F
        ld h, a
        add hl, $C000               ; HL -> map byte
        ld a, (hl)
        or a                        ; 0 = path?
        ld d, L2_PATH
        jr z, .haveCol
        ld d, L2_WALL
.haveCol:
        ; D = colour to write

        ; --- write to Layer 2 byte for (B=x, C=y) ---
        ld h, c
        ld l, b
        ld a, h
        srl a
        srl a
        srl a
        srl a
        srl a
        add a, L2_PAGE
        nextreg $56, a              ; page L2 bank into slot 6
        ld a, h
        and $1F
        ld h, a
        add hl, $C000               ; HL -> L2 byte
        ld a, d
        ld (hl), a                  ; write colour

        inc b
        jr nz, .colLoop             ; B wraps 255->0 after 256 columns
        inc c
        ld a, c
        cp 192
        jr nz, .rowLoop
        ret

; ============================================================
; waitKey - wait until any key on the keyboard is pressed.
; Reads all 8 half-rows; a 0 in bits 0-4 means a key is down.
; ============================================================
waitKey:
.wait:
        ld a, $fe                   ; scan all rows: address line low byte
        ld b, $00                   ; B=0 -> all 8 address lines active
        in a, ($fe)                 ; read keyboard
        and %00011111               ; keys are bits 0-4 (active low)
        cp %00011111                ; all 1 = nothing pressed
        jr z, .wait                 ; loop while no key
        ret

; ============================================================
; Map data - load testmaze.map into pages 40-45
; ============================================================
        MMU 6, MAP_PAGE
        MMU 7, MAP_PAGE + 1
        org $C000
        INCBIN "testmaze.map", 0, 16384

        MMU 6, MAP_PAGE + 2
        MMU 7, MAP_PAGE + 3
        org $C000
        INCBIN "testmaze.map", 16384, 16384

        MMU 6, MAP_PAGE + 4
        MMU 7, MAP_PAGE + 5
        org $C000
        INCBIN "testmaze.map", 32768, 16384

; ============================================================
; Reserve the three Layer 2 banks (pages 52-57) so they exist
; ============================================================
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

        SAVENEX OPEN "maptest.nex", progStart, $FF40
        SAVENEX AUTO
        SAVENEX CLOSE