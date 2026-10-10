#!/usr/bin/env python3
# Génère les bruitages et les musiques de Type to Fight dans un style 8 bits
# (ondes carrées, triangle et bruit), sans aucun fichier externe.
#
# Sans argument, écrit les fichiers WAV dans src/Audio/ :
#   - src/Audio/Sfx/<nom>.wav : bruitages (touches, coups, niveau, menu...)
#   - src/Audio/Music/<nom>.wav : musiques en boucle (menu et niveaux)
#
# Usage : python3 tools/generate_sounds.py [dossier_de_sortie]
# Aucune dépendance : bibliothèque standard de Python uniquement.
import math
import os
import random
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "src", "Audio")
SFX_DIR = os.path.join(out, "Sfx")
MUSIC_DIR = os.path.join(out, "Music")
os.makedirs(SFX_DIR, exist_ok=True)
os.makedirs(MUSIC_DIR, exist_ok=True)

RATE = 22050
# bruit reproductible : les fichiers ne changent pas d'une génération à l'autre
rng = random.Random(42)

NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


# "A4" -> 440 Hz
def note(name: str) -> float:
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + NOTE_INDEX[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


# --- oscillateurs ---------------------------------------------------------

# freq : fréquence fixe ou fonction du temps (glissando) ; duty : rapport
# cyclique des ondes carrées (0.5 son plein, 0.125 son nasillard)
def tone(kind: str, freq, duration: float, duty: float = 0.5) -> list:
    samples = []
    phase = 0.0
    for i in range(int(duration * RATE)):
        t = i / RATE
        f = freq(t) if callable(freq) else freq
        phase = (phase + f / RATE) % 1.0
        if kind == "square":
            value = 1.0 if phase < duty else -1.0
        elif kind == "triangle":
            value = 4 * abs(phase - 0.5) - 1
        elif kind == "saw":
            value = 2 * phase - 1
        else:
            value = math.sin(2 * math.pi * phase)
        samples.append(value)
    return samples


# bruit 8 bits : une valeur aléatoire tenue pendant RATE/pitch échantillons
# (pitch élevé : souffle aigu, pitch bas : grondement)
def noise(duration: float, pitch=8000.0) -> list:
    samples = []
    value = 0.0
    counter = 0.0
    for i in range(int(duration * RATE)):
        p = pitch(i / RATE) if callable(pitch) else pitch
        counter += p / RATE
        if counter >= 1.0:
            counter %= 1.0
            value = rng.uniform(-1, 1)
        samples.append(value)
    return samples


# enveloppe : attaque, puis décroissance jusqu'au silence (exposant > 1 : chute rapide)
def envelope(samples: list, attack: float = 0.005, curve: float = 1.5, volume: float = 1.0) -> list:
    n = len(samples)
    attack_n = max(1, int(attack * RATE))
    result = []
    for i, s in enumerate(samples):
        if i < attack_n:
            gain = i / attack_n
        else:
            gain = (1 - (i - attack_n) / max(1, n - attack_n)) ** curve
        result.append(s * gain * volume)
    return result


def mix(*tracks) -> list:
    length = max(len(t) for t in tracks)
    result = [0.0] * length
    for track in tracks:
        for i, s in enumerate(track):
            result[i] += s
    return result


def concat(*tracks) -> list:
    result = []
    for track in tracks:
        result.extend(track)
    return result


def silence(duration: float) -> list:
    return [0.0] * int(duration * RATE)


# ajoute samples dans buffer à partir de start ; wrap : ce qui dépasse
# repart au début (pour une boucle musicale sans coupure)
def place(buffer: list, samples: list, start: int, wrap: bool = False):
    for i, s in enumerate(samples):
        index = start + i
        if index >= len(buffer):
            if not wrap:
                return
            index %= len(buffer)
        buffer[index] += s


def write(path: str, samples: list, peak: float = 0.9):
    top = max(1e-9, max(abs(s) for s in samples))
    gain = peak / top if top > peak else 1.0
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))
    print(os.path.relpath(path, ROOT), "%.2fs" % (len(samples) / RATE))


