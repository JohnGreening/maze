
DEVICE ZXSPECTRUMNEXT

ORG $6000

; Tilemap definition
; defines what tiles go where in the 40x32 grid
; currently 1 byte tilemap mode only
tileMap:
DEFS 1280, 0

TilePatterns:
; Tile000
DB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
DB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
; Tile001
DB $00,$00,$01,$00,$00,$00,$01,$00,$11,$11,$11,$11,$00,$10,$00,$00
DB $00,$10,$00,$00,$11,$11,$11,$11,$00,$00,$01,$00,$00,$00,$01,$00

SpritePatterns:
; Sprite000
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$00,$00
DB $00,$E3,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$00,$E3,$00,$00,$E3,$E3,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$00,$E3,$E3,$00
DB $00,$E3,$E3,$E3,$00,$E3,$E3,$E3,$E3,$E3,$E3,$00,$E3,$E3,$E3,$00,$00,$E3,$E3,$E3,$E3,$00,$E3,$E3,$E3,$E3,$00,$E3,$E3,$E3,$E3,$00
DB $00,$E3,$E3,$E3,$E3,$E3,$00,$E3,$E3,$00,$E3,$E3,$E3,$E3,$E3,$00,$00,$E3,$E3,$E3,$E3,$E3,$E3,$00,$00,$E3,$E3,$E3,$E3,$E3,$E3,$00
DB $00,$E3,$E3,$E3,$E3,$E3,$E3,$00,$00,$E3,$E3,$E3,$E3,$E3,$E3,$00,$00,$E3,$E3,$E3,$E3,$E3,$00,$E3,$E3,$00,$E3,$E3,$E3,$E3,$E3,$00
DB $00,$E3,$E3,$E3,$E3,$00,$E3,$E3,$E3,$E3,$00,$E3,$E3,$E3,$E3,$00,$00,$E3,$E3,$E3,$00,$E3,$E3,$E3,$E3,$E3,$E3,$00,$E3,$E3,$E3,$00
DB $00,$E3,$E3,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$00,$E3,$E3,$00,$00,$E3,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$00,$E3,$00
DB $00,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; Sprite001
DB $E3,$E3,$E3,$E3,$0A,$0A,$0A,$0A,$0B,$0B,$0B,$0B,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$0A,$E3,$E3,$E3,$E3,$0A,$0A,$0A,$0A,$0B,$E3,$E3,$E3
DB $E3,$E3,$0A,$E3,$0A,$0A,$0A,$0A,$E3,$0A,$0A,$0A,$0A,$0A,$E3,$E3,$E3,$E3,$0A,$E3,$0B,$E3,$0B,$0A,$0A,$0B,$E3,$0B,$0A,$0A,$E3,$E3
DB $E3,$E3,$0A,$0A,$0B,$E3,$E3,$0B,$0B,$E3,$E3,$0B,$0A,$0A,$E3,$E3,$E3,$E3,$0A,$0B,$E3,$E3,$E3,$0B,$0B,$E3,$E3,$E3,$0B,$0A,$E3,$E3
DB $E3,$E3,$0A,$0A,$0B,$E3,$E3,$0B,$0A,$0B,$E3,$E3,$0B,$0A,$E3,$E3,$E3,$E3,$0A,$0A,$0A,$0B,$0B,$0A,$0A,$0A,$0B,$0B,$0B,$0A,$E3,$E3
DB $E3,$E3,$E3,$0A,$0A,$0A,$0A,$E3,$E3,$0A,$0A,$0A,$0A,$E3,$E3,$E3,$0A,$0A,$E3,$E3,$E3,$0A,$0A,$0A,$0A,$0A,$0A,$E3,$E3,$E3,$0A,$0A
DB $E3,$0B,$0A,$E3,$E3,$0B,$E3,$0A,$0B,$E3,$0B,$E3,$E3,$0A,$0B,$E3,$E3,$E3,$0A,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$0A,$E3,$E3
DB $E3,$E3,$E3,$E3,$0A,$E3,$0A,$E3,$E3,$0A,$E3,$0A,$E3,$E3,$E3,$E3,$0A,$0A,$0B,$E3,$0A,$0B,$0A,$0B,$0A,$0A,$0B,$0A,$E3,$0B,$0A,$0A
DB $E3,$0B,$0A,$E3,$E3,$E3,$0B,$0B,$0B,$0B,$E3,$E3,$E3,$0A,$0B,$E3,$E3,$E3,$0A,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$0A,$E3,$E3
; Sprite002
DB $00,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$00,$00,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
; Sprite003
DB $0B,$0B,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$0B,$0B,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
DB $E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3,$E3
endofSprites:



TilePalette0:
DB $E0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $0B,$01,$FF,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$E3,$01
TilePalette0Len EQU ($ - TilePalette0) / 2



SpritePalette0:
DB $03,$01,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$10,$00,$1C,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
DB $00,$00,$00,$00,$00,$00,$E3,$01
SpritePalette0Len EQU ($ - SpritePalette0) / 2


