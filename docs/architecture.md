# Architecture guide

This guide describes the implementation in `c64_asc_ubercube.asm`. The repository is named **C64 Padded**; the imported release source retains its internal C64 ASC Uber Cube name. The guide is intentionally tied to that source and its audit rules.

## Runtime overview

```text
RUN
  -> BASIC loader at $0801 executes SYS 2064
  -> init at $0810 initialises SID, visual state, CIA keyboard matrix, and VIC raster IRQ
  -> IRQ at raster line 0 advances music and queues up to two visual ticks
  -> main loop consumes one tick, scans SPACE, and redraws the visual frame
```

The split between the IRQ and main loop is deliberate. `play` owns music-order pointers and pattern pointers, while `scan_space_skip` runs outside the IRQ and only sets `skip_request`. The next IRQ safely consumes that request before it advances the current music row.

## Interrupt and frame model

The VIC raster compare register is set to line 0 and `$D01A` enables raster interrupts. `irq` acknowledges `$D019`, runs the SID player, then increments `frame_tick` only while it is below two. The main loop decrements one queued tick and calls `visual_update`.

This bounded queue avoids two failure modes:

- A one-bit ready flag can silently lose a frame whenever rendering takes longer than one IRQ.
- An unbounded backlog can make the main loop spend all of its time catching up.

The custom `$0314/$0315` handler ends with `JMP $EA31`. This is the KERNAL-compatible tail path after the KERNAL has saved A, X, and Y before calling the vector.

## Memory and hardware use

| Area | Role |
| --- | --- |
| `$0801` | Tokenized BASIC loader (`SYS 2064`). |
| `$0810` | Assembly entry point and runtime code. |
| `$0400-$07e7` | 1,000 visible screen cells. The renderer's clear routine stops before `$07e8-$07ff`, preserving the screen-page sprite pointer area. |
| `$d800-$dbe7` | Corresponding colour RAM cells. |
| `$d400-$d418` | SID registers for the three-voice music engine and filter. |
| `$d012`, `$d019`, `$d01a` | Raster compare, interrupt acknowledge, and raster interrupt mask. |
| `$dc00/$dc01` | CIA keyboard matrix used for the `SPACE` control. |

The program assumes PAL timing: the audio/visual model is driven at 50 Hz. It is not documented or tested as an NTSC-compatible production.

## Audio and section transitions

`tune_init` initializes order and pattern pointers. `play` advances a 16-step pattern at a five-frame cadence (`STEPFRAMES = 5`) and then applies bass, drum, lead, pulse-width, and filter effects.

The `SPACE` path is intentionally transactional:

1. `scan_space_skip` uses the C64 keyboard matrix (column 7, row bit 4) to edge-detect the key and apply a cooldown.
2. It sets `skip_request` but does not alter music state.
3. `play` calls `skip_to_next_part` on the next IRQ tick.
4. The handler silences/reset relevant SID state, selects the next top-level order section, resets visual transient state, loads the new order/step, then applies its short transition preset.

Natural playback also updates `top_section_index`, so a later manual skip starts from the currently playing top-level section rather than an outdated index.

## Wireframe renderer

The cube is represented as precomputed XY pair streams rather than runtime 3D projection. The release includes 48 frame streams: 16 normal frames, 16 zoom-in frames, and 16 rebound/zoom-out frames. This makes beat-driven size changes predictable on a 1 MHz machine.

`visual_update` follows an erase-then-draw order:

1. Erase the previous tails.
2. Erase the previous cube.
3. Draw bounded panel eyecandy.
4. Draw current tails.
5. Draw the current cube stream.

The current cube frame is chosen from the normal/zoom/rebound bank according to the beat envelope. Spin direction and step state select the individual frame within that bank.

## Renderer safety rules

The static audit enforces the release's rendering contracts:

| Rule | Reason |
| --- | --- |
| Cube stream coordinates are X 5–35 and Y 3–22. | Keeps the effect away from the protected top and bottom display regions. |
| Every stream is terminated and capped by a 200-pair guard. | Prevents malformed frame data from walking past its intended byte stream. |
| Plot helpers reject coordinates outside 40 × 25. | Prevents invalid screen/colour writes. |
| Screen clearing stops at 1,000 cells. | Preserves `$07e8-$07ff` rather than overwriting sprite-pointer memory. |
| Border/background writes occur only during initialization. | Prevents unwanted flash/top-line effects during playback. |
| Visual effect/tail modes are masked to 0–3. | Keeps dynamic table and mode selection bounded. |

The renderer derives colour RAM from the screen-address calculation instead of keeping a second independent address helper. This keeps character and colour writes paired.

## Audit coverage

`audit_static.py` is a conservative pre-assembly release audit. In addition to Python-level parsing checks, it validates project-specific invariants by searching the source for required handlers and prohibited regressions.

It checks:

- Duplicate labels, undefined control-flow targets, and risky relative-branch spans.
- Literal `!byte` / `!word` ranges that could fail assembly.
- KERNAL IRQ tailing and raster/audio scheduling requirements.
- Clean keyboard matrix handling and safe `SPACE` transition ownership.
- Cube-frame count, coordinate bounds, stream guards, and address validation.
- The expected erase/draw order and no-return of removed overlays or border flashes.
- The state needed for beat zoom, bidirectional spin, tails, and music transitions.

Run it explicitly with `./audit_static.py c64_asc_ubercube.asm`; `build.sh` always runs the same command before invoking ACME.