# notes jouées l'une après l'autre (arpège ou petit jingle)
def jingle(notes: list, step: float, kind: str = "square", duty: float = 0.5, volume: float = 0.5, last_length: float = 3.0) -> list:
    parts = []
    for i, name in enumerate(notes):
        length = step * (last_length if i == len(notes) - 1 else 1.0)
        parts.append(envelope(tone(kind, note(name), length, duty), curve=1.2, volume=volume))
    return concat(*parts)


# --- bruitages ------------------------------------------------------------

def sfx():
    sounds = {}

    # bonne touche : petit « bip » clair et court (sa hauteur monte avec le combo dans le jeu)
    sounds["key"] = envelope(tone("square", note("E6"), 0.06, 0.25), curve=2.0, volume=0.35)

    # mauvaise touche : bourdonnement grave qui descend
    sounds["wrong"] = envelope(mix(
        tone("square", lambda t: 180 - 300 * t, 0.16, 0.5),
        tone("square", lambda t: 190 - 300 * t, 0.16, 0.5),
    ), curve=1.0, volume=0.25)

    # coup dans le vide : souffle qui monte puis retombe
    sounds["whiff"] = envelope(noise(0.16, lambda t: 2000 + 9000 * math.sin(math.pi * t / 0.16)), attack=0.03, curve=1.2, volume=0.35)

    # ruée vers un ennemi : souffle rapide et aigu
    sounds["dash"] = envelope(noise(0.12, lambda t: 6000 + 40000 * t), attack=0.01, curve=1.5, volume=0.3)

    # l'arme touche l'ennemi : impact sourd + claquement
    sounds["hit"] = mix(
        envelope(tone("sine", lambda t: 220 * math.exp(-t * 25) + 60, 0.12), curve=2.0, volume=0.8),
        envelope(noise(0.07, 5000), curve=3.0, volume=0.5),
    )

    # ennemi vaincu : craquement puis petit cri qui descend
    sounds["die"] = concat(
        mix(
            envelope(noise(0.08, 3000), curve=2.0, volume=0.6),
            envelope(tone("sine", lambda t: 160 * math.exp(-t * 20) + 50, 0.08), curve=1.5, volume=0.7),
        ),
        envelope(tone("square", lambda t: 900 * math.exp(-t * 9), 0.2, 0.25), attack=0.0, curve=1.0, volume=0.25),
    )

    # le joueur est blessé : choc grave et grésillant
    sounds["hurt"] = mix(
        envelope(tone("square", lambda t: 300 * math.exp(-t * 6), 0.25, 0.5), curve=1.2, volume=0.35),
        envelope(noise(0.2, 1500), curve=2.0, volume=0.4),
    )

    # combo (multiplicateur augmenté) : arpège brillant
    sounds["combo"] = jingle(["C6", "E6", "G6", "C7"], 0.045, duty=0.25, volume=0.3, last_length=2.5)

    # début de niveau : petite montée
    sounds["level_start"] = jingle(["C5", "E5", "G5", "C6"], 0.08, duty=0.5, volume=0.3, last_length=3.0)

    # « C'est parti ! »
    sounds["go"] = mix(
        jingle(["G5", "C6"], 0.09, duty=0.25, volume=0.35, last_length=3.0),
        jingle(["G4", "C5"], 0.09, kind="triangle", volume=0.4, last_length=3.0),
    )

    # touche de départ (F, J...) trouvée
    sounds["ready"] = envelope(tone("triangle", note("A5"), 0.1), curve=1.5, volume=0.5)

    # niveau réussi : fanfare
    melody = jingle(["C5", "E5", "G5", "C6", "G5", "C6"], 0.1, duty=0.5, volume=0.3, last_length=4.0)
    bass = jingle(["C3", "C3", "G3", "C4"], 0.15, kind="triangle", volume=0.5, last_length=3.0)
    sounds["level_passed"] = mix(melody, bass)

    # niveau à rejouer : deux notes, sans tristesse excessive
    sounds["level_retry"] = mix(
        jingle(["E5", "C5", "D5"], 0.14, duty=0.5, volume=0.3, last_length=3.0),
        jingle(["C3", "A2", "G2"], 0.14, kind="triangle", volume=0.5, last_length=3.0),
    )

    # partie perdue : descente
    sounds["gameover"] = mix(
        jingle(["G4", "F#4", "F4", "E4", "D#4", "C4"], 0.16, duty=0.5, volume=0.3, last_length=5.0),
        jingle(["C3", "B2", "A#2", "A2", "G#2", "C2"], 0.16, kind="triangle", volume=0.5, last_length=5.0),
    )

    # nouveau record : scintillement
    sparkle = [concat(silence(i * 0.05), envelope(tone("square", note(name), 0.18, 0.125), curve=2.0, volume=0.2))
               for i, name in enumerate(["E6", "G6", "B6", "E7", "G7", "B7", "E7", "B7"])]
    sounds["record"] = mix(*sparkle)

    # interface : clic de bouton et changement de bouton
    sounds["click"] = envelope(tone("square", lambda t: 1200 - 4000 * t, 0.05, 0.25), curve=2.0, volume=0.3)
    sounds["move"] = envelope(tone("triangle", note("C6"), 0.035), curve=1.5, volume=0.35)

    for name, samples in sounds.items():
        write(os.path.join(SFX_DIR, name + ".wav"), samples)


