; =============================================================================
; GAME BOY RUBP PROTOCOL MODULE
; =============================================================================

SECTION "RUBP", ROM0

; =============================================================================
; Initialize RUBP
; =============================================================================
RubpInit:
    xor a
    ld [wMsgSequence], a
    ret

; =============================================================================
; Build header (A = message type)
; =============================================================================
BuildHeader:
    push af
    ld hl, wNetBufferTx

    ; Magic "RACH"
    ld a, "R"
    ld [hl+], a
    ld a, "A"
    ld [hl+], a
    ld a, "C"
    ld [hl+], a
    ld a, "H"
    ld [hl+], a

    ; Version
    ld a, RUBP_VERSION
    ld [hl+], a

    ; Message type
    pop af
    ld [hl+], a

    ; Sequence
    ld a, [wMsgSequence]
    ld [hl+], a
    inc a
    ld [wMsgSequence], a

    ; Flags + reserved (8 bytes)
    xor a
    ld b, 9
.clearReserved:
    ld [hl+], a
    dec b
    jr nz, .clearReserved
    ret

; =============================================================================
; Clear payload
; =============================================================================
ClearPayload:
    ld hl, wNetBufferTx + PAYLOAD_START
    ld b, PAYLOAD_SIZE
    xor a
.clearLoop:
    ld [hl+], a
    dec b
    jr nz, .clearLoop
    ret

; =============================================================================
; Send HELLO
; =============================================================================
SendHello:
    ld a, MSG_HELLO
    call BuildHeader
    call ClearPayload

    ; Copy player name
    ld hl, PlayerName
    ld de, wNetBufferTx + PAYLOAD_START
    ld b, 16
.copyName:
    ld a, [hl+]
    ld [de], a
    inc de
    dec b
    jr nz, .copyName

    ; Platform ID
    ld a, PLATFORM_ID_HI
    ld [wNetBufferTx + PAYLOAD_START + 16], a
    ld a, PLATFORM_ID_LO
    ld [wNetBufferTx + PAYLOAD_START + 17], a

    call NetSend
    ret

; =============================================================================
; Send DRAW
; =============================================================================
SendDraw:
    ld a, MSG_DRAW_CARD
    call BuildHeader
    call ClearPayload
    call NetSend
    ret

; =============================================================================
; Send PLAY_CARD (A = card)
; =============================================================================
SendPlayCard:
    push af
    ld a, MSG_PLAY_CARD
    call BuildHeader
    call ClearPayload
    pop af
    ld [wNetBufferTx + PAYLOAD_START], a
    call NetSend
    ret

; =============================================================================
; Validate RUBP (returns A=0 if valid)
; =============================================================================
RubpValidate:
    ld hl, wNetBufferRx
    ld a, [hl+]
    cp "R"
    jr nz, .invalid
    ld a, [hl+]
    cp "A"
    jr nz, .invalid
    ld a, [hl+]
    cp "C"
    jr nz, .invalid
    ld a, [hl]
    cp "H"
    jr nz, .invalid
    xor a
    ret
.invalid:
    ld a, 1
    ret

; =============================================================================
; Get message type (returns A)
; =============================================================================
GetMessageType:
    ld a, [wNetBufferRx + 5]
    ret

; =============================================================================
; Data
; =============================================================================
PlayerName:
    DB "GAME BOY", 0, 0, 0, 0, 0, 0, 0, 0
