# datafall


a binary sonification instrument for monome norns. load any file — code, images, PDFs, archives, anything — and hear its raw data as sound while watching its binary structure scroll across the screen.

bytes become samples. structure becomes texture. compression becomes noise. headers become rhythm.

---

## what it does

datafall reads any file byte-by-byte and interprets the raw binary data as audio. different file types produce radically different sounds:

- **text/code** — narrow frequency band, repetitive patterns, almost melodic
- **JPEG/PNG** — structured header followed by pseudo-random compressed data
- **PDF** — mixed zones of structure and chaos, text blocks create rhythm
- **ZIP/compressed** — dense white noise, maximum entropy
- **WAV/audio** — you hear the file hearing itself, warped and aliased
- **executables** — code sections drone, data sections crackle

the OLED screen shows a real-time binary waterfall: each pixel represents one byte, brightness maps to value. you literally see the data structure — headers, repeating blocks, compressed regions — all visually distinct.

---

## requirements

- **norns** (shield, standard, or fates)
- any file on the norns filesystem

## installation

```
;install https://github.com/ayso/datafall
```

restart norns after installation (`SYSTEM > RESTART`) to compile the engine.

---

## controls

### global

| control | function |
|---------|----------|
| **E1** | page select (FALL / SET / INFO) |
| **K2** | play / stop |
| **K3** | open file browser (FALL/INFO) or apply settings (SET) |
| **K1+K3** | toggle loop |

### FALL page — visualization + playback

| control | function |
|---------|----------|
| **E2** | playback rate (0.01x – 4x) |
| **E3** | lowpass filter (100 Hz – 18 kHz) |

the waterfall scrolls with playback position. a bright line marks the current play head. file type and bit depth shown in header.

### SET page — sonification settings

| control | function |
|---------|----------|
| **E2** | select setting |
| **E3** | change value |
| **K3** | apply — rebuilds audio with new settings |

| setting | options | effect |
|---------|---------|--------|
| bit depth | 1 / 4 / 8 / 16 / 24 | how many bits per audio sample |
| channels | mono / stereo | mono or alternating L/R bytes |
| sample rate | 22050 / 44100 / 48000 Hz | playback sample rate |
| visual mode | intensity / ascii / waveform | display style |
| brightness | normal / inverted / log / threshold | pixel mapping curve |

changing bit depth, channels, or sample rate requires pressing K3 to rebuild the audio file.

### INFO page — file details

| control | function |
|---------|----------|
| **E2** | amplitude |
| **E3** | lowpass filter |

displays filename, size, detected type, audio duration, and current settings.

### file browser

| control | function |
|---------|----------|
| **E2** | navigate up/down |
| **E3** | fast scroll (5x) |
| **K3** | enter folder / load file |
| **K2** | go to parent folder |

starts at `/home/we/`. folders listed first, then files. selected file shows size on the right.

---

## bit depth guide

| depth | bytes per sample | character |
|-------|-----------------|-----------|
| **1-bit** | 1 byte → 8 samples | harsh, digital, square-wave energy |
| **4-bit** | 1 byte → 2 samples | retro, crunchy, 16 amplitude levels |
| **8-bit** | 1 byte → 1 sample | balanced between detail and rawness |
| **16-bit** | 2 bytes → 1 sample | smoother, wider dynamic range |
| **24-bit** | 3 bytes → 1 sample | maximum resolution, subtle textures |

## visual modes

| mode | description |
|------|-------------|
| **intensity** | classic waterfall — each pixel = one byte, brightness = value |
| **ascii** | bytes as characters — text files become readable, binary becomes abstract poetry |
| **waveform** | oscilloscope — byte values trace amplitude on screen |

## brightness modes

| mode | mapping |
|------|---------|
| **normal** | linear: value → brightness |
| **inverted** | reversed: 0 = bright, 255 = dark |
| **log** | logarithmic: boosts low values, reveals dark detail |
| **threshold** | binary: above 128 = white, below = black |

---

## tips

- start with a **small file** — a Lua script or short text
- **lower the rate** to 0.05x–0.1x for detailed listening
- **LPF** at 1–2kHz turns harsh noise into ambient texture
- try the **same file at different bit depths** — character changes dramatically
- **stereo** on structured files creates spatial movement
- **1-bit** on text files is surprisingly rhythmic — ASCII bit patterns repeat
- compressed files sound like white noise — that's entropy made audible

---

## how it works

1. file read as raw bytes (up to 2MB)
2. bytes interpreted as PCM samples based on bit depth setting
3. temporary WAV written with chosen sample rate and channel count
4. WAV loaded into SuperCollider buffer, played with variable rate + filter
5. OLED displays raw byte values as pixels, scrolling with playback

no format awareness — just raw binary as sound. the "music" comes from the structure of the data itself.

---

## credits

built by [@ayso](https://llllllll.co/u/ayso)

inspired by [binary waterfall](https://nimaid.itch.io/binary-waterfall) by ella jameson and the data sonification research community.
