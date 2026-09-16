# c64_asc_ubercube

Clean release of the ACME 6502 / Commodore 64 PAL demo formerly developed as Euro Pulsegrid.

## Features

- PAL 50 Hz music IRQ with KERNAL-safe `$0314` vector tail.
- True precomputed XYZ wireframe cube.
- Beat-driven cube grow/shrink zoom.
- Beat-driven bidirectional cube spin with persistent base direction.
- Drum- and lead-reactive eyecandy.
- `SPACE` jumps to the next top-level music section and cycles visual effect, tail mode, and transition mode.
- No top-line, no border flash, no VU/level overlay.
- Dirty erase/draw renderer with stream guards and frame-index clamps.

## Files

- `c64_asc_ubercube.asm` — release ACME source.
- `build.sh` — runs static audit and then ACME.
- `audit_static.py` — static safety/release audit.
- `RELEASE_NOTES.md` — release notes.
- `AUDIT_FINDINGS.md` — audit summary.

## Build

```bash
chmod +x build.sh
./build.sh
```

Expected output when ACME is installed:

```text
c64_asc_ubercube.prg
```

The static audit runs before ACME and checks the most important invariants: branch range patterns, SPACE keyboard matrix, top-section jump, cube bounds, stream guards, no top-line/border writes, beat zoom/spin state, and release cleanup.
