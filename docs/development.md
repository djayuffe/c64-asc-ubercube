# Development and release guide

This guide is for maintainers of C64 Padded. The repository name is C64 Padded, while the imported ACME source and build product intentionally retain the stable `c64_asc_ubercube` identifier.

## Prerequisites

- ACME assembler (`acme`) for production builds.
- Python 3 for `audit_static.py`.
- VICE (`x64sc`) for emulator smoke tests.
- A PAL C64 or PAL-configured emulator for representative timing.

Confirm the local tools before editing:

```sh
command -v acme
command -v python3
command -v x64sc
```

## Normal change cycle

1. Make a focused source or documentation change.
2. Run the static audit:

   ```sh
   ./audit_static.py c64_asc_ubercube.asm
   ```

3. Build through the supported entry point:

   ```sh
   ./build.sh
   ```

4. Run the generated PRG in VICE:

   ```sh
   x64sc -autostartprgmode 1 -autostart c64_asc_ubercube.prg
   ```

5. Inspect the effect for several beats. Press `SPACE` repeatedly and confirm that the soundtrack continues, the cube is erased cleanly, and the next section/effect arrives without a stale visual frame.

The generated `c64_asc_ubercube.prg` is ignored by Git. Commit source, documentation, tests, and intentionally curated media only.

## Low-level change rules

The C64 has tight timing and memory constraints. Treat these as release requirements, not style preferences:

- Keep the custom IRQ tail as `JMP $EA31`; do not replace it with an `RTI` when using the KERNAL `$0314` vector contract.
- Keep music order/pattern pointer mutations in the IRQ-owned playback path. Main-loop input should only raise `skip_request`.
- Preserve the two-tick `frame_tick` cap. A boolean loses work; an unbounded counter can starve input and rendering.
- Preserve the visual coordinate window and stream guard. Every frame stream must remain terminated and fit the audited bounds.
- Do not clear past the first 1,000 screen cells. `$07e8-$07ff` is not general-purpose screen memory.
- Do not reintroduce per-frame `$d020`/`$d021` writes unless the raster/timing implications are designed and audited.
- If you change table counts, frame banks, or mode masks, update `audit_static.py` in the same commit.

The [architecture guide](architecture.md) gives the ownership and data-flow context for these rules.

## Release checklist

Before tagging a release, run:

```sh
./audit_static.py c64_asc_ubercube.asm
./build.sh
git diff --check
git fsck --no-reflogs
git status --short
```

Then complete a PAL VICE smoke test and, if the display has changed, replace `assets/uber-cube-live.png` with a genuine native VICE capture of the tagged build. Do not use mockups or edited emulator output as a runtime screenshot.

Finally, update `README.md`, `AUDIT_FINDINGS.md`, and `RELEASE_NOTES.md` when the behavior, release status, or audit coverage changes. Create an annotated version tag only after the working tree is clean and `main` contains the verified release commit.
