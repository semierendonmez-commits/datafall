# datafall

waterfall binary sonification for norns. load any file — code, images, PDFs, archives, anything — and hear its raw data as sound while watching its binary structure scroll across the screen.

---

## what it does

datafall reads any file byte-by-byte and interprets the raw binary data as audio. different file types produce radically different sounds:

- **text/code** — narrow frequency band, repetitive patterns, almost melodic
- **JPEG/PNG** — structured header followed by pseudo-random compressed data
- **PDF** — mixed zones of structure and chaos, text blocks create rhythm
- **ZIP/compressed** — dense white noise, maximum entropy
- **WAV/audio** — you hear the file hearing itself, warped and aliased
- **executables** — code sections drone, data sections crackle

the OLED screen shows a real-time binary waterfall: each pixel represents one byte, brightness maps to value. you literally see the data structure.

---

## requirements

- **norns** (shield, standard, or fates)
- any file on the norns filesystem

## installation

```
;install https://github.com/semierendonmez-commits/datafall
```

restart norns after installation (`SYSTEM > RESTART`) to compile the engine.

---

## controls

### FALL page — visualization + playback

| control | function |
|---------|----------|
| **E2** | playback rate (0.01x – 4x) |
| **E3** | lowpass filter (when LPF is on) |
| **K2** | play / stop |
| **K3** | open file browser |
| **K1+K3** | toggle loop (default ON)|

### SET page — settings

| control | function |
|---------|----------|
| **E2** | select setting |
| **E3** | change value |
| **K3** | APPLY — rebuild audio with new settings |

| setting | options | effect |
|---------|---------|--------|
| bit depth | 1 / 4 / 8 / 16 / 24 | bits per audio sample |
| channels | mono / stereo | mono duplicates to both channels, stereo alternates L/R |
| sample rate | 22050 / 44100 / 48000 Hz | playback sample rate |
| visual mode | normal / inverted / threshold / 1-bit | waterfall brightness mapping |
| lowpass | ON / OFF | toggle lowpass filter |
| APPLY | K3 | rebuild + restart playback |

### file browser

| control | function |
|---------|----------|
| **E2** | navigate |
| **E3** | fast scroll (5x) |
| **K3** | enter folder / load file |
| **K2** | parent folder |

### global

| control | function |
|---------|----------|
| **E1** | page select (FALL / SET) |

---

## bit depth guide

| depth | character |
|-------|-----------|
| **1-bit** | harsh, digital, square-wave energy |
| **4-bit** | retro, crunchy, 16 amplitude levels |
| **8-bit** | balanced between detail and rawness |
| **16-bit** | smoother, wider dynamic range |
| **24-bit** | maximum resolution, subtle textures |

## visual modes

| mode | description |
|------|-------------|
| **normal** | linear: byte value → brightness |
| **inverted** | reversed: 0 = bright, 255 = dark |
| **threshold** | binary at midpoint, stark contrast |
| **1-bit** | pure black and white |

---

## params menu extras

- **focus mode** — hides header/footer, waterfall fills the screen. only progress bar remains.
- **lowpass on/off** — bypass filter without changing freq value
- **APPLY** — also available as trigger in params menu

---

## tips

- start with a small file (a Lua script, a text file)
- lower the rate to 0.05x–0.1x for detailed listening
- LPF at 1–2kHz turns harsh data into ambient texture
- try the same file at different bit depths
- stereo on structured files creates spatial movement
- 1-bit visual mode reveals file structure most clearly
- compressed files sound like white noise — that's entropy made audible

---

## how it works

1. file read as raw bytes 
2. bytes interpreted as PCM samples based on bit depth
3. temporary stereo WAV written (mono = same data both channels)
4. WAV loaded into SuperCollider buffer
5. played with variable rate + optional LPF
6. OLED shows byte values as pixel brightness, scrolling with playback

---

## credits

built by [@SEMI](https://llllllll.co/u/semi)

inspired by [binary waterfall](https://nimaid.itch.io/binary-waterfall) by ella jameson.
