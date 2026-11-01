#pragma once
#include <array>

// Playback policy shared by AVFoundation and the device-independent regression test.
// Backend supplies start(index, loop), resume, pause, stop, and isPlaying.
template<class Backend, int Effects, int Music>
class AudioPlayback {
public:
    explicit AudioPlayback(Backend& backend) : backend(backend) {}
    bool isMuted() const { return muted; }
    int currentMusic() const { return music; }
    void playSound(int index) {
        if (index >= 0 && index < Effects && !muted && !paused) backend.start(index, false);
    }
    void playMusic(int index) {
        if (index < 0 || index >= Music || music == index) return;
        stopMusic();
        music = index;
        updateMusic();
    }
    void stopMusic() {
        if (music >= 0) backend.stop(Effects + music);
        music = -1;
        musicStarted = musicPlaying = false;
    }
    void setMuted(bool value) {
        if (muted == value) return;
        muted = value;
        if (muted) {
            for (int i = 0; i < Effects; ++i) backend.stop(i);
            pausedEffects.fill(false); // Muting discards one-shot effects, not the music position.
        }
        updateMusic();
    }
    void setPaused(bool value) {
        if (paused == value) return;
        paused = value;
        for (int i = 0; i < Effects; ++i) {
            if (paused) {
                pausedEffects[i] = backend.isPlaying(i);
                if (pausedEffects[i]) backend.pause(i);
            } else {
                if (pausedEffects[i] && !muted) backend.resume(i);
                pausedEffects[i] = false;
            }
        }
        updateMusic();
    }
private:
    void updateMusic() {
        if (music < 0) return;
        const int index = Effects + music;
        if (muted || paused) {
            if (musicPlaying) backend.pause(index);
            musicPlaying = false;
        } else if (!musicPlaying) {
            musicPlaying = musicStarted ? backend.resume(index) : backend.start(index, true);
            musicStarted |= musicPlaying;
        }
    }
    Backend& backend;
    int music = -1;
    bool muted = false, paused = false, musicStarted = false, musicPlaying = false;
    std::array<bool, Effects> pausedEffects{};
};
