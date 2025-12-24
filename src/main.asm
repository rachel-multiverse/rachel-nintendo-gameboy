; =============================================================================
; NINTENDO GAME BOY RACHEL CLIENT
; Main entry point
; =============================================================================

INCLUDE "hardware.inc"

; =============================================================================
; ROM Header
; =============================================================================
SECTION "Header", ROM0[$100]
    nop
    jp Start

; Nintendo logo (required for boot)
    DB $CE,$ED,$66,$66,$CC,$0D,$00,$0B,$03,$73,$00,$83,$00,$0C,$00,$0D
    DB $00,$08,$11,$1F,$88,$89,$00,$0E,$DC,$CC,$6E,$E6,$DD,$DD,$D9,$99
    DB $BB,$BB,$67,$63,$6E,$0E,$EC,$CC,$DD,$DC,$99,$9F,$BB,$B9,$33,$3E

; Title (11 chars)
    DB "RACHEL",0,0,0,0,0

; Manufacturer code
    DB 0,0,0,0

; CGB flag
    DB 0

; New licensee code
    DB 0,0

; SGB flag
    DB 0

; Cartridge type (ROM only)
    DB 0

; ROM size (32KB)
    DB 0

; RAM size (none)
    DB 0

; Destination (non-Japanese)
    DB 1

; Old licensee code
    DB $33

; Version
    DB 0

; Header checksum (filled by rgbfix)
    DB 0

; Global checksum (filled by rgbfix)
    DW 0

; =============================================================================
; Entry Point
; =============================================================================
SECTION "Main", ROM0[$150]

Start:
    di
    ld sp, $FFFE

    ; Wait for VBlank
    call WaitVBlank

    ; Turn off LCD
    xor a
    ld [rLCDC], a

    ; Initialize
    call InitDisplay
    call LoadFont
    call ClearScreen
    call RubpInit
    call NetInit

    ; Show title
    call ShowTitle

    ; Enable LCD
    ld a, LCDC_ON | LCDC_BG_ON
    ld [rLCDC], a

    ; Set palette
    ld a, %11100100         ; 3=black, 2=dark, 1=light, 0=white
    ld [rBGP], a

    ; Initial state
    ld a, STATE_TITLE
    ld [wGameState], a

    ; Enable interrupts
    ld a, %00000001         ; VBlank only
    ld [rIE], a
    ei

MainLoop:
    call WaitVBlank
    call ReadJoypad

    ld a, [wGameState]
    cp STATE_TITLE
    jr z, .doTitle
    cp STATE_CONNECT
    jr z, .doConnect
    cp STATE_GAME
    jr z, .doGame
    jr MainLoop

.doTitle:
    call HandleTitle
    jr MainLoop

.doConnect:
    call DoConnect
    jr MainLoop

.doGame:
    call ProcessGame
    jr MainLoop

; =============================================================================
; Wait for VBlank
; =============================================================================
WaitVBlank:
    ld a, [rLY]
    cp 144
    jr c, WaitVBlank
    ret

; =============================================================================
; Initialize display
; =============================================================================
InitDisplay:
    ; Clear VRAM
    ld hl, $8000
    ld bc, $2000
    xor a
.clearLoop:
    ld [hl+], a
    dec bc
    ld a, b
    or c
    jr nz, .clearLoop
    ret

; =============================================================================
; Load font tiles
; =============================================================================
LoadFont:
    ld hl, FontData
    ld de, VRAM_TILES_1     ; $8800, tiles 128-255 (signed addressing)
    ld bc, FontDataEnd - FontData
.copyLoop:
    ld a, [hl+]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .copyLoop
    ret

; =============================================================================
; Clear screen
; =============================================================================
ClearScreen:
    ld hl, VRAM_MAP_0
    ld bc, 32*32
    ld a, $80               ; Empty tile
.clearLoop:
    ld [hl+], a
    dec bc
    ld a, b
    or c
    ld a, $80
    jr nz, .clearLoop
    ret

; =============================================================================
; Set cursor position (B=X, C=Y)
; =============================================================================
SetCursor:
    ld a, b
    ld [wCursorX], a
    ld a, c
    ld [wCursorY], a
    ret

; =============================================================================
; Print string (HL = string address, null-terminated)
; =============================================================================
PrintString:
    push hl
    ; Calculate VRAM address: $9800 + Y*32 + X
    ld a, [wCursorY]
    ld h, 0
    ld l, a
    add hl, hl              ; *2
    add hl, hl              ; *4
    add hl, hl              ; *8
    add hl, hl              ; *16
    add hl, hl              ; *32
    ld a, [wCursorX]
    add l
    ld l, a
    ld bc, VRAM_MAP_0
    add hl, bc
    ld d, h
    ld e, l
    pop hl

