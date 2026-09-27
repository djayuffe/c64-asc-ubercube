# C64 ASC Uber Cube release notes

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
