#!/usr/bin/env python3
import math
import struct
import wave
from pathlib import Path

SR = 44100
BPM = 124
BEAT = 60.0 / BPM
BAR = BEAT * 4.0
BARS = 16
DURATION = BAR * BARS
MASTER = 0.76
TICKS = 480

ROOT = Path(__file__).resolve().parents[1]
TITLE_WAV_OUT = ROOT / "audio" / "signal_dark_title.wav"
STEALTH_WAV_OUT = ROOT / "audio" / "signal_dark_spy_stealth.wav"
SEARCH_WAV_OUT = ROOT / "audio" / "signal_dark_spy_search.wav"
COMBAT_WAV_OUT = ROOT / "audio" / "signal_dark_spy_combat.wav"
MIDI_OUT = ROOT / "audio" / "signal_dark_blacksite_theme.mid"


def clamp(x: float) -> float:
    return max(-1.0, min(1.0, x))


def midi_to_hz(note: int) -> float:
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


def env(t: float, attack: float, decay: float, sustain: float, release: float, length: float) -> float:
    if t < 0.0 or t > length + release:
        return 0.0
    if t < attack:
        return t / max(attack, 1e-6)
    if t < attack + decay:
        d = (t - attack) / max(decay, 1e-6)
        return 1.0 + (sustain - 1.0) * d
    if t < length:
        return sustain
    r = (t - length) / max(release, 1e-6)
    return sustain * (1.0 - r)


def osc_sine(freq: float, t: float) -> float:
    return math.sin(2.0 * math.pi * freq * t)


def osc_square(freq: float, t: float) -> float:
    return 1.0 if osc_sine(freq, t) >= 0.0 else -1.0


def osc_saw(freq: float, t: float) -> float:
    phase = (t * freq) % 1.0
    return 2.0 * phase - 1.0


def osc_tri(freq: float, t: float) -> float:
    return 2.0 * abs(osc_saw(freq, t)) - 1.0


def lowpass(prev: float, target: float, cutoff_hz: float) -> float:
    alpha = min(0.45, (2.0 * math.pi * cutoff_hz) / SR)
    return prev + (target - prev) * alpha


def vlq(value: int) -> bytes:
    buffer = [value & 0x7F]
    value >>= 7
    while value:
        buffer.append(0x80 | (value & 0x7F))
        value >>= 7
    return bytes(reversed(buffer))


def secs_to_ticks(seconds: float) -> int:
    return int(round(seconds / BEAT * TICKS))