# --- musiques -------------------------------------------------------------

def kick() -> list:
    return envelope(tone("sine", lambda t: 140 * math.exp(-t * 30) + 45, 0.14), attack=0.001, curve=1.5, volume=0.9)


def snare() -> list:
    return mix(
        envelope(noise(0.12, 7000), attack=0.001, curve=2.0, volume=0.35),
        envelope(tone("triangle", 190, 0.06), attack=0.001, curve=2.0, volume=0.3),
    )


def hat(volume: float = 0.12) -> list:
    return envelope(noise(0.03, 20000), attack=0.001, curve=3.0, volume=volume)


# morceau de 16e en 16e : chaque mesure a un accord (pour la basse et l'arpège)
# et, éventuellement, une mélodie [(pas, note, longueur en pas)]
def song(bpm: float, bars: list, bass_style: str, drums: str, lead_duty: float, lead_volume: float, arp_volume: float) -> list:
    step = 60.0 / bpm / 4
    step_n = int(round(step * RATE))
    total = step_n * 16 * len(bars)
    buffer = [0.0] * total

    for bar_index, bar in enumerate(bars):
        chord = bar["chord"]
        bar_start = bar_index * 16 * step_n

        # basse au triangle
        if bass_style == "eighths":
            pattern = [(0, 0), (2, 0), (4, 1), (6, 0), (8, 0), (10, 0), (12, 1), (14, 0)]
            for s, octave_up in pattern:
                name = chord[0][:-1] + str(int(chord[0][-1]) + octave_up)
                place(buffer, envelope(tone("triangle", note(name), step * 1.8), curve=0.8, volume=0.55), bar_start + s * step_n, True)
        else:
            for s, index in [(0, 0), (8, 1)]:
                name = chord[0] if index == 0 else chord[2][:-1] + str(int(chord[0][-1]))
                place(buffer, envelope(tone("triangle", note(name), step * 7.5), attack=0.01, curve=0.7, volume=0.55), bar_start + s * step_n, True)

        # arpège discret sur les notes de l'accord, une octave au-dessus
        if arp_volume > 0:
            arp = [chord[1], chord[2], chord[3] if len(chord) > 3 else chord[1][:-1] + str(int(chord[1][-1]) + 1), chord[2]]
            for s in range(16):
                name = arp[s % len(arp)]
                place(buffer, envelope(tone("square", note(name), step * 0.9, 0.125), curve=1.5, volume=arp_volume), bar_start + s * step_n, True)

        # mélodie
        for s, name, length in bar.get("melody", []):
            samples = tone("square", note(name), step * length, lead_duty)
            place(buffer, envelope(samples, attack=0.005, curve=0.6, volume=lead_volume), bar_start + s * step_n, True)

        # percussions
        if drums == "full":
            for s in (0, 8, 10):
                place(buffer, kick(), bar_start + s * step_n, True)
            for s in (4, 12):
                place(buffer, snare(), bar_start + s * step_n, True)
            for s in range(0, 16, 2):
                place(buffer, hat(0.1 if s % 4 else 0.14), bar_start + s * step_n, True)
        elif drums == "light":
            place(buffer, kick(), bar_start, True)
            for s in range(2, 16, 4):
                place(buffer, hat(0.08), bar_start + s * step_n, True)

    return buffer


