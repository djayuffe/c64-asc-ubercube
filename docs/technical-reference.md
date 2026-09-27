# Technical reference

This reference describes the audited `c64_asc_ubercube.asm` release. It is a
PAL-only C64 program assembled by ACME, loaded at `$0801`, and entered by its
embedded BASIC `SYS 2064` stub at `$0810`.

## Execution and timing

| Item | Value / contract |
| --- | --- |
| CPU target | MOS 6510-compatible C64 CPU |
| Video target | PAL VIC-II, 312 raster lines, 50 Hz render/music cadence |
| Raster IRQ | Line 0; `$D01A` raster mask enabled and `$D019` acknowledged |
| IRQ exit | `JMP $EA31` through the KERNAL vector contract |
| Visual queue | `frame_tick` saturates at 2; IRQ produces, main loop consumes one |
| Music row cadence | 16 steps, advanced once per `STEPFRAMES = 5` IRQs |
| Main-loop work | Scan `SPACE`, erase prior state, render one bounded visual frame |

The IRQ owns SID and song-pattern pointer mutation. The main loop never edits
active music pointers; it raises `skip_request`, which `play` consumes on the
next safe IRQ tick. This separation prevents a live transition from racing
with pattern/order fetches.

## Memory map

| Address or range | Use |
| --- | --- |
| `$0801` | Tokenized BASIC loader: `SYS 2064` |
| `$0810` | 6510 entry point and demo runtime |
| `$0002-$0005` | Visual and cube stream indirect pointers |
| `$00F7-$00FE` | Music pattern/order pointers |
| `$0314/$0315` | KERNAL IRQ vector redirected to `irq` |
| `$0400-$07E7` | 1,000 character screen cells |
| `$07E8-$07FF` | Sprite pointer tail: deliberately preserved by clear routines |
| `$D400-$D418` | SID voice/filter/master registers |
| `$D800-$DBE7` | Colour RAM paired with the screen window |
| `$DC00/$DC01` | CIA keyboard matrix for `SPACE` |
| `$D012/$D019/$D01A` | VIC raster compare, IRQ acknowledge and IRQ enable |

## Audio model

The included music engine uses all three SID voices. Bass, drum and lead
patterns are selected from four-byte order entries. The IRQ emits the musical
state and applies kick, filter, PWM, lead and bass effects. Drum and lead
events feed bounded envelopes that are reused by the visual layer, giving the
cube its zoom, spin, rail and spark response without audio analysis or a
second clock.

`SPACE` advances to the next top-level order section. The transition resets
the appropriate SID/visual transient state, loads the new order and first
step, and completes that IRQ tick without also processing a stale row.

## Wireframe data and renderer

The cube has 48 precomputed coordinate streams:

- 16 normal rotation poses;
- 16 zoom-in poses for beat peaks; and
- 16 rebound poses for the decay phase.

Each stream is an XY pair sequence with a terminator. Runtime projection is
deliberately absent: a 1 MHz C64 spends the saved cycles on predictable
erase/draw timing and responsive SID-linked behavior instead. Spin state
chooses a pose; bounded envelopes choose the normal, zoom or rebound bank.

The render order is fixed:

```text
erase tails -> erase previous cube -> draw panel accents -> draw tails -> draw cube
```

Coordinates are guarded before screen and colour writes. Cube stream data is
capped at 200 pairs; audited frame coordinates stay within X 5–35 and Y 3–22.
The visual and tail modes are masked to 0–3 before table selection.

## Static audit guarantees

`audit_static.py` is a project-specific pre-assembly check, not a replacement
for running the demo. It verifies:

- duplicate labels, undefined control-flow targets and risky relative branches;
- literal byte/word ranges that would fail ACME;
- IRQ setup/tail behavior and bounded queue ownership;
- keyboard transition ownership and section loading order;
- frame-bank count, coordinate limits, stream terminators and guard paths;
- safe 1,000-cell screen/colour clears; and
- no regression of the documented erase/draw and visual-mode contracts.

The GitHub Actions pipeline installs ACME, runs this audit, builds the PRG,
checks its `$0801` load address and uploads the binary artifact.

## Limits

This is a PAL release. NTSC cadence, physical hardware calibration, and
alternate VIC/SID revisions are outside its automated verification. The
repository includes a native VICE runtime capture, but a release operator
should still test final media and display behavior on the intended target.
