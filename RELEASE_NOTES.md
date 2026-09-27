# C64 ASC Uber Cube release notes

## v1.1.0 — 2026-09-27

- Renamed the public project and GitHub repository to `c64-asc-ubercube`, the
  identity already used by the audited ACME source and PRG.
- Added a fresh PAL VICE runtime screenshot built from the current source.
- Added GitHub Actions CI: ACME install, static audit, PRG build, `$0801`
  load-address verification and downloadable workflow artifact.
- Added `docs/technical-reference.md` with the IRQ contract, memory map,
  music/visual synchronization, renderer data model, audit guarantees and
  target limits.
- Updated public repository description and discovery topics.

## Clean release changes

- Renamed project, source, and PRG output to `c64_asc_ubercube`.
- Removed obsolete dead/compatibility code:
  - old `skip_wrap_intro` compatibility path
  - old `section_lo` / `section_hi` tables
  - unused `visual_trigger_spin_forward_slow`
  - unused `visual_clamp_cube_index_a`
- Updated `build.sh` and `audit_static.py` for the new release name.
- Added `OPT62 c64_asc_ubercube clean release audit`.

## Current core

- 50 Hz C64 PAL demo.
- True XYZ cube, precomputed normal/grow/shrink frame banks.
- Beat grow/shrink zoom.
- Beat-aware bidirectional spin.
- Drum and lead reactive visuals.
- SPACE = next section / effect / tail / music transition.
- Stable no-topline/no-border-flash presentation.

## Notes

The release keeps the 1000-cell clear behavior intentionally, preserving `$07e8-$07ff` sprite pointer area.
