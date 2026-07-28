# Rachel - Nintendo Game Boy Client

A Rachel card game client for the Nintendo Game Boy.

## Platform Details

- **CPU**: Sharp LR35902 @ 4.19 MHz (Z80-like)
- **RAM**: 8KB work RAM + 127B high RAM
- **VRAM**: 8KB
- **Display**: 160x144, 4 shades of gray
- **Link Port**: Serial communication
- **Platform ID**: 0x00C2 (194)

## Building

Requires RGBDS assembler suite:

```bash
# Install RGBDS (macOS)
brew install rgbds

# Build
make
```

Output: `build/rachel.gb` (Game Boy ROM)

## Controls

- **D-Pad Left/Right**: Move cursor
- **A**: Toggle card selection
- **B**: Play selected cards
- **Select**: Draw card
- **Start**: Begin game (title screen)

## Hardware Setup

The Game Boy link port can be adapted for serial WiFi:
- Link cable connected to an ESP8266 adapter
- Software bit-banging at ~8kHz

## Architecture Notes

The Sharp LR35902 is NOT a true Z80:
- No IX/IY index registers
- No alternate register set
- Different opcode encoding for some instructions
- Memory-mapped I/O (no IN/OUT)

The display uses tiles (8x8 pixels) arranged in a 20x18 visible grid.
Only 4 colors are available (black, dark gray, light gray, white).

## Memory Map

```
$0000-$3FFF: ROM Bank 0 (16KB)
$4000-$7FFF: ROM Bank 1-N (switchable)
$8000-$9FFF: VRAM (8KB)
$A000-$BFFF: External RAM
$C000-$DFFF: Work RAM (8KB)
$FE00-$FE9F: OAM (sprite data)
$FF00-$FF7F: I/O registers
$FF80-$FFFE: High RAM (127 bytes)
```

## Files

- `src/main.asm` - Entry point and main loop
- `src/hardware.inc` - Hardware constants
- `src/input.asm` - Joypad reading
- `src/game.asm` - Game logic and rendering
- `src/rubp.asm` - Protocol implementation
- `src/net/serial.asm` - Link cable serial

## Protocol

Uses RUBP (Rachel Unified Binary Protocol):
- 64-byte fixed-size messages
- "RACH" magic header
- Platform ID: 0x00C2 (Game Boy)

Full specification: [rachel-multiverse/protocol](https://github.com/rachel-multiverse/protocol) — also rendered at <https://rachel.stevehill.xyz/protocol>.

## License

MIT License - See LICENSE file
