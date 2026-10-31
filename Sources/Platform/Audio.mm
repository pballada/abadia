#import <AVFoundation/AVFoundation.h>
#include "system.h"
#include <cstdio>
static System nativeSystem;
System *const sys = &nativeSystem;
static NSMutableDictionary<NSNumber *, AVAudioPlayer *> *players;
static NSMutableSet<NSNumber *> *pausedPlayers;
static const char *files[] = {"abrir", "aporrear", "campanas", "cerrar", "coger", "dejar", "espejo", "pasos", "tintineo", "inicio", "final", "fondo"};
static void Play(int index, bool loop) {
    if (sys->muted || index < 0 || index >= 12) return;
    if (!players) players = [NSMutableDictionary dictionary];
    AVAudioPlayer *player = players[@(index)];
    if (!player) {
        NSString *path = [NSString stringWithFormat:@"roms/abadia/%s.wav", files[index]];
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
        if (!player) return;
        players[@(index)] = player;
    }
    if (loop && player.isPlaying) return;
    player.numberOfLoops = loop ? -1 : 0;
    player.currentTime = 0;
    [player play];
}
void System::playSound(int i) { if (i >= 0 && i < TOTAL_SOUND_FILES) Play(i, false); }
void System::playMusic(int i) { if (i >= 0 && i < TOTAL_MUSIC_FILES) Play(9 + i, true); }
void System::stopMusic() { for (NSNumber *key in players) [players[key] stop]; }
void System::setAudioPaused(bool paused) {
    if (paused) {
        pausedPlayers = [NSMutableSet set];
        for (NSNumber *key in players) if (players[key].isPlaying) {
            [pausedPlayers addObject:key]; [players[key] pause];
        }
    } else {
        if (!muted) for (NSNumber *key in pausedPlayers) [players[key] play];
        [pausedPlayers removeAllObjects];
    }
}
void System::print(const std::string message) { fprintf(stderr, "%s", message.c_str()); }
