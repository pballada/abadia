#import <AVFoundation/AVFoundation.h>
#include "system.h"
#include "AudioPlayback.h"
#include <cstdio>
static System nativeSystem;
System *const sys = &nativeSystem;
static NSMutableDictionary<NSNumber *, AVAudioPlayer *> *players;
static const char *files[] = {"abrir", "aporrear", "campanas", "cerrar", "coger", "dejar", "espejo", "pasos", "tintineo", "inicio", "final", "fondo"};
static_assert(sizeof(files) / sizeof(*files) == TOTAL_SOUND_FILES + TOTAL_MUSIC_FILES);
struct NativeAudio {
    std::array<bool, TOTAL_SOUND_FILES + TOTAL_MUSIC_FILES> reported{};
    void report(int index, NSString *reason) {
        if (reported[index]) return;
        reported[index] = true;
        fprintf(stderr, "Audio %s.wav: %s\n", files[index], reason.UTF8String);
    }
    AVAudioPlayer *load(int index) {
        if (!players) players = [NSMutableDictionary dictionary];
        AVAudioPlayer *player = players[@(index)];
        if (!player) {
            NSString *relative = [NSString stringWithFormat:@"roms/abadia/%s.wav", files[index]];
            NSString *path = [NSFileManager.defaultManager.currentDirectoryPath stringByAppendingPathComponent:relative];
            NSError *error = nil;
            player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&error];
            if (!player) { report(index, error.localizedDescription ?: @"Unable to read audio file."); return nil; }
            [player prepareToPlay];
            players[@(index)] = player;
        }
        return player;
    }
    bool start(int index, bool loop) {
        AVAudioPlayer *player = load(index);
        if (!player) return false;
        player.numberOfLoops = loop ? -1 : 0;
        player.currentTime = 0;
        return resume(index);
    }
    bool resume(int index) {
        if ([players[@(index)] play]) return true;
        report(index, @"The audio output could not start. Check the system output device.");
        return false;
    }
    bool isPlaying(int index) { return players[@(index)].isPlaying; }
    void pause(int index) { [players[@(index)] pause]; }
    void stop(int index) { [players[@(index)] stop]; }
};
static NativeAudio nativeAudio;
static AudioPlayback<NativeAudio, TOTAL_SOUND_FILES, TOTAL_MUSIC_FILES> playback(nativeAudio);
void System::playSound(int i) { playback.playSound(i); }
void System::preloadAudio() { for (int i = 0; i < TOTAL_SOUND_FILES + TOTAL_MUSIC_FILES; ++i) nativeAudio.load(i); }
void System::playMusic(int i) { playback.playMusic(i); }
void System::stopMusic() { playback.stopMusic(); }
void System::setMuted(bool muted) { playback.setMuted(muted); }
bool System::isMuted() const { return playback.isMuted(); }
int System::currentMusic() const { return playback.currentMusic(); }
void System::setAudioPaused(bool paused) { playback.setPaused(paused); }
void System::print(const std::string message) { fprintf(stderr, "%s", message.c_str()); }
