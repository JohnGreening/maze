; this is the IM2 routine
; gets called every 1/50 second, i.e. 20ms
; push/pop are in main program


        ld a, (floodInProgress)
        and a
        jr z, noFlood
        ld a, (paletteDelay)
        inc a
        and 7
        ld (paletteDelay), a
        jr nz, noFlood
        ld a, (paletteFlip)
        xor 1
        ld (paletteFlip), a
        swapnib
        nextreg $6c, a

noFlood:
        LD C, AYPortC              ; shared port for AY chip access

; select AY1
        LD B, AYPortSelectB              ; AYSelect
        LD A, 255
        OUT (C), A

; get the Ch1 tone value
; apply delta
        LD HL, (Ch1Pitch)
        LD DE, (Ch1PitchD)
        ADD HL, DE
        LD (Ch1Pitch), HL

; write Ch1 tone to AY chip
        AY_TONE 'A'

; get the Ch1 volume value
; apply delta
        LD HL, (Ch1Volume)
        LD DE, (Ch1VolumeD)
        ADD HL, DE
        LD (Ch1Volume), HL

        LD A, H
        AND 15

; write Ch1 volume to AY chip
        AY_VOLUME 'A'

; get the Ch2 tone value
; apply delta
        LD HL, (Ch2Pitch)
        LD DE, (Ch2PitchD)
        ADD HL, DE
        LD (Ch2Pitch), HL

; write Ch2 tone to AY chip
        AY_TONE 'B'

; get the Ch2 volume value
; apply delta
        LD HL, (Ch2Volume)
        LD DE, (Ch2VolumeD)
        ADD HL, DE
        LD (Ch2Volume), HL

        LD A, H
        AND 15

; write Ch2 volume to AY chip
        AY_VOLUME 'B'

; get the Ch3 tone value
; apply delta
        LD HL, (Ch3Pitch)
        LD DE, (Ch3PitchD)
        ADD HL, DE
        LD (Ch3Pitch), HL

; write Ch3 tone to AY chip
        AY_TONE 'C'

; get the Ch3 volume value
; apply delta
        LD HL, (Ch3Volume)
        LD DE, (Ch3VolumeD)
        ADD HL, DE
        LD (Ch3Volume), HL

        LD A, H
        AND 15

; write Ch3 volume to AY chip
        AY_VOLUME 'C'


; ---- AY mixer (reg 7): 0 = enabled. tone A/B/C = bits 0-2, noise A/B/C = bits 3-5 ----
; ChNFlags: bit0 = tone-on, bit1 = noise-on.
; Gather each channel's tone bit into E and noise bit into D, then place & invert.
; --- AY1 mixer: OR the three channels' pre-positioned flag bits, then invert ---
        ld a, (Ch1Flags)
        ld b, a
        ld a, (Ch2Flags)
        or b
        ld b, a
        ld a, (Ch3Flags)
        or b
        cpl                         ; 0 = enable; bits 6,7 -> 1 (I/O input)
        ld bc, AYSelect
        ld d, mixerFlag
        out (c), d
        ld bc, AYrw
        out (c), a

ch1Update:
        ld hl, Ch1Length                            ; get the Ch1 sound length
        dec (hl)                                    ; -1 (will roll to 255)
        jr nz, ch2Update                            ; branch if it's not zero
        inc hl                                      ; point to Ch1 flags
        ld (hl), 0                                  ; set to 0 to disable sound for this channel
ch2Update:
        ld hl, Ch2Length
        dec (hl)
        jr nz, ch3Update
        inc hl
        ld (hl), 0
ch3Update:
        ld hl, Ch3Length
        dec (hl)
        jr nz, chFinished
        inc hl
        ld (hl), 0
chFinished:


melodyRoutine:
        LD A, (frameCount)                  ; pick up remaining note time
        DEC A                               ; decrease by 1 frame
        LD (frameCount), A                  ; save it back
        JP NZ, melodyEnd                    ; branch to end if not zero

        ; timer expired, so pick up next note to play
        ; - first set timer for this new note
mr0:
        LD DE, (framePointer)               ; framePointer = timer table
        LD A, (DE)                          ; get note length

        INC DE                              ; skip past high byte
        CP 255                              ; is it 255 marker
        JR NZ, mr1                          ; branch if not

        LD DE, frameTable                   ; point to table start
        LD (framePointer), DE               ; save in framePointer
        JR mr0                              ; and test again !
mr1:
        LD (frameCount), A                  ; save note length

        ; - point to the note, save in HL and update
        ;   framePointer for next time
        INC DE                              ; point to note data
        LD A, (DE)                          ; get low byte
        LD L, A
        INC DE                              ; point to high byte
        LD A, (DE)                          ; get the high byte
        LD H, A
        INC DE                              ; point to next timer entry
        LD (framePointer), DE               ; and save in framePointer
        EX DE, HL
playNotes:
        ld c, AYPortC

        ; -------------------- AY2 --------------------
        LD A, 254
        LD B, AYPortSelectB
        OUT (C), A

        ; Tone A
        XOR A
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        LD A, 1
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        ; Volume A
        LD A, 8
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        ; set A = %00000001 for mixer if A > 0, otherwise %00000000, save in H for later
        sub 1
        sbc a, a
        inc a
        ld h, a

        ; Tone B
        LD A, 2
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        LD A, 3
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        ; Volume B
        LD A, 9
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        ; set A = %00000010 for mixer if A > 0, otherwise %00000000, OR with previous value
        sub 1
        sbc a, a
        inc a
        rla
        or h
        ld h, a

        ; Tone C
        LD A, 4
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        LD A, 5
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        ; Volume C
        LD A, 10
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        ; set A = %00000100 for mixer if A > 0, otherwise %00000000, OR with previous value
        sub 1
        sbc a, a
        inc a
        rla
        rla
        or h
        ld h, a

        ; Mixer
        LD A, 7
        LD B, AYPortSelectB
        OUT (C), A
        LD A, H
        XOR %11111111
        LD B, AYPortWriteB
        OUT (C), A

        ; -------------------- AY3 --------------------
        LD A, 253
        LD B, AYPortSelectB
        OUT (C), A

        ; Tone A
        XOR A
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        LD A, 1
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        ; Volume A
        LD A, 8
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        AND %00000001
        LD H, A
        LD A, (volume)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        ; Tone B
        LD A, 2
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        LD A, 3
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        ; Volume B
        LD A, 9
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        AND %00000010
        OR H
        LD H, A
        LD A, (volume)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        ; Tone C
        LD A, 4
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        LD A, 5
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        INC DE
        LD B, AYPortWriteB
        OUT (C), A

        ; Volume C
        LD A, 10
        LD B, AYPortSelectB
        OUT (C), A
        LD A, (DE)
        AND %00000100
        OR H
        LD H, A
        LD A, (volume)
        LD B, AYPortWriteB
        OUT (C), A

        ; Mixer
        LD A, 7
        LD B, AYPortSelectB
        OUT (C), A
        LD A, H
        XOR %11111111
        LD B, AYPortWriteB
        OUT (C), A

melodyEnd:
