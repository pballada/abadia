#pragma once
// Native macOS platform contract for the Abbey/VIGASOCO game logic.
// SDLPalette is an upstream class name; no SDL runtime is used.
#include <cstdint>
#include <string>
#include <array>
#include <libkern/OSByteOrder.h>
using Uint8 = uint8_t;
using Uint32 = uint32_t;
inline uint16_t SDL_SwapLE16(uint16_t n) { return OSSwapLittleToHostInt16(n); }
constexpr int TEXTURE_WIDTH = 640, TEXTURE_HEIGHT = 400;
constexpr unsigned GAME_FRAME_TIME = 130, SCROLL_FRAME_TIME = 60;
enum MUSICFILES { START, END, BACKGROUND, TOTAL_MUSIC_FILES };
enum SOUNDFILES { OPEN, HIT, BELLS, CLOSE, GET, LET, MIRROR, STEPS, JINGLE, TOTAL_SOUND_FILES };
enum STATES { INTRO, SCROLL, MENU, LANGUAGE, LOAD, SAVE, PLAY, ASK_NEW_GAME, ASK_CONTINUE, ASK_EXIT, ENDING };
struct PlayerInput {
    bool up{}, down{}, left{}, right{}, button1{}, button2{}, button3{}, button4{}, start{};
};
#define BUTTON_YES sys->pad.button3
#define BUTTON_NO sys->pad.button2
struct NativeSurface { void *pixels; };
struct System {
    PlayerInput pad{};
    bool exit = false, muted = false;
    unsigned minimumFrameTime = GAME_FRAME_TIME;
    std::array<uint32_t, TEXTURE_WIDTH * TEXTURE_HEIGHT> framebuffer{};
    NativeSurface storage{framebuffer.data()};
    NativeSurface *surface = &storage;
    void playMusic(int i);
    void stopMusic();
    void setAudioPaused(bool paused);
    void playSound(int i);
    void hapticFeedback() {}
    void setFastSpeed() { minimumFrameTime = SCROLL_FRAME_TIME; }
    void setNormalSpeed() { minimumFrameTime = GAME_FRAME_TIME; }
    uint32_t RGBA(uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
        return uint32_t(r) | uint32_t(g) << 8 | uint32_t(b) << 16 | uint32_t(a) << 24;
    }
    void updateTexture() {}
    void exitGame() { exit = true; }
    void print(const std::string message);
};
extern System *const sys;
