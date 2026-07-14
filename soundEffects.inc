AYPortSelect   EQU $FF                     ; B value for AYSelect port ($FFFD)
AYPortWrite    EQU $BF                     ; B value for AYrw port ($BFFD)

        
MACRO AY_TONE argChannel
; write HL as a tone value to [previously] selected AY Chip (253/254/255)
; argChannel is A, B or C

        ; prepare B so that the next "OUT (C), A" instruction 
        ; will select the port/register that we want to write to
        LD B, AYPortSelect

        ; set A to the port register for the low byte tone value
        ; it's dependent on the AY chip Channel, i.e. A, B or C
        IF argChannel = 'A'
            ld a, 0
        ELSEIF argChannel = 'B'
            ld a, 2
        ELSEIF argChannel = 'C'
            ld a, 4
        ENDIF
        OUT (C), A

        ; AY chip ia now ready to accept the tone (low byte) value held in L
        ; so write it here
        LD B, AYPortWrite
        OUT (C), L

        ; prepare B so that the next "OUT (C), A" instruction 
        ; will select the port/register that we want to write to
        LD B, AYPortSelect

        ; set A to the port register for the high byte tone value
        ; it's dependent on the AY chip Channel, i.e. A, B or C
        ; since we've already set the low byte value, the register for the high byte is simply +1
        inc a
;        IF argChannel = 'A'
;            ld a, 1
;        ELSEIF argChannel = 'B'
;            ld a, 3
;        ELSEIF argChannel = 'C'
;            ld a, 5
;        ENDIF
        OUT (C), A

        ; AY chip ia now ready to accept the tone (high byte) value held in H
        ; so write it here
        LD B, AYPortWrite
        OUT (C), H
        ENDM


MACRO AY_VOLUME argChannel
; write A as a volume value to [previously] selected AY Chip (253/254/255)
; argChannel is A, B or C

        ; prepare B so that the next "OUT (C), A" instruction 
        ; will select the port/register that we want to write to
        LD B, AYPortSelect

        ; set H to the port register for the volume value
        ; it's dependent on the AY chip Channel, i.e. A, B or C
        IF argChannel = 'A'
            ld h, 8
        ELSEIF argChannel = 'B'
            ld h, 9
        ELSEIF argChannel = 'C'
            ld h, 10
        ENDIF
        OUT (C), H

        ; AY chip ia now ready to accept the VOLUME value held in A
        ; so write it here
        LD B, AYPortWrite
        OUT (C), A
        ENDM

playsound:
; Input : A = sound fx to play
;
; routine will rotate next available channel (even if still playing) and copy sound fx to that channel
; IM2 will then process that data
        PUSH HL
        PUSH DE
        PUSH BC

        ; source for the sound effect is: sound1 + (fx-1) * 10 (sound effect record length)
        DEC A                                       ; do the fx-1
        LD E, A
        ADD A, A                                    ; now * 2
        ADD A, A                                    ; * 4
        ADD A, E                                    ; * 5 (i.e. +n)
        ADD A, A                                    ; * 10
        LD HL, sound1                               ; point to base of data
        ADD HL, A                                   ; and add the offset to get to fx

        ; destination is: ch1 + nextCH * 10
        LD A, (nextCH)                              ; whats the nextCH to use
        ld e, a                                     ; save it (0, 1 or 2)
        add a, a                                    ; * 2
        add a, a                                    ; * 4
        add a, e                                    ; * 5 (i.e. +n)
        add a, a                                    ; * 10        
        ld de, Ch1                                  ; point to base of data
        add de, a                                   ; and add the offset to get Ch1, Ch2 or Ch3

        LD BC, 9                                    ; we copy first 9 bytes of sound setup
        LDIR                                        ; do the copy

        ; HL now points to mixer flag settings for this sound
        ; DE points to the equivalent CHn setting
        ld a, (hl)                                  ; point to mixer/flags for this sound (bit 0=tone on, bit 1=noise on)
        ld b, a                                     ; save in B
        ld hl, mixerRemap                           ; point to the mixer remap table
        ld a, (nextCH)                              ; get the available slot (0,1 or 2)
        add a, a                                    ; our table has 4 entries for each channel, so * 2
        add a, a                                    ; and * 2
        add a, b                                    ; add in our Ch(n) offset
        add hl, a                                   ; add total offset into table
        ld a, (hl)                                  ; get table value
        ld (de), a                                  ; put into slot

        ld a, (nextCH)                              ; ready to rotate for next fx
        inc a                                       ; point to next 
        cp 3                                        ; only channel values of 0, 1 or 2 are valid
        jr c, .store                                ; branch if ok 
        xor a                                       ; reset to 0 (wrap 3 -> 0)