def build_events():
    # Original, reference-informed layout:
    # - 4/4
    # - layered synth bass
    # - hook lead in upper-mid register
    # - brass/orch hit punctuation
    # - EDM kick bed
    bass_roots = [38, 38, 41, 36]
    pulse_line = [50, 51, 50, 53, 57, 56, 53, 51]
    # More of the reference substance:
    # repeated-note drive, semitone upper-neighbor pressure, then a wider release.
    # Still original and in D minor, but closer in contour language.
    lead_a = [69, 70, 69, 70, 69, 72, 74, 70, 69, 67, 65, 67]
    lead_b = [74, 75, 74, 72, 70, 69, 70, 72, 74, 70, 69, 67]
    brass_shapes = [
        (0.0, [62, 65, 69]),
        (2.0, [60, 63, 67]),
        (3.0, [58, 62, 65]),
    ]

    events = {
        "sub_bass": [],
        "mid_bass": [],
        "pulse": [],
        "lead": [],
        "pluck": [],
        "pad": [],
        "brass": [],
        "kick": [],
        "snare": [],
        "hat": [],
    }

    for bar in range(BARS):
        bar_t = bar * BAR
        root = bass_roots[bar % len(bass_roots)]
        for beat_index in range(4):
            t = bar_t + beat_index * BEAT
            note = root + (0 if beat_index in (0, 1) else 5 if beat_index == 2 else -2)
            level = 0.62 if beat_index in (0, 2) else 0.5
            length = BEAT * (0.88 if beat_index == 3 else 0.72)
            events["sub_bass"].append((t, note - 12, length, level))
            events["mid_bass"].append((t, note, length * 0.8, level * 0.84))
            events["kick"].append((t, 1.0))
            if beat_index in (1, 3):
                events["snare"].append((t, 0.82))
            events["hat"].append((t + BEAT * 0.5, 0.22))

        for i, note in enumerate(pulse_line):
            step = BEAT * 0.5
            t = bar_t + i * step
            velocity = 0.26 if i % 2 == 0 else 0.2
            events["pulse"].append((t, note, step * 0.35, velocity))
            pluck_note = note + (12 if i % 4 in (1, 3) else 24)
            events["pluck"].append((t + step * 0.12, pluck_note, step * 0.18, 0.16 if i % 2 == 0 else 0.12))

        if bar >= 2:
            lead_phrase = lead_a if bar % 4 in (0, 1) else lead_b
            for i, note in enumerate(lead_phrase):
                t = bar_t + i * (BEAT / 3.0)
                duration = BEAT * (0.22 if i % 3 != 2 else 0.42)
                velocity = 0.16 if bar < 8 else 0.22
                if i % 4 in (0, 1):
                    events["lead"].append((t, note, duration, velocity))
                else:
                    events["pluck"].append((t, note + 12, duration * 0.75, velocity * 0.9))

        if bar % 2 == 1:
            for beat_offset, chord in brass_shapes:
                t = bar_t + beat_offset * BEAT
                for note in chord:
                    events["brass"].append((t, note, BEAT * 0.62, 0.3))
            events["lead"].append((bar_t + BEAT * 3.5, 77, BEAT * 0.28, 0.22))
            events["lead"].append((bar_t + BEAT * 3.75, 74, BEAT * 0.2, 0.18))

        pad_chords = [(50, 57, 62), (48, 55, 60), (53, 57, 62), (45, 52, 57)]
        for note in pad_chords[bar % len(pad_chords)]:
            events["pad"].append((bar_t, note, BAR * 0.96, 0.12))

    return events


def write_midi(events):
    tracks = []

    meta = bytearray()
    meta += vlq(0) + bytes([0xFF, 0x03, len(b"Signal Dark Blacksite Theme")]) + b"Signal Dark Blacksite Theme"
    meta += vlq(0) + bytes([0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08])
    meta += vlq(0) + bytes([0xFF, 0x59, 0x02, 0xFF, 0x01])  # D minor
    mpqn = int(round(60000000 / BPM))
    meta += vlq(0) + bytes([0xFF, 0x51, 0x03]) + mpqn.to_bytes(3, "big")
    meta += vlq(BARS * 4 * TICKS) + bytes([0xFF, 0x2F, 0x00])
    tracks.append(bytes(meta))

    def add_note_track(name: str, channel: int, program: int, notes):
        events_bytes = []
        events_bytes.append((0, bytes([0xFF, 0x03, len(name.encode("latin1"))]) + name.encode("latin1")))
        if channel != 9:
            events_bytes.append((0, bytes([0xC0 | channel, program])))
        for start, note, length, velocity in notes:
            start_tick = secs_to_ticks(start)
            dur_tick = max(30, secs_to_ticks(length))
            vel = max(1, min(127, int(round(velocity * 127))))
            events_bytes.append((start_tick, bytes([0x90 | channel, note, vel])))
            events_bytes.append((start_tick + dur_tick, bytes([0x80 | channel, note, 0])))
        events_bytes.sort(key=lambda item: (item[0], item[1][0] != 0x80))
        payload = bytearray()
        last = 0
        for tick, msg in events_bytes:
            payload += vlq(tick - last)
            payload += msg
            last = tick
        payload += vlq(0) + bytes([0xFF, 0x2F, 0x00])
        return bytes(payload)

    tracks.append(add_note_track("Lead", 0, 81, events["lead"]))          # lead synth
    tracks.append(add_note_track("Pulse", 1, 80, events["pulse"]))        # square lead
    tracks.append(add_note_track("Pluck", 5, 87, events["pluck"]))        # lead saw/pluck
    tracks.append(add_note_track("Mid Bass", 2, 38, events["mid_bass"]))  # synth bass
    tracks.append(add_note_track("Sub Bass", 3, 39, events["sub_bass"]))  # synth bass 2
    tracks.append(add_note_track("Brass", 4, 61, events["brass"]))        # brass section
    tracks.append(add_note_track("Pad", 6, 89, events["pad"]))            # warm pad

    drum_notes = []
    for start, level in events["kick"]:
        drum_notes.append((start, 36, 0.18, level))
    for start, level in events["snare"]:
        drum_notes.append((start, 38, 0.14, level))
        drum_notes.append((start + 0.01, 40, 0.11, level * 0.72))
    for start, level in events["hat"]:
        drum_notes.append((start, 42, 0.05, level))
        drum_notes.append((start + BEAT * 0.25, 44, 0.04, level * 0.8))
        drum_notes.append((start + BEAT * 0.125, 46, 0.02, level * 0.45))
    tracks.append(add_note_track("Drums", 9, 0, drum_notes))

    header = b"MThd" + (6).to_bytes(4, "big") + (1).to_bytes(2, "big") + len(tracks).to_bytes(2, "big") + TICKS.to_bytes(2, "big")
    body = bytearray()
    for tr in tracks:
        body += b"MTrk" + len(tr).to_bytes(4, "big") + tr
    MIDI_OUT.write_bytes(header + body)


