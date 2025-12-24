; =============================================================================
; GAME BOY INPUT MODULE
; =============================================================================

SECTION "Input", ROM0

; =============================================================================
; Read joypad
; =============================================================================
ReadJoypad:
    ; Save old state
    ld a, [wJoypad]
    ld [wJoypadOld], a

    ; Read D-pad
    ld a, %00100000         ; Select D-pad
    ld [rP1], a
    ld a, [rP1]              ; Read several times for debounce
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    and $0F
    swap a
    ld b, a

    ; Read buttons
    ld a, %00010000         ; Select buttons
    ld [rP1], a
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    and $0F
    or b

    ; Invert (buttons are active low)
    cpl
    ld [wJoypad], a

    ; Calculate newly pressed buttons
    ld b, a
    ld a, [wJoypadOld]
    cpl
    and b
    ld [wJoypadNew], a

    ; Reset joypad
    ld a, %00110000
    ld [rP1], a
    ret
