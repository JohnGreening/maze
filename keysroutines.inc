DEVICE ZXSPECTRUMNEXT

KEY_AVAILABLE       EQU 1
KEY_COLLECTED       EQU 0
KEY_COUNT           EQU 4
KEY_DATA            defs 3 * KEY_COUNT              ; [tile X, tile Y, status ] * KEY_COUNT

;===========================================================
; display "Keys: n/x"
;===========================================================
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

;===========================================================
; this routine called when a key is collected
; it removes the key from the maze map
; clears and repopulates the distance map
; updates the playerKeys and shows current status
;===========================================================
collectKey:
        ld hl, KEY_DATA                             ; point to the key data
        ld b, a                                     ; save key index, 0, 1, 2 or 3
        add a, a                                    ; we want a*3, eg if 2 => 4
        add a, b                                    ; add on the original index, e.g. 2 => 6
        add hl, a                                   ; now we point to this keys data
        ld d, (hl)                                  ; get the tile x
        inc hl                                      
        ld e, (hl)                                  ; get the tile y
        inc hl
        ld (hl), KEY_COLLECTED                      ; set the key as collected
        ld l, d
        ld h, e
        ld a, MAP_PATH
        call putMapByte                             ; key at tile x, y

        ld l, d
        ld h, e
        inc l
        ld a, MAP_PATH
        call putMapByte                             ; key at tile x+1, y

        ld l, d
        ld h, e
        inc h
        ld a, MAP_PATH
        call putMapByte                             ; key at tile x, y+1

        ld l, d
        ld h, e
        inc l
        inc h
        ld a, MAP_PATH
        call putMapByte                             ; key at tile x+1, y+1

        ld a, soundCollect
        call playsound

        CALL rebuildMaps
        ld a, (playerKeys)
        inc a
        ld (playerKeys), a
        call showKeys
        ret

;===========================================================
; this routine callled when a key is collected
; for each key still in play it
;     calculates the distance field
;     rebuilds the radar layer 2 map
;===========================================================
rebuildMaps:
        ;=======================================================
        ; build the maps for a new game or when key is collected
        ;=======================================================
        SPEED 3
        ld a, 1                                     ; indicator for interupt handler
        ld (floodInProgress), a                     ; set it

        call clearFloodField                        ; clear any flood fill

        ld b, 0
.keyFlood:
        push bc
        ; compute KEY_DATA + b*3 fresh each time (floodFill trashes HL)
        ld hl, KEY_DATA
        ld a, b
        add a, a
        add a, b                        ; A = b*3
        add hl, a                       ; HL -> this key's record
        ld d, (hl)                      ; tileX
        inc hl
        ld e, (hl)                      ; tileY
        inc hl
        ld a, (hl)                      ; status
        cp KEY_AVAILABLE
        jr nz, .nextKey
        ld a, d
        ld (floodTargetX), a
        ld a, e
        ld (floodTargetY), a
        call floodFill                  ; trashes HL - but we recompute it next iter
.nextKey:        
        pop bc

        inc b
        ld a, b
        cp KEY_COUNT
        jr nz, .keyFlood

        call buildMapImage                          ; render maze into Layer 2

        LD A, 0                                     ; reset value
        ld (floodInProgress), a                     ; indicator for interupt handler
        nextreg $6c, a                              ; tilemap palette offset 0
        SPEED 0
        ret

;===========================================================
; this routine called as part of a new game
; it randomly adds each key into the maze map
;===========================================================
addKey:
        ld b, 0
.nextKey:
        push bc
.tryPos:
        ; random tile X 0..254
.rx:    call rnd8
        cp 255
        jr z, .rx                                   ; reject 255 (no room for tx+1)
        ld d, a                                     ; D = candidate tileX

        ; random tile Y 0..190
.ry:    call rnd8
        cp 8
        jr c, .ry
        cp 191
        jr nc, .ry                                  ; reject 191..255 (need ty in 0..190)
        ld e, a                                     ; E = candidate tileY

.loop
        ; --- test all four tiles of the 2x2 footprint are open ---
        ld b, d
        ld c, e
        GET_WORLD_VALUE TILEMAP_PAGE, USE_BC        ; (tx, ty)
        and a
        jr nz, .tryPos                              ; wall -> reject, draw again

        ld b, d
        ld c, e
        inc b
        GET_WORLD_VALUE TILEMAP_PAGE, USE_BC        ; (tx+1, ty)
        and a
        jr nz, .tryPos

        ld b, d
        ld c, e        
        inc c
        GET_WORLD_VALUE TILEMAP_PAGE, USE_BC        ; (tx, ty+1)
        and a
        jr nz, .tryPos

        ld b, d
        inc b
        ld c, e
        inc c
        GET_WORLD_VALUE TILEMAP_PAGE, USE_BC        ; (tx+1, ty+1)
        and a
        jp nz, .tryPos

        ; --- position is valid: D=tileX, E=tileY

        ; --- after the 4 wall-checks pass, before placing the key ensure no flood fill here.
        ld b, d
        ld c, e
        GET_WORLD_VALUE DFIELD_PAGE, USE_BC         ; A = field distance at candidate
        cp 255                                      ; 255 = unflooded
        jp nz, .tryPos                              ; already flooded -> re-pick

        ld l, d
        ld h, e
        ld a, MAP_KEYTL
        call putMapByte                             ; key at tile x, y

        ld l, d
        ld h, e
        inc l
        ld a, MAP_KEYTR
        call putMapByte                             ; key at tile x+1, y

        ld l, d
        ld h, e
        inc h
        ld a, MAP_KEYBL
        call putMapByte                             ; key at tile x, y+1

        ld l, d
        ld h, e
        inc l
        inc h
        ld a, MAP_KEYBR
        call putMapByte                             ; key at tile x+1, y+1
        
        push de
        ld a, d
        ld (floodTargetX), a
        ld a, e
        ld (floodTargetY), a
        call floodFill
        pop de

        pop bc
        ld hl, KEY_DATA
        ld a, b
        add a, a
        add a, b
        add hl, a
        ld (hl), d
        inc hl
        ld (hl), e
        inc hl
        ld (hl), KEY_AVAILABLE

        inc b
        ld a, b
        cp KEY_COUNT
        jp nz, .nextKey
        ret