def music():
    # niveaux : la mineur, entraînant mais pas stressant, pour taper en rythme
    am = ["A2", "A4", "C5", "E5"]
    f = ["F2", "F4", "A4", "C5"]
    c = ["C3", "C5", "E5", "G5"]
    g = ["G2", "G4", "B4", "D5"]
    e = ["E2", "E4", "G#4", "B4"]
    chords = [am, f, c, g, am, f, g, e]
    melodies = [
        [(0, "E5", 2), (2, "A5", 2), (4, "C6", 2), (6, "B5", 2), (8, "A5", 4), (12, "E5", 4)],
        [(0, "F5", 2), (2, "A5", 2), (4, "C6", 4), (8, "A5", 2), (10, "G5", 2), (12, "F5", 4)],
        [(0, "E5", 2), (2, "G5", 2), (4, "C6", 2), (6, "D6", 2), (8, "E6", 4), (12, "D6", 2), (14, "C6", 2)],
        [(0, "B5", 4), (4, "G5", 4), (8, "D5", 4), (12, "G5", 4)],
        [(0, "A5", 2), (2, "C6", 2), (4, "E6", 4), (8, "D6", 2), (10, "C6", 2), (12, "B5", 2), (14, "A5", 2)],
        [(0, "C6", 4), (4, "A5", 2), (6, "F5", 2), (8, "A5", 4), (12, "C6", 4)],
        [(0, "B5", 2), (2, "D6", 2), (4, "G6", 4), (8, "F6", 2), (10, "D6", 2), (12, "B5", 4)],
        [(0, "G#5", 4), (4, "B5", 4), (8, "E6", 6)],
    ]
    # première moitié avec la mélodie, seconde moitié en arpèges seuls
    bars = [{"chord": chords[i], "melody": melodies[i]} for i in range(8)]
    bars += [{"chord": chords[i]} for i in range(8)]
    level = song(118, bars, "eighths", "full", lead_duty=0.25, lead_volume=0.16, arp_volume=0.05)
    write(os.path.join(MUSIC_DIR, "level.wav"), level, peak=0.7)

    # menu : do majeur, plus calme
    cm = ["C3", "C4", "E4", "G4"]
    am2 = ["A2", "A3", "C4", "E4"]
    f2 = ["F2", "F3", "A3", "C4"]
    g2 = ["G2", "G3", "B3", "D4"]
    menu_melodies = [
        [(0, "E5", 6), (6, "D5", 2), (8, "C5", 4), (12, "G4", 4)],
        [(0, "A4", 4), (4, "C5", 4), (8, "E5", 8)],
        [(0, "F5", 6), (6, "E5", 2), (8, "C5", 4), (12, "A4", 4)],
        [(0, "B4", 4), (4, "D5", 4), (8, "G5", 8)],
        [(0, "G5", 6), (6, "E5", 2), (8, "C5", 4), (12, "E5", 4)],
        [(0, "A5", 4), (4, "G5", 4), (8, "E5", 8)],
        [(0, "F5", 4), (4, "A5", 4), (8, "G5", 4), (12, "F5", 4)],
        [(0, "D5", 4), (4, "B4", 4), (8, "G4", 8)],
    ]
    menu_chords = [cm, am2, f2, g2, cm, am2, f2, g2]
    menu_bars = [{"chord": menu_chords[i], "melody": menu_melodies[i]} for i in range(8)]
    menu = song(96, menu_bars, "halves", "light", lead_duty=0.5, lead_volume=0.12, arp_volume=0.06)
    write(os.path.join(MUSIC_DIR, "menu.wav"), menu, peak=0.7)


if __name__ == "__main__":
    sfx()
    music()
