SHELL := /bin/bash
CXX := xcrun clang++
ARCH ?= $(shell uname -m)
CONFIG ?= release
APP := build/La abadia del crimen.app
OBJ := build/obj-$(ARCH)-$(CONFIG)
CORE := $(wildcard Sources/Core/*.cpp)
NATIVE := $(wildcard Sources/Platform/*.mm)
OBJECTS := $(patsubst Sources/Core/%.cpp,$(OBJ)/%.o,$(CORE)) $(patsubst Sources/Platform/%.mm,$(OBJ)/%.o,$(NATIVE))
FLAGS := -std=c++17 -arch $(ARCH) -mmacosx-version-min=13.0 -ISources/Core -ISources/Platform -MMD -MP -Wall -Wextra -Wno-unused-parameter -Wno-sign-compare -Wno-missing-braces -Wno-unused-variable -Wno-deprecated-declarations
ifeq ($(CONFIG),sanitize)
APP := build/Abadia-sanitized.app
FLAGS += -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer
else
FLAGS += -O2 -g
endif
FRAMEWORKS := -framework AppKit -framework AVFoundation -framework GameController -framework QuartzCore
.PHONY: all run clean test test-audio universal package
all: $(OBJ)/Abadia
	@mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp $(OBJ)/Abadia "$(APP)/Contents/MacOS/Abadia"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	cp Sources/Core/readme.txt "$(APP)/Contents/Resources/VIGASOCO.txt"
	@if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$(APP)/Contents/Resources/"; fi
	codesign --force --sign - "$(APP)"
$(OBJ)/Abadia: $(OBJECTS)
	$(CXX) $(FLAGS) $^ $(FRAMEWORKS) -o $@
$(OBJ)/%.o: Sources/Core/%.cpp
	@mkdir -p $(OBJ)
	$(CXX) $(FLAGS) -c $< -o $@
$(OBJ)/%.o: Sources/Platform/%.mm
	@mkdir -p $(OBJ)
	$(CXX) $(FLAGS) -fobjc-arc -c $< -o $@
run: all
	open "$(APP)"
$(OBJ)/AudioPlaybackTests: Tests/AudioPlaybackTests.cpp Sources/Platform/AudioPlayback.h Sources/Platform/system.h
	@mkdir -p $(OBJ)
	$(CXX) $(FLAGS) $< -o $@
test-audio: $(OBJ)/AudioPlaybackTests
	$(OBJ)/AudioPlaybackTests
test: all test-audio
	"$(APP)/Contents/MacOS/Abadia" --self-test
universal:
	$(MAKE) ARCH=arm64 all
	$(MAKE) ARCH=x86_64 all
	lipo -create build/obj-arm64-$(CONFIG)/Abadia build/obj-x86_64-$(CONFIG)/Abadia -output "$(APP)/Contents/MacOS/Abadia"
	codesign --force --sign - "$(APP)"
package: universal
	ditto -c -k --keepParent "$(APP)" build/Abadia-macOS-universal.zip
clean:
	rm -rf build
-include $(OBJECTS:.o=.d)
