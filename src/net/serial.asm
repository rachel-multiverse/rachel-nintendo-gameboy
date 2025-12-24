; =============================================================================
; GAME BOY SERIAL MODULE
; Link cable serial communication
; =============================================================================

; The Game Boy link cable can theoretically be adapted to connect
; to an ESP8266 or similar WiFi module. The serial port runs at
; ~8kHz in internal clock mode.

SECTION "Serial", ROM0

; =============================================================================
; Initialize serial
; =============================================================================
NetInit:
    ; Set serial control: internal clock, transfer off
    ld a, %00000001
    ld [rSC], a
    ret

; =============================================================================
; Connect to server
; Returns: A = 0 on success, non-zero on failure
; =============================================================================
NetConnect:
    ; Send AT+CIPSTART
    ld hl, AtCipstart
    call SendAtString

    ; Send IP
    ld hl, IpString
    call SendAtString

    ; Send port
    ld hl, AtPort
    call SendAtString

    ; Wait for OK
    call WaitResponse
    ret

; =============================================================================
; Send AT string (HL = null-terminated string)
; =============================================================================
SendAtString:
.loop:
    ld a, [hl+]
    or a
    ret z
    call SerialWriteByte
    jr .loop

; =============================================================================
; Write byte via serial (A = byte)
; =============================================================================
SerialWriteByte:
    ld [rSB], a
    ; Start transfer with internal clock
    ld a, %10000001
    ld [rSC], a
    ; Wait for transfer complete
.waitTransfer:
    ld a, [rSC]
    bit 7, a
    jr nz, .waitTransfer
    ret

; =============================================================================
; Read byte via serial
; Returns: A = byte, carry set on timeout
; =============================================================================
SerialReadByte:
    ; Wait for incoming data (with timeout)
    ld bc, 10000
.waitData:
    ld a, [rSC]
    bit 7, a
    jr z, .gotData
    dec bc
    ld a, b
    or c
    jr nz, .waitData
    scf                     ; Timeout
    ret
.gotData:
    ld a, [rSB]
    or a                    ; Clear carry
    ret

; =============================================================================
; Wait for OK response
; Returns: A = 0 on success, 1 on timeout
; =============================================================================
WaitResponse:
    ld b, 200
.waitLoop:
    call SerialReadByte
    jr c, .nextTry
    cp "O"
    jr nz, .nextTry
    call SerialReadByte
    jr c, .nextTry
    cp "K"
    jr nz, .nextTry
    xor a
    ret
.nextTry:
    dec b
    jr nz, .waitLoop
    ld a, 1
    ret

; =============================================================================
; Send 64-byte buffer
; =============================================================================
NetSend:
    ; Send AT+CIPSEND
    ld hl, AtCipsend
    call SendAtString

    ; Send buffer
    ld hl, wNetBufferTx
    ld b, 64
.sendLoop:
    ld a, [hl+]
    call SerialWriteByte
    dec b
    jr nz, .sendLoop
    ret

; =============================================================================
; Receive 64-byte buffer
; Returns: A = 0 on success, 1 on partial, 2 on no data
; =============================================================================
NetRecv:
    ld hl, wNetBufferRx
    ld b, 64
    ld c, 0                 ; Bytes received

.recvLoop:
    call SerialReadByte
    jr c, .timeout
    ld [hl+], a
    inc c
    dec b
    jr nz, .recvLoop
    xor a                   ; Success
    ret

.timeout:
    ld a, c
    or a
    jr z, .noData
    ld a, 1                 ; Partial
    ret
.noData:
    ld a, 2
    ret

; =============================================================================
; Close connection
; =============================================================================
NetClose:
    ld hl, AtCipclose
    call SendAtString
    ret

; =============================================================================
; Data
; =============================================================================
AtCipstart:
    DB "AT+CIPSTART=\"TCP\",\"", 0
AtPort:
    DB "\",8765", 13, 0
AtCipsend:
    DB "AT+CIPSEND=64", 13, 0
AtCipclose:
    DB "AT+CIPCLOSE", 13, 0
IpString:
    DB "192.168.1.100", 0