.printLoop:
    ld a, [hl+]
    or a
    ret z
    ld [de], a
    inc de
    jr .printLoop

; =============================================================================
; Print character (A = char)
; =============================================================================
PrintChar:
    push hl
    push af
    ; Calculate VRAM address
    ld a, [wCursorY]
    ld h, 0
    ld l, a
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld a, [wCursorX]
    add l
    ld l, a
    ld bc, VRAM_MAP_0
    add hl, bc
    pop af
    ld [hl], a
    ; Advance cursor
    ld a, [wCursorX]
    inc a
    ld [wCursorX], a
    pop hl
    ret

; =============================================================================
; Show title screen
; =============================================================================
ShowTitle:
    call ClearScreen
    ld b, 4
    ld c, 7
    call SetCursor
    ld hl, MsgTitle
    call PrintString

    ld b, 2
    ld c, 12
    call SetCursor
    ld hl, MsgPressStart
    call PrintString
    ret

; =============================================================================
; Show connecting message
; =============================================================================
ShowConnecting:
    call ClearScreen
    ld b, 3
    ld c, 8
    call SetCursor
    ld hl, MsgConnecting
    call PrintString
    ret

; =============================================================================
; Handle title state
; =============================================================================
HandleTitle:
    ld a, [wJoypadNew]
    and PAD_START
    ret z

    call ShowConnecting
    ld a, STATE_CONNECT
    ld [wGameState], a
    ret

; =============================================================================
; Do connect state
; =============================================================================
DoConnect:
    call NetConnect
    or a
    jr nz, .fail

    call SendHello
    ld a, STATE_GAME
    ld [wGameState], a
    ret

.fail:
    ld a, STATE_TITLE
    ld [wGameState], a
    call ShowTitle
    ret

; =============================================================================
; Process game
; =============================================================================
ProcessGame:
    call NetRecv
    or a
    jr nz, .noData

    call RubpValidate
    or a
    jr nz, .noData

    call GetMessageType
    cp MSG_GAME_STATE
    jr nz, .noData
    call ProcessGameState
    call RenderGame

.noData:
    call HandleGameInput
    ret

; Include other modules
INCLUDE "input.asm"
INCLUDE "game.asm"
INCLUDE "rubp.asm"
INCLUDE "net/serial.asm"

; =============================================================================
; Data
; =============================================================================
SECTION "Strings", ROM0

MsgTitle:
    DB "RACHEL - GB", 0

MsgPressStart:
    DB "PRESS START", 0

MsgConnecting:
    DB "CONNECTING...", 0

; =============================================================================
; Font Data (ASCII 32-127, 8x8, 1bpp -> 2bpp for GB)
; =============================================================================
SECTION "Font", ROM0

FontData:
; Space ($20 = tile $80)
    DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; !
    DB $18,$18,$18,$18,$18,$18,$18,$18,$00,$00,$18,$18,$00,$00,$00,$00
; " to /
    DS 14*16, 0
; 0
    DB $7C,$7C,$C6,$C6,$CE,$CE,$D6,$D6,$E6,$E6,$C6,$C6,$7C,$7C,$00,$00
; 1
    DB $18,$18,$38,$38,$18,$18,$18,$18,$18,$18,$18,$18,$7E,$7E,$00,$00
; 2
    DB $7C,$7C,$C6,$C6,$06,$06,$1C,$1C,$30,$30,$60,$60,$FE,$FE,$00,$00
; 3
    DB $7C,$7C,$C6,$C6,$06,$06,$3C,$3C,$06,$06,$C6,$C6,$7C,$7C,$00,$00
; 4
    DB $1C,$1C,$3C,$3C,$6C,$6C,$CC,$CC,$FE,$FE,$0C,$0C,$0C,$0C,$00,$00
; 5
    DB $FE,$FE,$C0,$C0,$FC,$FC,$06,$06,$06,$06,$C6,$C6,$7C,$7C,$00,$00
; 6
    DB $3C,$3C,$60,$60,$C0,$C0,$FC,$FC,$C6,$C6,$C6,$C6,$7C,$7C,$00,$00
; 7
    DB $FE,$FE,$C6,$C6,$0C,$0C,$18,$18,$30,$30,$30,$30,$30,$30,$00,$00
; 8
    DB $7C,$7C,$C6,$C6,$C6,$C6,$7C,$7C,$C6,$C6,$C6,$C6,$7C,$7C,$00,$00
; 9
    DB $7C,$7C,$C6,$C6,$C6,$C6,$7E,$7E,$06,$06,$0C,$0C,$78,$78,$00,$00
; : to @
    DS 7*16, 0
; A
    DB $38,$38,$6C,$6C,$C6,$C6,$C6,$C6,$FE,$FE,$C6,$C6,$C6,$C6,$00,$00
