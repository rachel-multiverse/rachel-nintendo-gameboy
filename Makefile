# Nintendo Game Boy Rachel Client Makefile
# Uses RGBDS assembler suite

RGBASM = rgbasm
RGBLINK = rgblink
RGBFIX = rgbfix

SRC_DIR = src
BUILD_DIR = build
TARGET = $(BUILD_DIR)/rachel.gb

SOURCES = $(SRC_DIR)/main.asm
OBJECTS = $(BUILD_DIR)/main.o

.PHONY: all clean

all: $(BUILD_DIR) $(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/main.o: $(SOURCES) $(SRC_DIR)/hardware.inc $(SRC_DIR)/input.asm \
                     $(SRC_DIR)/game.asm $(SRC_DIR)/rubp.asm $(SRC_DIR)/net/serial.asm
	$(RGBASM) -o $@ -i $(SRC_DIR)/ $(SRC_DIR)/main.asm

$(TARGET): $(OBJECTS)
	$(RGBLINK) -o $@ $(OBJECTS)
	$(RGBFIX) -v -p 0xFF $@

clean:
	rm -rf $(BUILD_DIR)