def render(events, mode: str, out_path: Path):
    total = int(DURATION * SR)
    pcm = bytearray()
    bass_lp = 0.0
    mix_lp = 0.0
    mode_mix = {
        "title": {"sub_bass": 0.26, "mid_bass": 0.22, "pulse": 0.46, "lead": 0.26, "pluck": 0.36, "brass": 0.0, "pad": 1.0, "kick": 0.0, "snare": 0.0, "hat": 0.0, "sidechain": 0.0, "master": 0.86},
        "stealth": {"sub_bass": 0.58, "mid_bass": 0.52, "pulse": 0.8, "lead": 0.4, "pluck": 0.6, "brass": 0.16, "pad": 0.8, "kick": 0.62, "snare": 0.42, "hat": 0.38, "sidechain": 0.18, "master": 0.78},
        "search": {"sub_bass": 0.68, "mid_bass": 0.62, "pulse": 0.9, "lead": 0.48, "pluck": 0.72, "brass": 0.32, "pad": 0.74, "kick": 0.74, "snare": 0.52, "hat": 0.5, "sidechain": 0.24, "master": 0.82},
        "combat": {"sub_bass": 1.0, "mid_bass": 1.0, "pulse": 1.0, "lead": 1.0, "pluck": 1.0, "brass": 1.0, "pad": 0.7, "kick": 1.0, "snare": 1.0, "hat": 0.9, "sidechain": 0.32, "master": MASTER},
    }[mode]

    for idx in range(total):
        t = idx / SR
        sample = 0.0

        for start, note, length, level in events["sub_bass"]:
            if start <= t <= start + length + 0.16:
                nt = t - start
                f = midi_to_hz(note)
                wave_a = 0.52 * osc_sine(f, nt) + 0.24 * osc_saw(f * 0.5, nt)
                shaped = wave_a * env(nt, 0.003, 0.06, 0.74, 0.12, length)
                bass_lp = lowpass(bass_lp, shaped, 150.0)
                sample += bass_lp * level * mode_mix["sub_bass"]

        for start, note, length, level in events["mid_bass"]:
            if start <= t <= start + length + 0.1:
                nt = t - start
                f = midi_to_hz(note)
                wave_a = 0.48 * osc_saw(f, nt) + 0.2 * osc_square(f * 0.5, nt)
                sample += wave_a * env(nt, 0.004, 0.05, 0.46, 0.07, length) * level * mode_mix["mid_bass"]

        for start, note, length, level in events["pulse"]:
            if start <= t <= start + length + 0.05:
                nt = t - start
                f = midi_to_hz(note)
                pulse = 0.34 * osc_tri(f, nt) + 0.15 * osc_sine(f * 2.0, nt)
                sample += pulse * env(nt, 0.003, 0.04, 0.2, 0.03, length) * level * mode_mix["pulse"]

        for start, note, length, level in events["lead"]:
            if start <= t <= start + length + 0.08:
                nt = t - start
                f = midi_to_hz(note)
                lead = 0.32 * osc_saw(f, nt) + 0.2 * osc_square(f * 1.002, nt) + 0.12 * osc_sine(f * 2.0, nt)
                vib = 1.0 + 0.012 * math.sin(2.0 * math.pi * 5.4 * nt)
                sample += lead * vib * env(nt, 0.01, 0.06, 0.32, 0.05, length) * level * mode_mix["lead"]

        for start, note, length, level in events["pluck"]:
            if start <= t <= start + length + 0.05:
                nt = t - start
                f = midi_to_hz(note)
                pluck = 0.28 * osc_saw(f, nt) + 0.18 * osc_square(f * 2.0, nt)
                sample += pluck * env(nt, 0.002, 0.035, 0.08, 0.03, length) * level * mode_mix["pluck"]

        for start, note, length, level in events["brass"]:
            if start <= t <= start + length + 0.18:
                nt = t - start
                f = midi_to_hz(note)
                brass = 0.34 * osc_saw(f, nt) + 0.16 * osc_square(f * 0.5, nt) + 0.08 * osc_sine(f * 2.0, nt)
                sample += brass * env(nt, 0.012, 0.12, 0.42, 0.14, length) * level * mode_mix["brass"]

        for start, note, length, level in events["pad"]:
            if start <= t <= start + length + 0.18:
                nt = t - start
                f = midi_to_hz(note)
                pad = 0.14 * osc_sine(f, nt) + 0.08 * osc_tri(f * 0.5, nt)
                sample += pad * env(nt, 0.08, 0.24, 0.34, 0.16, length) * level * mode_mix["pad"]

        for start, level in events["kick"]:
            if start <= t <= start + 0.33:
                nt = t - start
                pitch = 82.0 - 52.0 * min(1.0, nt / 0.08)
                body = osc_sine(pitch, nt)
                click = math.exp(-nt * 60.0) * osc_sine(2200.0, nt)
                sample += (math.exp(-nt * 9.5) * body * 1.0 + click * 0.05) * level * mode_mix["kick"]

        for start, level in events["snare"]:
            if start <= t <= start + 0.16:
                nt = t - start
                noise = math.sin(nt * 15391.0 + nt * nt * 140.0)
                tone = osc_sine(190.0, nt)
                sample += (noise * 0.18 + tone * 0.08) * math.exp(-nt * 22.0) * level * mode_mix["snare"]

        for start, level in events["hat"]:
            if start <= t <= start + 0.05:
                nt = t - start
                noise = osc_square(5200.0, nt) * 0.42 + osc_square(7100.0, nt) * 0.28
                sample += noise * math.exp(-nt * 94.0) * level * 0.11 * mode_mix["hat"]

        sidechain = 1.0
        local_bar = t % BEAT
        if local_bar < 0.22:
            sidechain = (1.0 - mode_mix["sidechain"]) + (local_bar / 0.22) * mode_mix["sidechain"]

        mix_lp = lowpass(mix_lp, sample, 2600.0)
        mixed = clamp((sample * 0.66 + mix_lp * 0.34) * sidechain * mode_mix["master"])
        pcm.extend(struct.pack("<h", int(mixed * 32767.0)))

    peak = 1
    samples = []
    for i in range(0, len(pcm), 2):
        value = struct.unpack("<h", pcm[i:i + 2])[0]
        samples.append(value)
        peak = max(peak, abs(value))
    target_peak = int(32767 * 0.92)
    gain = target_peak / peak
    normalized = bytearray()
    for value in samples:
        normalized.extend(struct.pack("<h", int(max(-32767, min(32767, round(value * gain))))))

    with wave.open(str(out_path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SR)
        wav.writeframes(bytes(normalized))


def main():
    events = build_events()
    write_midi(events)
    render(events, "title", TITLE_WAV_OUT)
    render(events, "stealth", STEALTH_WAV_OUT)
    render(events, "search", SEARCH_WAV_OUT)
    render(events, "combat", COMBAT_WAV_OUT)
    print(TITLE_WAV_OUT)
    print(STEALTH_WAV_OUT)
    print(SEARCH_WAV_OUT)
    print(COMBAT_WAV_OUT)
    print(MIDI_OUT)


if __name__ == "__main__":
    main()