; B
    DB $FC,$FC,$C6,$C6,$C6,$C6,$FC,$FC,$C6,$C6,$C6,$C6,$FC,$FC,$00,$00
; C
    DB $7C,$7C,$C6,$C6,$C0,$C0,$C0,$C0,$C0,$C0,$C6,$C6,$7C,$7C,$00,$00
; D
    DB $F8,$F8,$CC,$CC,$C6,$C6,$C6,$C6,$C6,$C6,$CC,$CC,$F8,$F8,$00,$00
; E
    DB $FE,$FE,$C0,$C0,$C0,$C0,$F8,$F8,$C0,$C0,$C0,$C0,$FE,$FE,$00,$00
; F
    DB $FE,$FE,$C0,$C0,$C0,$C0,$F8,$F8,$C0,$C0,$C0,$C0,$C0,$C0,$00,$00
; G
    DB $7C,$7C,$C6,$C6,$C0,$C0,$CE,$CE,$C6,$C6,$C6,$C6,$7C,$7C,$00,$00
; H
    DB $C6,$C6,$C6,$C6,$C6,$C6,$FE,$FE,$C6,$C6,$C6,$C6,$C6,$C6,$00,$00
; I
    DB $7E,$7E,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$7E,$7E,$00,$00
; J
    DB $1E,$1E,$06,$06,$06,$06,$06,$06,$C6,$C6,$C6,$C6,$7C,$7C,$00,$00
; K
    DB $C6,$C6,$CC,$CC,$D8,$D8,$F0,$F0,$D8,$D8,$CC,$CC,$C6,$C6,$00,$00
; L
    DB $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0,$FE,$FE,$00,$00
; M
    DB $C6,$C6,$EE,$EE,$FE,$FE,$D6,$D6,$C6,$C6,$C6,$C6,$C6,$C6,$00,$00
; N
    DB $C6,$C6,$E6,$E6,$F6,$F6,$DE,$DE,$CE,$CE,$C6,$C6,$C6,$C6,$00,$00
; O
    DB $7C,$7C,$C6,$C6,$C6,$C6,$C6,$C6,$C6,$C6,$C6,$C6,$7C,$7C,$00,$00
; P
    DB $FC,$FC,$C6,$C6,$C6,$C6,$FC,$FC,$C0,$C0,$C0,$C0,$C0,$C0,$00,$00
; Q
    DB $7C,$7C,$C6,$C6,$C6,$C6,$C6,$C6,$D6,$D6,$CC,$CC,$76,$76,$00,$00
; R
    DB $FC,$FC,$C6,$C6,$C6,$C6,$FC,$FC,$D8,$D8,$CC,$CC,$C6,$C6,$00,$00
; S
    DB $7C,$7C,$C6,$C6,$C0,$C0,$7C,$7C,$06,$06,$C6,$C6,$7C,$7C,$00,$00
; T
    DB $7E,$7E,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$00,$00
; U
    DB $C6,$C6,$C6,$C6,$C6,$C6,$C6,$C6,$C6,$C6,$C6,$C6,$7C,$7C,$00,$00
; V
    DB $C6,$C6,$C6,$C6,$C6,$C6,$C6,$C6,$6C,$6C,$38,$38,$10,$10,$00,$00
; W
    DB $C6,$C6,$C6,$C6,$C6,$C6,$D6,$D6,$FE,$FE,$EE,$EE,$C6,$C6,$00,$00
; X
    DB $C6,$C6,$6C,$6C,$38,$38,$38,$38,$38,$38,$6C,$6C,$C6,$C6,$00,$00
; Y
    DB $66,$66,$66,$66,$66,$66,$3C,$3C,$18,$18,$18,$18,$18,$18,$00,$00
; Z
    DB $FE,$FE,$0C,$0C,$18,$18,$30,$30,$60,$60,$C0,$C0,$FE,$FE,$00,$00
; [ to remaining chars - padding
    DS 37*16, 0
FontDataEnd:

; =============================================================================
; WRAM Variables
; =============================================================================
SECTION "WRAM", WRAM0

wGameState:     DS 1
wJoypad:        DS 1
wJoypadOld:     DS 1
wJoypadNew:     DS 1
wCursorX:       DS 1
wCursorY:       DS 1
wMsgSequence:   DS 1

; RUBP buffers
wNetBufferTx:   DS 64
wNetBufferRx:   DS 64

; Game state
wCurrentTurn:   DS 1
wMyIndex:       DS 1
wDiscardTop:    DS 1
wCurrentSuit:   DS 1
wDrawCount:     DS 1
wHandCount:     DS 1
wHandCursor:    DS 1
wHandCards:     DS 20
wHandSelected:  DS 20
