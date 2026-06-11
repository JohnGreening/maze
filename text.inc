DEVICE ZXSPECTRUMNEXT

charset equ 15616
udgBase:    defb 0, 0, 0, 0, 255, 255, 0, 0
            defb 0, 0, 0, 0, 254, 254, 0, 0
            defb 0, 0, 0, 0, 252, 252, 0, 0
            defb 0, 0, 0, 0, 248, 248, 0, 0
            defb 0, 0, 0, 0, 240, 240, 0, 0
            defb 0, 0, 0, 0, 224, 224, 0, 0
            defb 0, 0, 0, 0, 192, 192, 0, 0
            defb 0, 0, 0, 0, 128, 128, 0, 0
            defb 0, 0, 0, 0,   0,   0, 0, 0

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

        call displayChar                            ; display char and advance column
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
; B = char row (0..23), C = char col (0..31), A = char (32..127)
; corrupts AF, DE, HL
        push bc                                     ; save the running Y/X screen positions
        push de                                     ; save DE in case of call from Bin8ToDec

        sla b                                       ; multiply Y by 8 to get pixel Y
        sla b
        sla b
        ld d, b                                     ; put Y in D for pixelad
        sla c                                       ; multiply X by 8 to get pixel X
        sla c
        sla c
        ld e, c                                     ; put X in D for pixelad
        pixelad                                     ; HL -> address of the cell's top pixel line

        cp 128
        jr nc, .udg

        sub 32                                      ; calc index into charset
        ld e, 8                                     ; each char is 8 bytes
        ld d, a                                     ; get index
        mul d, e                                    ; DE = index * 8
        add de, charset                             ; DE -> char bitmap (Z80N: ADD DE,nn)
        jr .draw

.udg
        sub 128
        ld e, 8
        ld d, a
        mul d, e
        add de, udgBase

.draw
        ld b, 8                                     ; 8 lines to a char
dcLine:
        ld a, (de)                                  ; get the bitmap row
        ld (hl), a                                  ; put it onto ULA
        inc de                                      ; next row
        inc h                                       ; down one pixel line within the cell
        djnz dcLine                                 ; loop for all 8 lines
        pop de
        pop bc
        inc c                                       ; advance to next column
        ld a, c                                     ; put A to clamp
        and 31                                      ; clamp at 31
        ld c, a                                     ; put back into C
        ret                

; 8-Bit Binary to Decimal Digits Extraction
; Input:  A  = 8-bit binary number (0 - 255)
;         B  = char row (0..23), C = char col (0..31)
; Calls displayChar with A to display each digit
Bin8ToDec:
; --- Step 1: Extract 100s Digit ---
        ld      e, '0' - 1                          ; Initialize ASCII counter
.Loop100:
        inc     e                                   ; Increment ASCII character
        sub     100                                 ; Subtract 100
        jr      nc, .Loop100                        ; Repeat if no underflow (result >= 0)
        add     a, 100                              ; Restore the remainder (add 100 back)

        ld      d, a                                ; Temporarily save remainder in B
        ld      a, e                                ; Get 100s digit
        call displayChar
        ld      a, d                                ; Restore remainder to A

; --- Step 2: Extract 10s Digit ---
        ld      e, '0' - 1                          ; Re-initialize ASCII counter
.Loop10:
        inc     e                                   ; Increment ASCII character
        sub     10                                  ; Subtract 10
        jr      nc, .Loop10                         ; Repeat if no underflow (result >= 0)
        add     a, 10                               ; Restore the remainder (add 10 back)

        ld      d, a                                ; Temporarily save 1s digit in B
        ld      a, e                                ; Get 10s digit
        call displayChar

; --- Step 3: Extract 1s Digit ---
        ld      a, d                                ; Restore 1s digit to A
DisplayDigit:
        ; if calling from here then BC must be set with B=row, C=Column
        add     a, '0'                              ; Convert the leftover 1s digit to ASCII
        call displayChar
        ret


debugs:
        ; get distance
        call getTileY
        ld bc, 10
        call Bin8ToDec

        call getTileX
        ld bc, 14
        call Bin8ToDec

        call getTileY        
        ld d, a

        call getTileX
        ld e, a

        ex de, hl
        call getFieldByte
        ld bc, 18
        call Bin8ToDec
        ret

getTileY
        ld hl, (player_py)
        DIV_HL_8
        ld a, l
        ret

getTileX
        ld hl, (player_px)
        DIV_HL_8
        ld a, l
        ret

debugs1:
        