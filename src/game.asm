; =============================================================================
; GAME BOY GAME MODULE
; =============================================================================

SECTION "Game", ROM0

; =============================================================================
; Process game state from network
; =============================================================================
ProcessGameState:
    ld hl, wNetBufferRx + PAYLOAD_START
    ld a, [hl+]
    ld [wCurrentTurn], a
    ld a, [hl+]
    ld [wMyIndex], a
    ld a, [hl+]
    ld [wDiscardTop], a
    ld a, [hl+]
    ld [wCurrentSuit], a
    ld a, [hl+]
    ld [wDrawCount], a
    ld a, [hl+]
    ld [wHandCount], a

    ; Copy hand cards
    ld de, wHandCards
    ld b, 20
.copyHand:
    ld a, [hl+]
    ld [de], a
    inc de
    dec b
    jr nz, .copyHand

    ; Clear selection
    ld hl, wHandSelected
    ld b, 20
    xor a
.clearSel:
    ld [hl+], a
    dec b
    jr nz, .clearSel

    xor a
    ld [wHandCursor], a
    ret

; =============================================================================
; Render game
; =============================================================================
RenderGame:
    call ClearScreen

    ; Discard pile
    ld b, 1
    ld c, 1
    call SetCursor
    ld hl, LblDiscard
    call PrintString
    ld a, [wDiscardTop]
    call PrintCard

    ; Current suit
    ld b, 1
    ld c, 3
    call SetCursor
    ld hl, LblSuit
    call PrintString
    ld a, [wCurrentSuit]
    call PrintSuit

    ; Draw count
    ld a, [wDrawCount]
    or a
    jr z, .noDrawCount
    ld b, 1
    ld c, 5
    call SetCursor
    ld hl, LblDraw
    call PrintString
    ld a, [wDrawCount]
    call PrintDecimal

.noDrawCount:
    ; Render hand
    call RenderHand

    ; Status
    ld b, 0
    ld c, 16
    call SetCursor
    ld a, [wCurrentTurn]
    ld b, a
    ld a, [wMyIndex]
    cp b
    jr nz, .showWaiting
    ld hl, LblYourTurn
    jr .showStatus
.showWaiting:
    ld hl, LblWaiting
.showStatus:
    call PrintString
    ret

; =============================================================================
; Render hand
; =============================================================================
RenderHand:
    ld b, 0
    ld c, 12
    call SetCursor

    ld a, [wHandCount]
    or a
    ret z

    ld b, a
    ld de, wHandCards
    ld hl, wHandSelected
    xor a
    ld c, a                 ; Index

.renderLoop:
    push bc
    push hl
    push de

    ; Cursor indicator
    ld a, [wHandCursor]
    cp c
    jr nz, .noCursor
    ld a, "["
    call PrintChar
    jr .showCard
.noCursor:
    ld a, " "
    call PrintChar

.showCard:
    pop de
    push de
    ld a, [de]
    call PrintCard

    ; Selected indicator
    pop de
    pop hl
    push hl
    push de
    ld a, [hl]
    or a
    jr z, .notSel
    ld a, "*"
    call PrintChar
    jr .nextCard
.notSel:
    ld a, " "
    call PrintChar

.nextCard:
    pop de
    inc de
    pop hl
    inc hl
    pop bc
    inc c
    dec b
    jr nz, .renderLoop
    ret

; =============================================================================
; Print card (A = card byte)
; =============================================================================
PrintCard:
    push af
    srl a
    srl a                   ; Divide by 4 for rank
    ld hl, Ranks
    add l
    ld l, a
    ld a, [hl]
    call PrintChar
    pop af
    and $03
    call PrintSuit
    ret

; =============================================================================
; Print suit (A = 0-3)
; =============================================================================
PrintSuit:
    ld hl, Suits
    add l
    ld l, a
    ld a, [hl]
    call PrintChar
    ret

; =============================================================================
; Print decimal (A = 0-99)
; =============================================================================
PrintDecimal:
    ld b, 0
.tens:
    cp 10
    jr c, .printOnes
    sub 10
    inc b
    jr .tens
.printOnes:
    push af
    ld a, b
    or a
    jr z, .skipTens
    add "0"
    call PrintChar
.skipTens:
    pop af
    add "0"
    call PrintChar
    ret

; =============================================================================
; Handle game input
; =============================================================================
HandleGameInput:
    ; Left
    ld a, [wJoypadNew]
    and PAD_LEFT
    jr z, .notLeft
    ld a, [wHandCursor]
    or a
    jr z, .notLeft
    dec a
    ld [wHandCursor], a
    call RenderGame
.notLeft:

    ; Right
    ld a, [wJoypadNew]
    and PAD_RIGHT
    jr z, .notRight
    ld a, [wHandCursor]
    ld b, a
    ld a, [wHandCount]
    dec a
    cp b
    jr z, .notRight
    jr c, .notRight
    ld a, [wHandCursor]
    inc a
    ld [wHandCursor], a
    call RenderGame
.notRight:

    ; A = select
    ld a, [wJoypadNew]
    and PAD_A
    jr z, .notSelect
    ld a, [wHandCursor]
    ld hl, wHandSelected
    add l
    ld l, a
    ld a, [hl]
    xor $FF
    ld [hl], a
    call RenderGame
.notSelect:

    ; B = play
    ld a, [wJoypadNew]
    and PAD_B
    jr z, .notPlay
    call PlaySelectedCards
.notPlay:

    ; Select = draw
    ld a, [wJoypadNew]
    and PAD_SELECT
    jr z, .notDraw
    call SendDraw
.notDraw:
    ret

; =============================================================================
; Play selected cards
; =============================================================================
PlaySelectedCards:
    ld hl, wHandSelected
    ld de, wHandCards
    ld a, [wHandCount]
    or a
    ret z
    ld b, a
.findSel:
    ld a, [hl+]
    or a
    jr nz, .foundSel
    inc de
    dec b
    jr nz, .findSel
    ret
.foundSel:
    ld a, [de]
    call SendPlayCard
    ret

; =============================================================================
; Data
; =============================================================================
Ranks:
    DB "A23456789TJQK"
Suits:
    DB "HDCS"

LblDiscard:
    DB "DISC:", 0
LblSuit:
    DB "SUIT:", 0
LblDraw:
    DB "DRAW:", 0
LblYourTurn:
    DB "YOUR TURN A/B/SEL", 0
LblWaiting:
    DB "WAITING...", 0
