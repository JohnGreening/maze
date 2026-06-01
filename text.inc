DEVICE ZXSPECTRUMNEXT

charset equ 15616


displayText:
; IY = text string, terminate with $FF, set AT with 22, Y, X
; corrupts IY, AF, BC
        ld bc, 0                                    ; set B (y) = 0 and C (x) = 0
.loop
        ld a, (IY +0)                               ; get control or char to display
        cp $ff                                      ; end of string
        ret z                                       ; return if so        
        cp 22                                       ; AT control
        jr z, .at                                   ; branch if so
        call displayChar                            ; display char
        inc c                                       ; next column        
        inc iy                                      ; point to next in string
        jr .loop                                    ; and loop
.at
        inc iy                                      ; point to YX parameters
        ld b, (iy +0)                               ; store Y
        inc iy                                      ; point to next in string
        ld c, (iy +0)                               ; store X
        inc iy                                      ; point to next in string
        jr .loop                                    ; loop

displayChar:
; D = char row (0..23), E = char col (0..31), A = char (32..127)
; corrupts AF, DE, HL
        push bc                                     ; save the running Y/X screen positions
        sla b                                       ; multiply Y by 8 to get pixel Y
        sla b
        sla b
        ld d, b                                     ; put Y in D for pixelad
        sla c                                       ; multiply X by 8 to get pixel X
        sla c
        sla c
        ld e, c                                     ; put X in D for pixelad
        pixelad                                     ; HL -> address of the cell's top pixel line

        sub 32                                      ; calc index into charset
        ld e, 8                                     ; each char is 8 bytes
        ld d, a                                     ; get index
        mul d, e                                    ; DE = index * 8
        add de, charset                             ; DE -> char bitmap (Z80N: ADD DE,nn)

        ld b, 8                                     ; 8 lines to a char
dcLine:
        ld a, (de)                                  ; get the bitmap row
        ld (hl), a                                  ; put it onto ULA
        inc de                                      ; next row
        inc h                                       ; down one pixel line within the cell
        djnz dcLine                                 ; loop for all 8 lines
        pop bc
        ret                