; *****************************************
; call to initialise the graphics
; *****************************************
spriteSetup:

; Configure tilemap control
    NEXTREG $6b, %10100001
; bit 7 1= enable tilemap
; bit 6 1= 80x32, 0=40x32
; bit 5 1= use 6c for attributes (i.e. 1 byte tilemap mode)
; bit 4 1= 2nd tilemap palette, 0= first
; bit 3 1= activate text mode
; bit 2 reserved, set to 0
; bit 1 1=512, 0=256 tilemap mode
; bit 0 1= force tilemap ontop of ULA

; Default tilemap attribute for 8bit maps
; i.e. when using 1 byte tilemap mode
; NB limits colours to 0-15
    NEXTREG $6c, $0
; bit 7-4 Palette offset
; bit 3 1=mirror in X direction
; bit 2 1=mirror in Y direction
; bit 1 1=rotate 90deg clockwise
; bit 0 1=ula overtilemap, 0=tilemap over ULA
 
; ULA control
    NEXTREG $68, $0
; bit 7 1=disable ULA output
; bit 6 concerned with blending in SLU modes 6/7
;       1=select ULA/tilemap mix
;       0=select ULA colour
; bits 5-1 reserved, always 0
; bit 0 1=enable stencil mode when ULA & tilemap enabled
 
; point to the tilemap and tile pattern data
    NEXTREG $6e, tileMap / 256
    NEXTREG $6f, TilePatterns / 256
 
; Palette Control
; set values for Tilemap palette 0
    NEXTREG $43, %00110000
; bit 7 1=disable palette auto inc
; bit 6-4 select palette for r/w
; 000 = ULA palette 1
; 100 = ULA palette 2
; 001 = Layer 2 palette 1
; 101 = Layer 2 palette 2
; 010 = Sprites palette 1
; 110 = Sprites palette 2
; 011 = Tilemap palette 1
; 111 = Tilemap palette 2
; bit 3
; bit 2
; bit 1
; bit 0

; set index of transparent colour in the tile palette
  NEXTREG $4C, 015
 
 
; load the colours into the palette memory
; here we are using 9 bit colours, so use $44 to do the load

; first initialise the palette index to 0
    NEXTREG $40, 0

; set the number of colours 
; set location of Tilemap palette data
    LD BC, TilePalette0Len
    LD HL, TilePalette0

; write palette data, 2 bytes per colour
tilemapPalette0Loop:
    LD A, (HL)
    INC HL
    NEXTREG $44, A
    LD A, (HL)
    INC HL
    NEXTREG $44, A
    DEC BC
    LD A, B
    OR C
    JR NZ, tilemapPalette0Loop
 
; Configure Sprite and Layers System
; NEXTREG $15, %00000011
    ;NEXTREG $15, %00010111
; bit 7 1=enable lo-res 
; bit 6 1=flip sprite rendering priority
; bit 5 1=change clipping over border mode
; bit 4-2 000=sprites on top, layer 2 under
; bit 1 1=enable sprites over border
; bit 0 1=enable sprite visibility
 
    LD BC, $303b                 ; set port for Sprites
    SUB A, A                     ; Set sprite index to 0
    OUT (C), A                   ; write to port

    LD HL, SpritePatterns; point to sprite patterns
    LD BC, $5b                    ; set port to write patterns to
    LD DE, endofSprites - SpritePatterns

spritePatternLoop:
    LD A, (HL)                    ; get each byte of pattern data
    INC HL                        ; ready for next read
    OUT (C), A                    ; upload to sprite memory
    DEC DE                        ; dec loop count
    LD A, E                       ; test for 0
    OR A, D
    JR NZ, spritePatternLoop      ; loop if more data

; Palette Control
; set values for Sprites palette 1
    NEXTREG $43, %00100000
; bit 7 1=disable palette auto inc
; bit 6-4 select palette for r/w
; 000 = ULA palette 1
; 100 = ULA palette 2
; 001 = Layer 2 palette 1
; 101 = Layer 2 palette 2
; 010 = Sprites palette 1
; 110 = Sprites palette 2
; 011 = Tilemap palette 1
; 111 = Tilemap palette 2
; bit 3
; bit 2
; bit 1
; bit 0

TRANSPARENT_SPRITE_SLOT

; set global transparency fallback
    NEXTREG $14, 0

; load the colours into the palette memory
; here we are using 9 bit colours, so use $44 to do the load

; first initialise the palette index to 0
    NEXTREG $40, 0

; set the number of colours 
; set location of sprite palette data
    LD BC, SpritePalette0Len
    LD HL, SpritePalette0

    ; write palette data, 2 bytes per colour
spritePalette0Loop:
    LD A, (HL)
    INC HL
    NEXTREG $44, A
    LD A, (HL)
    INC HL
    NEXTREG $44, A
    DEC BC
    LD A, B
    OR C
    JR NZ, spritePalette0Loop
 
    RET
