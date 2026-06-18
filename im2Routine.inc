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
;        ld a, (paletteFlip)
;        xor 1
;        ld (paletteFlip), a
;        swapnib
;        nextreg $6c, a

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
        LD B, AYPortSelectB             ; AYSelect
        LD A, channel1ToneL
        OUT (C), A
        LD B, AYPortWriteB              ; AYrw
        OUT (C), L

        LD B, AYPortSelectB
        LD A, channel1ToneH
        OUT (C), A
        LD B, AYPortWriteB
        OUT (C), H

; get the Ch1 volume value
; apply delta
        LD HL, (Ch1Volume)
        LD DE, (Ch1VolumeD)
        ADD HL, DE
        LD (Ch1Volume), HL

        LD A, H
        AND 15

; write Ch1 volume to AY chip
        LD B, AYPortSelectB
        LD H, channel1Volume
        OUT (C), H
        LD B, AYPortWriteB
        OUT (C), A

; get the Ch2 tone value
; apply delta
        LD HL, (Ch2Pitch)
        LD DE, (Ch2PitchD)
        ADD HL, DE
        LD (Ch2Pitch), HL

; write Ch2 tone to AY chip
        LD B, AYPortSelectB
        LD A, channel2ToneL
        OUT (C), A
        LD B, AYPortWriteB
        OUT (C), L

        LD B, AYPortSelectB
        LD A, channel2ToneH
        OUT (C), A
        LD B, AYPortWriteB
        OUT (C), H

; get the Ch2 volume value
; apply delta
        LD HL, (Ch2Volume)
        LD DE, (Ch2VolumeD)
        ADD HL, DE
        LD (Ch2Volume), HL

        LD A, H
        AND 15

; write Ch2 volume to AY chip
        LD B, AYPortSelectB
        LD H, channel2Volume
        OUT (C), H
        LD B, AYPortWriteB
        OUT (C), A

; get the Ch3 tone value
; apply delta
        LD HL, (Ch3Pitch)
        LD DE, (Ch3PitchD)
        ADD HL, DE
        LD (Ch3Pitch), HL

; write Ch3 tone to AY chip
        LD B, AYPortSelectB
        LD A, channel3ToneL
        OUT (C), A
        LD B, AYPortWriteB
        OUT (C), L

        LD B, AYPortSelectB
        LD A, channel3ToneH
        OUT (C), A
        LD B, AYPortWriteB
        OUT (C), H

; get the Ch3 volume value
; apply delta
        LD HL, (Ch3Volume)
        LD DE, (Ch3VolumeD)
        ADD HL, DE
        LD (Ch3Volume), HL

        LD A, H
        AND 15

; write Ch3 volume to AY chip
        LD B, AYPortSelectB
        LD H, channel3Volume
        OUT (C), H
        LD B, AYPortWriteB
        OUT (C), A

; set the AY mixer value depending on ch1Flags, ch2Flags & ch3Flags
; these control the tone and noise flags in main AY mixer setting
; mapping is as follows and we negate the Ch1/2/3Flag setting
; Ch1Flags
; bit
; 0 -> 0
; 1 -> 3
; Ch2Flags
; 0 -> 1
; 1 -> 4
; Ch3Flags
; 0 -> 2
; 1 -> 5
        LD C, 255                               ; initialise to all 1's, everything off
        LD HL, mixerFlags                       ; point to mapping data for Ch1Flags
        LD A, (Ch1Flags)                        ; get Ch1Flags setting
        AND %00000011                           ; we're only interested in bits 0,1
        ADD HL, A                               ; offset into mixerFlags mapping
        LD A, (HL)                              ; get value
        AND C                                   ; AND with existing
        LD C, A                                 ; store back

        LD HL, mixerFlags +4
        LD A, (Ch2Flags)
        AND %00000011
        ADD HL, A
        LD A, (HL)
        AND C
        LD C, A
        LD HL, mixerFlags +8
        LD A, (Ch3Flags)
        AND %00000011
        ADD HL, A
        LD A, (HL)
        AND C
        LD BC, AYSelect
        LD D, mixerFlag
        OUT (C), D
        LD BC, AYrw
        OUT (C), A
        
        LD A, (Ch1Length)
        DEC A
        JR NZ, ch1endskip
        LD (Ch1Flags), A
        LD HL, 0
        LD (Ch1Volume), HL
        LD (Ch1VolumeD), HL
ch1endskip
        LD (Ch1Length), A

        LD A, (Ch2Length)
        DEC A
        JR NZ, ch2endskip
        LD (Ch2Flags), A
        LD HL, 0
        LD (Ch2Volume), HL
        LD (Ch2VolumeD), HL
ch2endskip
        LD (Ch2Length), A

        LD A, (Ch3Length)
        DEC A
        JR NZ, ch3endskip
        LD (Ch3Flags), A
        LD HL, 0
        LD (Ch3Volume), HL
        LD (Ch3VolumeD), HL
ch3endskip
        LD (Ch3Length), A


melodyRoutine
        LD A, (frameCount)                  ; pick up remaining note time
        DEC A                               ; decrease by 1 frame
        LD (frameCount), A                  ; save it back
        JP NZ, melodyEnd                    ; branch to end if not zero

        ; timer expired, so pick up next note to play
        ; - first set timer for this new note
mr0
        LD HL, (framePointer)               ; framePointer = timer table
        LD A, (HL)                          ; get note length

        INC HL                              ; skip past high byte
        CP 255                              ; is it 255 marker
        JR NZ, mr1                          ; branch if not

        LD HL, frameTable                   ; point to table start
        LD (framePointer), HL               ; save in framePointer
        JR mr0                              ; and test again !
mr1
        LD (frameCount), A                  ; save note length

        ; - point to the note, save in DE and update
        ;   framePointer for next time
        INC HL                              ; point to note data
        LD E, (HL)                          ; get low byte
        INC HL                              ; point to high byte
        LD D, (HL)                          ; get the high byte
        INC HL                              ; point to next timer entry
        LD (framePointer), HL               ; and save in framePointer

playNotes
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
        INC DE
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

melodyEnd
