#include "AudioPlayback.h"
#include "system.h"
#include <cstdio>

struct FakeAudio {
    struct Player { bool playing = false, loop = false; int starts = 0, resumes = 0, stops = 0, position = 0; };
    std::array<Player, TOTAL_SOUND_FILES + TOTAL_MUSIC_FILES> players{};
    bool fail = false;
    bool start(int i, bool loop) {
        auto& p = players.at(i);
        ++p.starts; p.loop = loop; p.position = 0;
        return p.playing = !fail;
    }
    bool resume(int i) { ++players.at(i).resumes; return players.at(i).playing = !fail; }
    bool isPlaying(int i) { return players.at(i).playing; }
    void pause(int i) { players.at(i).playing = false; }
    void stop(int i) { ++players.at(i).stops; players.at(i).playing = false; }
};

int main() {
    FakeAudio backend;
    AudioPlayback<FakeAudio, TOTAL_SOUND_FILES, TOTAL_MUSIC_FILES> audio(backend);
    auto& intro = backend.players[TOTAL_SOUND_FILES + START];
    auto& background = backend.players[TOTAL_SOUND_FILES + BACKGROUND];
    auto& ending = backend.players[TOTAL_SOUND_FILES + END];
    auto& steps = backend.players[STEPS];
    bool ok = true;
    auto check = [&](bool value, const char *message) {
        printf("%s audio: %s\n", value ? "PASS" : "FAIL", message); ok &= value;
    };
    audio.playMusic(START);
    intro.position = 42;
    for (int i = 0; i < 100; ++i) audio.playMusic(START);
    check(intro.playing && intro.loop && intro.starts == 1 && intro.position == 42,
          "repeated game ticks do not restart the music");
    audio.playSound(STEPS);
    audio.playMusic(BACKGROUND);
    check(!intro.playing && background.playing && steps.playing && !steps.loop,
          "changing music stops the previous track and preserves sound effects");
    background.position = 17; steps.position = 3;
    audio.setPaused(true); audio.setPaused(true);
    check(!background.playing && !steps.playing, "pause silences music and active effects");
    audio.playSound(OPEN);
    audio.setPaused(false); audio.setPaused(false);
    check(background.playing && background.position == 17 && steps.playing && steps.position == 3 &&
          steps.resumes == 1 && backend.players[OPEN].starts == 0,
          "repeated pause preserves playback positions and does not queue new effects");
    audio.setMuted(true);
    check(!background.playing && !steps.playing && audio.isMuted(), "mute silences all playback");
    audio.playSound(STEPS);
    audio.setMuted(false);
    check(background.playing && background.position == 17 && background.starts == 1 &&
          !steps.playing && steps.starts == 1, "unmute resumes music without replaying stale effects");
    audio.setPaused(true); audio.setMuted(true); audio.setMuted(false);
    check(!background.playing, "unmuting while paused remains silent");
    audio.setPaused(false);
    check(background.playing && background.position == 17, "resuming after mute restores the selected music");
    audio.setMuted(true); audio.setPaused(true); audio.setPaused(false);
    check(!background.playing, "resuming while muted remains silent");
    audio.playMusic(END);
    check(ending.starts == 0 && audio.currentMusic() == END, "track changes are remembered while muted");
    audio.setMuted(false);
    check(ending.playing && ending.starts == 1 && !background.playing, "unmute starts only the newly selected track");
    audio.playSound(STEPS); audio.stopMusic();
    check(!ending.playing && steps.playing, "stopMusic leaves sound effects playing");
    audio.playMusic(END); audio.setPaused(true); audio.stopMusic(); audio.setPaused(false);
    check(!ending.playing && audio.currentMusic() == -1, "a stopped track is not resurrected after a pause");
    audio.playMusic(-1); audio.playMusic(TOTAL_MUSIC_FILES);
    audio.playSound(-1); audio.playSound(TOTAL_SOUND_FILES);
    check(audio.currentMusic() == -1, "invalid audio identifiers are ignored");
    backend.fail = true; audio.playMusic(START);
    check(!intro.playing && audio.currentMusic() == START, "output failure retains the requested track");
    backend.fail = false; audio.setMuted(true); audio.setMuted(false);
    check(intro.playing && intro.starts == 3, "a failed start can be retried on unmute");
    return ok ? 0 : 1;
}