.store
        ld (nextCH), a                              ; save it back
        
        POP BC
        POP DE
        POP HL
        RET

mixerRemap:                             ; active-high mixer bits per (channel, flags&3)
        db %00000000, %00000001, %00001000, %00001001   ; Ch1: tone->b0, noise->b3
        db %00000000, %00000010, %00010000, %00010010   ; Ch2: tone->b1, noise->b4
        db %00000000, %00000100, %00100000, %00100100   ; Ch3: tone->b2, noise->b5

sound1:
; initial tone period
; tone period delta
; initial volme (*256) allows really fine delta movement although most will be unheard (only 0-15 of the high byte is used in the AY chip)
; volume delta
; tone, noise, envelope flags. Mostly unused. bit 0 is tone enable, bit 1 is noise enable
; length in frames (50hz)

; hit head sound
        DW 500
        DW 10
        DW 15 * 256
        DW 20
        DB 5
        DB %00000001

; this is the pop sound
sound2:
        DW 100
        DW 10
        DW 15*256
        DW -20
        DB 10
        DB %0000001

; bounce sound
sound3:
        DW 252
        DW -10
        DW 15*256
        DW -100
soundDur:
        DB 15
        DB 1

sound4:
        DW 100
        DW -10
        DW 15*256
        DW -100
        DB 5
        DB 3

; item hit sound
sound5:
        DW 100
        DW -10
        DW 15*256
        DW 20
        DB 10
        DB %0000001

; kill skull sound
sound6:
        DW 500
        DW 10
        DW 15*256
        DW 20
        DB 100
        DB %00000011

nextCH:      DB 0

Ch1:
Ch1Pitch:    DW 0
Ch1PitchD:   DW 0
Ch1Volume    DW 00
Ch1VolumeD:  DW 00
Ch1Length    DB 0
Ch1Flags:    DB 0

Ch2:
Ch2Pitch:    DW 00
Ch2PitchD:   DW 00
Ch2Volume    DW 00
Ch2VolumeD:  DW 00
Ch2Length    DB 0
Ch2Flags:    DB 0

Ch3:
Ch3Pitch:    DW 00
Ch3PitchD:   DW 00
Ch3Volume    DW 00
Ch3VolumeD:  DW 00
Ch3Length    DB 0
Ch3Flags:    DB 0

AYSelect        EQU $FFFD
AYrw            EQU $bffd
AYPortC         EQU $FD                     ; Port low byte, stays in C
AYPortSelectB   EQU $FF                     ; B value for AYSelect port ($FFFD)
AYPortWriteB    EQU $BF                     ; B value for AYrw port ($BFFD)
channel1ToneL   equ 0
channel1ToneH   equ 1
channel2ToneL   equ 2
channel2ToneH   equ 3
channel3ToneL   equ 4
channel3ToneH   equ 5
channel1Volume  equ 8
channel2Volume  equ 9
channel3Volume  equ 10
mixerFlag       equ 7
frameCount   DB $01                         ; interrupt count for note set
framePointer DW frameTable                  ; pointer to the ic and note set
volume       DB %00001111                   ; volume


soundHithead   EQU 1
soundPop       EQU 2
soundBounce    EQU 3
soundHitskull  EQU 4
soundCollect   EQU 5
soundKillskull EQU 6
