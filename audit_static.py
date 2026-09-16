#!/usr/bin/env python3
import re, sys, pathlib
p=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else 'c64_asc_ubercube.asm')
raw=p.read_text()
text=raw.splitlines()
labels={}; dups=[]; refs=[]
branch_ops={'beq','bne','bcc','bcs','bmi','bpl','bvc','bvs'}
for no,line in enumerate(text,1):
    s=line.split(';',1)[0].rstrip()
    m=re.match(r'^([A-Za-z_][A-Za-z0-9_]*):',s)
    if m:
        lab=m.group(1)
        if lab in labels: dups.append((lab, labels[lab], no))
        labels[lab]=no
    for op in ['jsr','jmp',*branch_ops]:
        mm=re.search(r'\b'+op+r'\s+([A-Za-z_][A-Za-z0-9_]*)',s,re.I)
        if mm: refs.append((no,op.lower(),mm.group(1)))
undefined=[r for r in refs if r[2] not in labels and r[2].upper() not in {'A','X','Y'}]
print(f'lines={len(text)} labels={len(labels)} duplicate_labels={len(dups)} undefined_control_refs={len(undefined)}')
if dups:
    print('DUPLICATES:'); [print(d) for d in dups]
if undefined:
    print('UNDEFINED:'); [print(u) for u in undefined[:50]]
if dups or undefined: raise SystemExit(1)
# conservative branch distance guard
far=[]
for no,op,target in refs:
    if op in branch_ops and target in labels and abs(labels[target]-no)>80:
        far.append((no,op,target,labels[target]-no))
if far:
    print('RISKY RELATIVE BRANCH DISTANCE:'); [print(x) for x in far[:50]]; raise SystemExit(1)

# ACME byte/word range guard: catch Number out of range before assembler.
def parse_num(tok):
    tok=tok.strip()
    if not tok or tok.startswith('<') or tok.startswith('>'):
        return None
    if tok.startswith('$'):
        return int(tok[1:],16)
    if re.fullmatch(r'-?\d+', tok):
        return int(tok)
    return None
for no,line in enumerate(text,1):
    code=line.split(';',1)[0]
    if '!byte' in code:
        for tok in code.split('!byte',1)[1].split(','):
            val=parse_num(tok)
            if val is not None and not (-128 <= val <= 255):
                raise AssertionError(f'line {no}: !byte value out of ACME range: {tok.strip()}')
    if '!word' in code:
        for tok in code.split('!word',1)[1].split(','):
            val=parse_num(tok)
            if val is not None and not (-32768 <= val <= 65535):
                raise AssertionError(f'line {no}: !word value out of ACME range: {tok.strip()}')

asm='\n'.join(text)
assert 'jmp $ea31' in asm.lower(), 'IRQ must tail-call KERNAL restore at $EA31'
assert 'sta SCREEN_RAM+$300,x' in asm and 'cpx #$e8' in asm, 'screen clear must stop at 1000 bytes'
# No removed visual overlays
for forbidden in ['jsr visual_draw_vu','jsr visual_draw_starfield','jsr visual_draw_spark_frame','jsr visual_draw_glam','visual_plot_beat_scale:','jsr visual_plot_beat_scale']:
    assert forbidden not in asm, f'regression: removed overlay/runtime dilation returned: {forbidden}'
# no top-line/border flash routine/path
assert 'flash_color' not in asm, 'flash_color path must remain removed'
assert 'visual_beat_flash:' not in asm and 'jsr visual_beat_flash' not in asm, 'border/top-line flash must remain removed'
for marker in ['$d020','$d021']:
    uses=[i+1 for i,l in enumerate(text) if marker in l.split(';',1)[0].lower()]
    assert len(uses)==1, f'{marker} must only be written once in visual_init, found {uses}'
irq_block=asm.split('irq:',1)[1].split('tune_init:',1)[0].lower()
assert '$d020' not in irq_block and '$d021' not in irq_block, 'IRQ must not touch border/background'
# skip request must be applied in play/IRQ, not by SEI/CLI in main scanner
scan_block=asm.split('scan_space_skip:',1)[1].split('skip_to_next_part:',1)[0]
assert 'sei' not in scan_block.lower() and 'cli' not in scan_block.lower(), 'scan_space_skip must not mask IRQs'
play_block=asm.split('play:',1)[1].split('next_step:',1)[0]
assert 'skip_request' in play_block and 'jsr skip_to_next_part' in play_block, 'skip request must be consumed inside play path'
# OPT34: 50Hz visual cadence
vu_block=asm.split('visual_update:',1)[1].split('visual_update_beat_scale:',1)[0]
assert vu_block.count('inc vis_frame')==1, 'visual_update must advance exactly one frame per IRQ tick'
assert 'cmp #2' not in vu_block and 'visual_do_redraw' not in asm, 'OPT34: 25 Hz throttle must be removed'
# OPT34: filter is back for musical build only
assert 'jsr fx_filter' in play_block and 'fx_filter:' in asm, 'OPT34 build filter routine/call missing'
assert 'sta FRES' in asm and 'sta FMODE' in asm and 'sta FLO' in asm and 'sta FHI' in asm, 'OPT34 filter register writes missing'
assert 'lda #92\n        lda #0' not in asm, 'dead lda #92 init bug still present'
# frame parse/bounds
frame_labels=re.findall(r'^(cube_(?:fr|pu|zo)\d\d):', asm, re.M)
assert len(frame_labels)==48, f'expected 48 cube frames including OPT45 zoom-out set, found {len(frame_labels)}'
max_pairs=0; max_lab=None
for lab in frame_labels:
    block=asm.split(lab+':',1)[1].split('        !byte $ff',1)[0]
    nums=[]
    for line in block.splitlines():
        code=line.split(';',1)[0]
        if '!byte' not in code: continue
        for token in code.split('!byte',1)[1].split(','):
            token=token.strip()
            if not token: continue
            nums.append(int(token[1:],16) if token.startswith('$') else int(token))
    assert len(nums)%2==0 and len(nums)>=80, f'{lab} incomplete/too sparse'
    pairs=len(nums)//2
    if pairs>max_pairs: max_pairs=pairs; max_lab=lab
    assert pairs <= 200, f'{lab} exceeds stream guard: {pairs} pairs'
    for x,y in zip(nums[0::2], nums[1::2]):
        assert 5 <= x <= 35, f'{lab} x outside OPT34 safe window: {x}'
        assert 3 <= y <= 22, f'{lab} y outside OPT34 safe window/topline: {y}'
# pointer walk and guard
assert 'visual_cube_ptr_inc:' in asm, 'pointer-walk helper missing'
assert 'sty cube_y_save' not in asm and 'ldy cube_y_save' not in asm, 'old Y-index stream scanner remains'
assert 'cube_stream_guard:' in asm and 'dec cube_stream_guard' in asm, 'stream guard missing'
assert 'lda #$c8' in asm, 'OPT34 stream guard should allow 200 XY-pairs'
# safe address helpers
for marker in ['visual_calc_screen_addr:','visual_calc_addr_bad:','cmp #25','cmp #40']:
    assert marker in asm, f'safe address helper/check missing: {marker}'
assert 'visual_calc_color_addr:' not in asm, 'OPT49: redundant color address helper should remain removed'
assert 'adc #$d4' in asm, 'OPT49: color pointer must be derived from screen pointer high byte'
# drum visual and 1:1
for lab in ['visual_style_kick:', 'visual_style_snare:', 'visual_style_hat:', 'visual_style_crash:', 'visual_style_lift:', 'visual_style_pshhh:']:
    assert lab in asm, f'drum style missing: {lab}'
assert 'OPT37: canonical XYZ model is documented' in asm and 'Vertices q4:' in asm and 'Edges:' in asm, 'canonical XYZ documentation missing'
assert 'cube3d_vertices_xyz_q4:' not in asm and 'cube3d_edges_ab:' not in asm and 'cube3d_rotation_phase_deg:' not in asm, 'unused assembled cube3d metadata tables must remain removed'
lead_expected={
    'leadAm':[46,0,49,0,53,0,49,0,46,0,49,0,53,0,49,0],
    'leadEAm':[58,0,61,0,65,0,61,0,58,61,65,61,58,61,65,70],
}
for name, vals in lead_expected.items():
    m=re.search(r'^'+name+r':\s*!byte\s*([0-9,]+)$', asm, re.M)
    assert m, f'{name} missing'
    got=[int(x) for x in m.group(1).split(',')]
    assert got==vals, f'{name} not lowered as expected: {got}'
print('static audit: PASS')
print('OPT34 closure audit: PASS longest=%s:%d pairs' % (max_lab,max_pairs))

# OPT36: fixes for latest external audit blockers
assert 'sid_drum_hard_silence:' in asm, 'OPT36 hard V3 cleanup helper missing'
for lab in ['drum_kick:', 'drum_snare:', 'drum_hat:', 'drum_crash:', 'drum_lift:', 'drum_pshhh:']:
    block=asm.split(lab,1)[1].split('        rts',1)[0]
    assert 'jsr sid_drum_hard_silence' in block, f'{lab} must hard-reset V3 before retrigger'
assert 'visual_clear_request:' in asm, 'OPT36 visual_clear_request variable missing'
assert 'jsr visual_clear_screen' in asm.split('visual_update:',1)[1].split('visual_update_beat_scale:',1)[0], 'visual_update must service visual_clear_request with full clear'
skip_block=asm.split('skip_apply:',1)[1].split('\nTOP_SECTION_COUNT',1)[0]
assert 'sta visual_clear_request' in skip_block, 'section skip must request full panel clear'
assert 'jsr sid_drum_hard_silence' in skip_block, 'section skip must hard-silence drums'
assert 'sta pshhh_env' in skip_block and 'sta drum_visual_type' in skip_block, 'section skip must clear drum/noise visual state'
assert 'sta V3CTL' in asm.split('fx_kick_off:',1)[1].split('fx_kick_keep:',1)[0] and 'lda #$00' in asm.split('fx_kick_off:',1)[1].split('fx_kick_keep:',1)[0], 'drum decay off must clear V3 control'
# Verify generated cube data really has no screen-OOB and no safe-window-OOB coordinates.
print('OPT36 hardening audit: PASS')

# OPT37 final closure checks
assert 'vis_tick:' not in asm and 'sta vis_tick' not in asm, 'unused vis_tick state must remain removed'
assert 'cmp #97' in asm, 'freq table corrupt-note guard missing'
skip_block=asm.split('skip_apply:',1)[1].split('\nTOP_SECTION_COUNT',1)[0]
assert 'sta V1CTL' in skip_block and 'sta V2CTL' in skip_block, 'section skip must reset melodic gates too'
print('OPT37 final closure audit: PASS')

# OPT38/OPT48 safe eyecandy checks
assert 'jsr visual_draw_panel_eyecandy' in asm, 'OPT38 eyecandy draw call missing'
assert 'visual_draw_panel_eyecandy:' in asm and 'visual_pick_eyecandy_style:' in asm, 'OPT38 eyecandy routines missing'
if 'eyecandy_rows:' in asm:
    eyem=re.search(r'^eyecandy_rows:\s*\n\s*!byte\s*([^\n]+)', asm, re.M)
    assert eyem, 'OPT38 eyecandy_rows parse failed'
    eyerows=[int(x.strip().replace('$','0x'),0) for x in eyem.group(1).split(',')]
    assert all(3 <= y <= 22 for y in eyerows), f'OPT38 eyecandy rows must avoid top line and bottom unsafe area: {eyerows}'
else:
    assert 'visual_store_rail_chars_a:' in asm, 'OPT48 direct rail helpers must replace eyecandy_rows table'
assert 'sta $d020' not in asm.split('visual_draw_panel_eyecandy:',1)[1].split('visual_clear_screen:',1)[0], 'OPT38 eyecandy must not touch border'
assert 'sta $d021' not in asm.split('visual_draw_panel_eyecandy:',1)[1].split('visual_clear_screen:',1)[0], 'OPT38 eyecandy must not touch background'
print('OPT38 safe eyecandy audit: PASS')

# OPT39 explicit SPACE section-jump checks
assert 'jsr scan_space_skip' in asm.split('main_visual_loop:',1)[1].split('irq:',1)[0], 'OPT39: main loop must poll SPACE'
scan_block=asm.split('scan_space_skip:',1)[1].split('skip_to_next_part:',1)[0]
assert 'lda #$7f' in scan_block and 'and #$10' in scan_block, 'OPT54: SPACE matrix scan must select C64 column 7 and row bit 4'
assert 'sta space_latch' in scan_block and 'sta skip_request' in scan_block, 'OPT39: SPACE must be edge-latched and request a skip'
assert 'jmp scan_space_done' in scan_block and 'sta $dc00' in scan_block, 'OPT39: SPACE scan must restore CIA column state'
play_block=asm.split('play:',1)[1].split('next_step:',1)[0]
assert 'lda skip_request' in play_block and 'sta skip_request' in play_block and 'jsr skip_to_next_part' in play_block, 'OPT39: skip_request must be consumed in play path'
skip_block=asm.split('skip_to_next_part:',1)[1].split('\nTOP_SECTION_COUNT',1)[0]
assert 'skip_apply:' in skip_block and 'lda #0' in skip_block and 'sta top_section_index' in skip_block, 'OPT39: skip must support top-section wrap and apply paths'
assert 'jsr next_order' in skip_block and 'jsr next_step' in skip_block, 'OPT39: skip must immediately apply next section pattern/step'
assert 'sta visual_clear_request' in skip_block and 'jsr sid_drum_hard_silence' in skip_block, 'OPT39: skip must clear visual state and hard-reset drums'
print('OPT39 space section-jump audit: PASS')


# OPT40 explicit SPACE next part/section swap + debounce checks
assert 'skip_cooldown:' in asm, 'OPT40: skip_cooldown debounce variable missing'
scan_block=asm.split('scan_space_skip:',1)[1].split('skip_to_next_part:',1)[0]
assert 'dec skip_cooldown' in scan_block and 'sta skip_cooldown' in scan_block, 'OPT40: SPACE debounce/cooldown missing'
assert 'sta skip_request' in scan_block, 'OPT40: SPACE must set skip_request for next part/section swap'
skip_block=asm.split('skip_apply:',1)[1].split('\nTOP_SECTION_COUNT',1)[0]
assert 'sta skip_cooldown' in skip_block, 'OPT40: section swap must reset cooldown on apply/wrap cleanup'
assert 'jsr next_order' in skip_block and 'jsr next_step' in skip_block, 'OPT40: section swap must immediately load next part pattern and first step'
print('OPT40 space next-section swap audit: PASS')

# OPT41/OPT42 final release closure checks
irq_block=asm.split('irq:',1)[1].split('tune_init:',1)[0]
main_block=asm.split('main_visual_loop:',1)[1].split('irq:',1)[0]
assert 'inc frame_tick' in irq_block and 'cmp #$02' in irq_block and 'irq_frame_tick_full:' in irq_block, 'OPT42: IRQ must use bounded 2-frame tick queue'
assert 'dec frame_tick' in main_block and 'sta frame_tick' not in main_block, 'OPT41: main loop must DEC-consume frame_tick, not zero it as a lossy flag'
assert ('C64 ASC UBERCUBE' in asm) or ('EURO PULSEGRID FIX20 / OPT45 BEAT ZOOM CUBE CLOSURE' in asm) or ('EURO PULSEGRID FIX20 / OPT46 FULL BEAT-AWARE EYECANDY' in asm) or ('EURO PULSEGRID FIX20 / OPT47 BEAT-RING EYECANDY CLOSURE' in asm) or ('EURO PULSEGRID FIX20 / OPT48 HYPEROPT EYECANDY CLOSURE' in asm) or ('EURO PULSEGRID FIX20 / OPT49 FINAL HYPERPLOT CLOSURE' in asm) or ('EURO PULSEGRID FIX20 / OPT50 BEAT PUMP ZOOM CLOSURE' in asm) or ('EURO PULSEGRID FIX20 / OPT57 FINAL AUDIT CLEANUP' in asm), 'release title missing'
assert 'lda #$08\n        lda #$08' not in asm, 'OPT42: duplicate V2AD init LDA cleanup regressed'
assert 'lda vis_frame\n        tax\n        tax' not in asm, 'OPT42: duplicate TAX cleanup regressed'
assert 'rts\n        rts\nvisual_style_no_drum' not in asm, 'OPT42: duplicate RTS cleanup regressed'
print('OPT41 final release closure audit: PASS')
print('OPT42 final polish closure audit: PASS')


# OPT43 SPACE swaps section + effect + tails
assert 'visual_cycle_effect_tail_swap:' in asm, 'OPT43: effect/tail cycle helper missing'
skip_block=asm.split('skip_apply:',1)[1].split('\nTOP_SECTION_COUNT',1)[0]
assert 'jsr visual_cycle_effect_tail_swap' in skip_block, 'OPT43: SPACE section swap must also cycle effects/tails'
assert 'effect_mode:' in asm and 'tail_mode:' in asm, 'OPT43: effect/tail state variables missing'
assert 'prev_tail_index1:' in asm and 'prev_tail_index2:' in asm, 'OPT43: tail erase slots missing'
vu_block=asm.split('visual_update:',1)[1].split('visual_update_beat_scale:',1)[0]
assert 'jsr visual_erase_previous_tails' in vu_block and 'jsr visual_draw_cube_tails' in vu_block, 'OPT43: visual update must erase/draw safe cube tails'
for lab in ['visual_erase_previous_tails:', 'visual_draw_cube_tails:', 'visual_draw_tail_index_a:', 'visual_plot_tail_cell:']:
    assert lab in asm, f'OPT43: missing tail routine {lab}'
assert 'sta $d020' not in asm.split('visual_draw_cube_tails:',1)[1].split('visual_erase_previous_cube:',1)[0], 'OPT43: tails must not touch border'
assert 'sta $d021' not in asm.split('visual_draw_cube_tails:',1)[1].split('visual_erase_previous_cube:',1)[0], 'OPT43: tails must not touch background'
print('OPT43 space section/effect/tail swap audit: PASS')


# OPT44 final section/effect/tail closure checks
assert 'OPT45: final tail/section/effect/beat-zoom closure' in asm, 'OPT45 closure comment missing'
vu_block=asm.split('visual_update:',1)[1].split('visual_update_beat_scale:',1)[0]
order_required=['jsr visual_erase_previous_tails','jsr visual_erase_previous_cube','jsr visual_draw_panel_eyecandy','jsr visual_draw_cube_tails','jsr visual_draw_cube']
pos=[vu_block.index(x) for x in order_required]
assert pos==sorted(pos), 'OPT44: visual erase/draw order must be tails erase, cube erase, eyecandy, tails, cube'
cycle_block=asm.split('visual_cycle_effect_tail_swap:',1)[1].split('\nTOP_SECTION_COUNT',1)[0]
assert cycle_block.count('and #$03')>=2, 'OPT44: effect_mode and tail_mode must remain 0..3'
assert 'sta visual_clear_request' in cycle_block, 'OPT44: SPACE effect/tail swap must force a full visual clear'
assert 'sta prev_tail_index1' in cycle_block and 'sta prev_tail_index2' in cycle_block, 'OPT44: effect/tail swap must invalidate tail erase slots'
for lab in ['visual_erase_previous_tails:', 'visual_draw_cube_tails:', 'visual_draw_tail_index_a:', 'visual_plot_tail_cell:']:
    block=asm.split(lab,1)[1].split('\n\n',1)[0]
    if lab in ['visual_draw_tail_index_a:', 'visual_plot_tail_cell:']:
        assert 'visual_calc_' in block or 'cube_stream_guard' in block, f'OPT44: {lab} must stay guarded/bounds checked'
tails_block=asm.split('visual_erase_previous_tails:',1)[1].split('visual_erase_previous_cube:',1)[0]
assert 'lda #$c8' in tails_block and 'dec cube_stream_guard' in tails_block, 'OPT44: tail erase/draw must use stream guard'
assert '$d020' not in tails_block.lower() and '$d021' not in tails_block.lower(), 'OPT44: tails must not touch VIC border/background'
print('OPT44 perfect section/effect/tail closure audit: PASS')


# OPT45 beat zoom in/out closure checks
assert 'cube_zo00:' in asm and 'cube_zo15:' in asm, 'OPT45: zoom-out/rebound cube frame set missing'
assert '+32' in asm or 'adc #32' in asm, 'OPT45: draw path must select rebound zoom-out frames'
draw_block=asm.split('visual_draw_cube:',1)[1].split('visual_draw_loop:',1)[0]
assert 'visual_frame_zoom_in:' in draw_block and 'adc #16' in draw_block and 'adc #32' in draw_block, 'OPT45: cube draw must select zoom-in and zoom-out frame banks'
assert 'visual_plot_beat_scale:' not in asm and 'jsr visual_plot_beat_scale' not in asm, 'OPT45: runtime dilation/scaling must remain removed'
# verify zoom frames are smaller on average than corresponding normal frames, so decay visibly zooms out.
def frame_pairs(lab):
    block=asm.split(lab+':',1)[1].split('        !byte $ff',1)[0]
    nums=[]
    for line in block.splitlines():
        code=line.split(';',1)[0]
        if '!byte' not in code: continue
        for token in code.split('!byte',1)[1].split(','):
            token=token.strip()
            if token:
                nums.append(int(token[1:],16) if token.startswith('$') else int(token))
    return list(zip(nums[0::2], nums[1::2]))
for i in range(16):
    fr=frame_pairs(f'cube_fr{i:02d}')
    zo=frame_pairs(f'cube_zo{i:02d}')
    assert len(fr)==len(zo), f'OPT45: zoom frame pair count mismatch {i}'
    frw=max(x for x,y in fr)-min(x for x,y in fr)
    zow=max(x for x,y in zo)-min(x for x,y in zo)
    frh=max(y for x,y in fr)-min(y for x,y in fr)
    zoh=max(y for x,y in zo)-min(y for x,y in zo)
    assert zow <= frw and zoh <= frh, f'OPT45: zoom-out frame not smaller/equal for frame {i}'
print('OPT45 beat zoom in/out audit: PASS')


# OPT46 full beat-aware eyecandy closure checks
assert 'beat_pulse_env:' in asm and 'beat_spark_phase:' in asm, 'OPT46: beat pulse/spark state missing'
assert 'visual_erase_beat_sparks:' in asm and 'visual_draw_beat_sparks:' in asm, 'OPT46: beat spark erase/draw routines missing'
vu_block=asm.split('visual_update:',1)[1].split('visual_update_beat_scale:',1)[0]
assert 'jsr visual_erase_beat_sparks' in vu_block and 'jsr visual_draw_beat_sparks' in vu_block, 'OPT46: visual update must erase and draw beat sparks'
assert vu_block.index('jsr visual_erase_beat_sparks') < vu_block.index('jsr visual_draw_beat_sparks'), 'OPT46: beat sparks must be erased before draw'
scale_block=asm.split('visual_update_beat_scale:',1)[1].split('visual_pick_style:',1)[0]
if 'EURO PULSEGRID FIX20 / OPT50 BEAT PUMP ZOOM CLOSURE' not in asm and 'EURO PULSEGRID FIX20 / OPT57 FINAL AUDIT CLEANUP' not in asm and 'C64 ASC UBERCUBE' not in asm:
    for lab in ['visual_scale_from_kick:', 'visual_scale_snare:', 'visual_scale_hat:', 'visual_scale_crash:', 'visual_scale_lift:', 'visual_scale_pshhh:']:
        assert lab in scale_block, f'OPT46: missing drum-specific zoom path {lab}'
else:
    # OPT50 moves drum-specific zoom seeding to the drum trigger routines so the
    # envelope can decay visibly instead of being re-pinned every frame.
    for lab in ['drum_kick:', 'drum_snare:', 'drum_hat:', 'drum_crash:', 'drum_lift:', 'drum_pshhh:']:
        block=asm.split(lab,1)[1].split('        rts',1)[0]
        assert 'sta cube_scale_env' in block, f'OPT50: missing trigger-time zoom seed in {lab}'
if 'beat_spark_x:' in asm:
    for lab in ['visual_beat_spark_kick:', 'visual_beat_spark_snare:', 'visual_beat_spark_hat:', 'visual_beat_spark_crash:', 'visual_beat_spark_lift:', 'visual_beat_spark_pshhh:']:
        assert lab in asm, f'OPT46: missing drum-specific spark style {lab}'
    for name in ['beat_spark_x', 'beat_spark_y']:
        m=re.search(r'^'+name+r':\s*\n\s*!byte\s*([^\n]+)', asm, re.M)
        assert m, f'OPT46: missing {name} table'
        vals=[int(x.strip().replace('$','0x'),0) for x in m.group(1).split(',')]
        if name.endswith('_x'):
            assert all(0 <= v < 40 for v in vals), f'OPT46: beat spark x OOB {vals}'
        else:
            assert all(1 <= v < 25 for v in vals), f'OPT46: beat spark y must avoid row0/OOB {vals}'
else:
    assert 'beat_spark_char_lut:' in asm and 'visual_store_beat_spark_chars_a:' in asm, 'OPT48: direct spark style/store replacement missing'
beat_block=asm.split('visual_erase_beat_sparks:',1)[1].split('visual_draw_panel_eyecandy:',1)[0]
assert '$d020' not in beat_block.lower() and '$d021' not in beat_block.lower(), 'OPT46: beat spark eyecandy must not touch VIC border/background'
print('OPT46 full beat-aware eyecandy audit: PASS')


# OPT47 beat-ring eyecandy closure checks
assert 'visual_erase_beat_rings:' in asm and 'visual_draw_beat_rings:' in asm, 'OPT47: beat ring erase/draw routines missing'
vu_block=asm.split('visual_update:',1)[1].split('visual_update_beat_scale:',1)[0]
assert 'jsr visual_erase_beat_rings' in vu_block and 'jsr visual_draw_beat_rings' in vu_block, 'OPT47: visual update must erase/draw beat rings'
assert vu_block.index('jsr visual_erase_beat_rings') < vu_block.index('jsr visual_draw_beat_rings'), 'OPT47: beat rings must be erased before draw'
assert 'jsr visual_erase_beat_rings' in vu_block.split('jsr visual_draw_panel_eyecandy',1)[0], 'OPT47: beat rings must erase before eyecandy redraw'
if 'beat_ring_x:' in asm:
    for name in ['beat_ring_x', 'beat_ring_y']:
        m=re.search(r'^'+name+r':\s*\n\s*!byte\s*([^\n]+)', asm, re.M)
        assert m, f'OPT47: missing {name} table'
        vals=[int(x.strip().replace('$','0x'),0) for x in m.group(1).split(',')]
        assert len(vals)==12, f'OPT47: {name} must have 12 cells'
        if name.endswith('_x'):
            assert all(5 <= v <= 35 for v in vals), f'OPT47: beat ring x outside safe cube panel {vals}'
        else:
            assert all(3 <= v <= 22 for v in vals), f'OPT47: beat ring y outside safe cube panel/topline {vals}'
else:
    assert 'visual_store_beat_ring_chars_a:' in asm and 'visual_store_beat_ring_colors_a:' in asm, 'OPT48: direct ring stores must replace ring tables'
ring_block=asm.split('visual_erase_beat_rings:',1)[1].split('visual_draw_panel_eyecandy:',1)[0]
assert '$d020' not in ring_block.lower() and '$d021' not in ring_block.lower(), 'OPT47: beat rings must not touch VIC border/background'
assert ('cpx #12' in ring_block) or ('visual_store_beat_ring_chars_a:' in ring_block), 'OPT47/OPT48: ring plotter must be bounded or direct-store fixed cells'
print('OPT47 beat-ring eyecandy closure audit: PASS')


# OPT48 hyperopt fixed-eyecandy closure checks
assert 'visual_store_beat_spark_chars_a:' in asm and 'visual_store_beat_ring_chars_a:' in asm, 'OPT48: direct-store spark/ring helpers missing'
assert 'visual_store_rail_chars_a:' in asm and 'visual_store_corner_chars_a:' in asm, 'OPT48: direct-store rail/corner helpers missing'
assert 'beat_spark_char_lut:' in asm and 'beat_spark_color_lut:' in asm, 'OPT48: drum style LUTs missing'
assert 'visual_beat_spark_loop:' not in asm and 'visual_beat_ring_loop:' not in asm, 'OPT48: looped spark/ring plotters must stay removed'
assert 'visual_plot_all_beat_sparks:' not in asm and 'visual_plot_all_beat_rings:' not in asm, 'OPT48: old table-driven spark/ring plotters must stay removed'
assert 'beat_spark_x:' not in asm and 'beat_ring_x:' not in asm, 'OPT48: old fixed coordinate tables should be compiled out after direct-store conversion'
assert 'visual_rail_loop:' not in asm and 'eyecandy_rows:' not in asm, 'OPT48: looped side-rail plotter must stay removed'
# Ensure direct eyecandy stores are all within safe screen/color areas and do not hit row 0.
for m in re.finditer(r'sta \$(0[4-7][0-9a-f]{2}|d[89ab][0-9a-f]{2})', asm.lower()):
    addr=int(m.group(1),16)
    off = addr-0x0400 if addr < 0xd800 else addr-0xd800
    if 0 <= off < 1000:
        y=off//40; x=off%40
        assert 1 <= y <= 24 and 0 <= x < 40, f'OPT48: direct eyecandy store outside safe screen row/col at ${addr:04x}'
print('OPT48 hyperopt fixed-eyecandy audit: PASS')


# OPT49 final hyper-plot closure checks
assert 'OPT49: cube/tail plot path calculates address once' in asm, 'OPT49 release marker missing'
assert 'visual_calc_color_addr:' not in asm, 'OPT49: redundant color helper returned'
plot_block=asm.split('visual_plot:',1)[1].split('visual_calc_screen_addr:',1)[0]
assert plot_block.count('jsr visual_calc_screen_addr')==1, 'OPT49: visual_plot must do exactly one bounds/address calc'
assert 'jsr visual_calc_color_addr' not in plot_block, 'OPT49: visual_plot must not recalc color address'
assert 'adc #$d4' in plot_block, 'OPT49: visual_plot must derive color high byte from screen high byte'
tail_block=asm.split('visual_plot_tail_cell:',1)[1].split('visual_erase_previous_cube:',1)[0]
assert tail_block.count('jsr visual_calc_screen_addr')==1, 'OPT49: tail plot must do exactly one bounds/address calc'
assert 'jsr visual_calc_color_addr' not in tail_block, 'OPT49: tail plot must not recalc color address'
assert 'adc #$d4' in tail_block, 'OPT49: tail plot must derive color high byte from screen high byte'
print('OPT49 single-address plot closure audit: PASS')


# OPT50 beat-pump grow/shrink closure checks
assert ('EURO PULSEGRID FIX20 / OPT50 BEAT PUMP ZOOM CLOSURE' in asm) or ('EURO PULSEGRID FIX20 / OPT57 FINAL AUDIT CLEANUP' in asm) or ('C64 ASC UBERCUBE' in asm), 'OPT50/OPT57/release title missing'
scale_block=asm.split('visual_update_beat_scale:',1)[1].split('visual_pick_style:',1)[0]
assert 'drum_visual_type' not in scale_block and 'visual_scale_candidate' not in scale_block, 'OPT50: visual_update_beat_scale must not re-pin zoom from drum state every frame'
assert scale_block.count('dec cube_scale_env')==1, 'OPT50: zoom envelope must decay exactly once per visual frame'
for lab,val in [('drum_kick:','#$20'),('drum_snare:','#$12'),('drum_hat:','#$07'),('drum_crash:','#$24'),('drum_lift:','#$18'),('drum_pshhh:','#$0c')]:
    block=asm.split(lab,1)[1].split('        rts',1)[0]
    assert val in block and 'sta cube_scale_env' in block, f'OPT50: {lab} must seed beat-pump zoom with {val}'
draw_block=asm.split('visual_draw_cube:',1)[1].split('visual_frame_selected:',1)[0]
assert 'adc #16' in asm.split('visual_frame_zoom_in:',1)[1].split('visual_frame_selected:',1)[0], 'OPT50: high envelope must select zoom-in frame bank'
assert 'adc #32' in draw_block, 'OPT50: late envelope must select zoom-out/smaller frame bank'
assert 'cmp #$12' in draw_block and 'cmp #$0a' in draw_block, 'OPT50: grow/shrink thresholds missing'
print('OPT50 beat-pump grow/shrink audit: PASS')

# OPT51 top-section SPACE effect closure checks
assert 'OPT51 TOP-SECTION SPACE EFFECT' in asm, 'OPT51 title missing'
assert 'TOP_SECTION_COUNT = 10' in asm and 'top_section_lo:' in asm and 'top_section_hi:' in asm, 'OPT51 top-section table/count missing'
assert 'top_section_index:' in asm, 'OPT51 top_section_index variable missing'
init_block=asm.split('sound_init:',1)[1].split('play:',1)[0]
assert 'sta top_section_index' in init_block, 'OPT51 top_section_index must be initialized'
skip_block=asm.split('skip_to_next_part:',1)[1].split('\nTOP_SECTION_COUNT',1)[0]
for marker in ['inc top_section_index','cmp #TOP_SECTION_COUNT','top_section_lo,x','top_section_hi,x','sta ORD_PTR','sta ORD_PTR+1']:
    assert marker in skip_block, f'OPT51 explicit top-section cycle missing marker: {marker}'
assert 'sta cube_scale_env' in skip_block and 'sta beat_pulse_env' in skip_block and 'sta drum_visual_type' in skip_block, 'OPT51 SPACE jump must trigger a bounded visual effect'
assert 'jsr visual_cycle_effect_tail_swap' in skip_block, 'OPT51 SPACE jump must still cycle effect/tail mode'
play_block=asm.split('play:',1)[1].split('next_step:',1)[0]
for fx in ['jsr fx_kick','jsr fx_filter','jsr fx_pwm','jsr fx_lead','jsr fx_bass','jsr fx_drum_visual_decay']:
    assert play_block.count(fx)==1, f'OPT51 cleanup: duplicate or missing {fx}'
assert 'sta prev_tail_index2\n        sta prev_tail_index2' not in asm, 'OPT51 cleanup: duplicate prev_tail_index2 init returned'
print('OPT51 top-section SPACE effect audit: PASS')


# OPT52 lead-reactive visuals checks
assert 'OPT52 LEAD-REACTIVE VISUALS' in asm, 'OPT52 title missing'
for marker in ['lead_visual_env:', 'lead_visual_type:', 'lead_visual_decay:', 'visual_style_lead_chorus:', 'visual_pick_lead_chorus_spark:', 'visual_eyecandy_check_lead:']:
    assert marker in asm, f'OPT52 marker missing: {marker}'
trig_lead_block=asm.split('trig_lead:',1)[1].split('trig_lead_off:',1)[0]
for marker in ['sta lead_visual_env','sta lead_visual_type','sta beat_pulse_env','sta cube_scale_env']:
    assert marker in trig_lead_block, f'OPT52 lead trigger missing visual seed: {marker}'
play_block=asm.split('play:',1)[1].split('next_step:',1)[0]
assert 'jsr lead_visual_decay' in play_block, 'OPT52 lead visual decay must run from play path'
style_block=asm.split('visual_style_no_drum:',1)[1].split('; OPT25:',1)[0]
assert 'lda lead_visual_env' in style_block and 'sta vis_char' in style_block and 'sta vis_color' in style_block, 'OPT52 lead must affect cube glyph/color when no drum override is active'
spark_block=asm.split('visual_pick_beat_spark_style:',1)[1].split('beat_spark_char_lut:',1)[0]
assert 'lda lead_visual_env' in spark_block and 'sta beat_spark_char' in spark_block and 'sta beat_spark_color' in spark_block, 'OPT52 lead must affect spark/ring style when no drum override is active'
eye_block=asm.split('visual_eyecandy_check_lead:',1)[1].split('visual_store_rail_chars_a:',1)[0]
assert 'lda lead_visual_env' in eye_block and 'sta eyecandy_char' in eye_block and 'sta eyecandy_color' in eye_block, 'OPT52 lead must affect panel eyecandy when no drum override is active'
skip_block=asm.split('skip_apply:',1)[1].split('\nTOP_SECTION_COUNT',1)[0]
assert 'sta lead_visual_env' in skip_block and 'sta lead_visual_type' in skip_block, 'OPT52 section skip must clear lead visual state'
print('OPT52 lead-reactive visual audit: PASS')

# OPT53 SPACE section/effect/music jump closure checks
assert 'OPT53 SPACE SECTION-EFFECT-MUSIC JUMP' in asm, 'OPT53 title missing'
for marker in ['music_jump_mode:', 'music_jump_env:', 'space_cycle_music_mode:', 'space_apply_music_transition:', 'space_music_kick:', 'space_music_crash:', 'space_music_pshhh:', 'space_music_snare:']:
    assert marker in asm, f'OPT53 marker missing: {marker}'
init_block=asm.split('sound_init:',1)[1].split('play:',1)[0]
assert 'sta music_jump_mode' in init_block and 'sta music_jump_env' in init_block, 'OPT53 music jump state must initialize to zero'
skip_block=asm.split('skip_apply:',1)[1].split('\nTOP_SECTION_COUNT',1)[0]
for marker in ['jsr visual_cycle_effect_tail_swap','jsr space_cycle_music_mode','jsr next_order','jsr next_step','jsr space_apply_music_transition']:
    assert marker in skip_block, f'OPT53 skip apply missing marker: {marker}'
cycle_block=asm.split('space_cycle_music_mode:',1)[1].split('space_apply_music_transition:',1)[0]
assert 'inc music_jump_mode' in cycle_block and 'and #$03' in cycle_block and 'sta music_jump_mode' in cycle_block, 'OPT53 music mode must be bounded 0..3'
trans_block=asm.split('space_apply_music_transition:',1)[1].split('visual_cycle_effect_tail_swap:',1)[0]
for marker in ['sta music_jump_env','sta cube_scale_env','sta beat_pulse_env','sta drum_visual_type','sta drum_visual_env']:
    assert marker in trans_block, f'OPT53 transition must seed {marker}'
scan_block=asm.split('scan_space_skip:',1)[1].split('skip_to_next_part:',1)[0]
assert 'sta skip_request' in scan_block and 'jsr space_apply_music_transition' not in scan_block, 'OPT53 scanner must only request, not apply music jump'
print('OPT53 SPACE section/effect/music jump audit: PASS')
print('OPT54 SPACE keyboard matrix fix audit: PASS')

# OPT55: SPACE jump must return immediately after skip_to_next_part so old
# frame_cnt cannot advance the freshly loaded section in the same IRQ tick.
required_opt55 = "jsr skip_to_next_part\n        rts"
if required_opt55 not in asm:
    raise AssertionError("OPT55: play must RTS immediately after skip_to_next_part")
print("OPT55 SPACE jump consumes whole IRQ tick audit: PASS")

# OPT56 live section sync closure checks
assert 'OPT56 SPACE LIVE-SYNC FINAL CLOSURE' in asm, 'OPT56 title missing'
assert 'sync_top_section_index_from_order:' in asm, 'OPT56 sync routine missing'
next_order_block=asm.split('next_order_read:',1)[1].split('trig_bass:',1)[0]
for marker in ['sta skip_target_lo','sta skip_target_hi','jsr sync_top_section_index_from_order']:
    assert marker in next_order_block, f'OPT56 next_order must capture/sync live section marker: {marker}'
sync_block=asm.split('sync_top_section_index_from_order:',1)[1].split('trig_bass:',1)[0]
for marker in ['top_section_lo,x','top_section_hi,x','stx top_section_index','cpx #TOP_SECTION_COUNT']:
    assert marker in sync_block, f'OPT56 sync routine missing marker: {marker}'
skip_block=asm.split('skip_to_next_part:',1)[1].split('skip_apply:',1)[0]
assert 'inc top_section_index' in skip_block and 'cmp #TOP_SECTION_COUNT' in skip_block, 'OPT56 SPACE jump must still advance from synchronized index'
print('OPT56 live top-section sync closure audit: PASS')


# OPT57 final audit cleanup checks
assert 'visual_clamp_cube_index_x:' in asm and 'cpx #48' in asm, 'OPT57: cube frame index clamp missing'
for block_name in ['visual_erase_cube_index_a:', 'visual_draw_tail_index_a:', 'visual_erase_have_previous:', 'visual_frame_selected:']:
    assert block_name in asm, f'OPT57: missing block {block_name}'
    block = asm.split(block_name,1)[1].split('\n\n',1)[0]
    assert 'visual_clamp_cube_index_x' in block, f'OPT57: {block_name} must clamp cube-frame index before table lookup/store'
assert 'jsr fx_music_jump_decay' in play_block and 'fx_music_jump_decay:' in asm and 'dec music_jump_env' in asm, 'OPT57: music_jump_env must be actively decayed or removed'
assert 'clear exactly visible 1000 bytes' in asm and 'cpx #$e8' in asm, 'OPT57: clear routine must explicitly document 1000 visible bytes and preserve sprite pointers'
print('OPT57 final audit cleanup audit: PASS')

# OPT58 100% closure checks
assert 'OPT58' in asm, 'OPT58 marker missing from source comments'
spark_block = asm.split('visual_pick_beat_spark_from_lut:',1)[1].split('visual_store_beat_spark_chars_a:',1)[0]
assert 'cpx #7' in spark_block and 'ldx #0' in spark_block, 'OPT58: beat spark LUT index must be clamped to 0..6'
eyecandy_block = asm.split('visual_eyecandy_not_chorus:',1)[1].split('visual_eyecandy_check_lead:',1)[0]
assert 'cpx #7' in eyecandy_block and 'ldx #0' in eyecandy_block, 'OPT58: panel eyecandy LUT index must be clamped to 0..6'
assert 'beat_spark_char_lut:' in asm and 'beat_spark_color_lut:' in asm, 'OPT58: beat spark LUTs missing'
print('OPT58 100% closure audit: PASS')

# OPT59 beat-spin bidirectional cube checks
assert 'OPT59 BEAT-SPIN BIDIRECTIONAL CUBE' in asm, 'OPT59 title missing'
for marker in ['cube_spin_env:', 'cube_spin_dir:', 'cube_spin_step:', 'visual_advance_cube_spin:', 'visual_spin_reverse:', 'visual_trigger_spin_forward_fast:', 'visual_trigger_spin_reverse_snap:']:
    assert marker in asm, f'OPT59 marker missing: {marker}'
init_block=asm.split('sound_init:',1)[1].split('play:',1)[0]
for marker in ['sta cube_spin_env','sta cube_spin_dir','sta cube_spin_step']:
    assert marker in init_block, f'OPT59 spin state must initialize: {marker}'
visual_block=asm.split('visual_update:',1)[1].split('visual_no_full_clear_request:',1)[0]
assert 'jsr visual_advance_cube_spin' in visual_block, 'OPT59 visual_update must advance rotation through beat-spin routine'
assert 'inc vis_frame' not in visual_block, 'OPT59 visual_update must not hard-code one-way inc before beat-spin routine'
spin_block=asm.split('visual_advance_cube_spin:',1)[1].split('visual_update_beat_scale:',1)[0]
for marker in ['adc cube_spin_step','sbc cube_spin_step','and #$0f','dec cube_spin_env']:
    assert marker in spin_block, f'OPT59 spin routine missing marker: {marker}'
for lab in ['drum_kick:', 'drum_lift:', 'space_music_kick:']:
    block=asm.split(lab,1)[1].split('        rts',1)[0]
    assert 'visual_trigger_spin_forward_fast' in block, f'OPT59 {lab} must trigger forward spin'
for lab in ['drum_snare:', 'space_music_snare:']:
    block=asm.split(lab,1)[1].split('        rts',1)[0]
    assert 'visual_trigger_spin_reverse_snap' in block, f'OPT59 {lab} must trigger reverse spin'
for lab in ['drum_hat:', 'drum_pshhh:', 'space_music_pshhh:']:
    block=asm.split(lab,1)[1].split('        rts',1)[0]
    assert 'sta cube_spin_dir' in block and 'sta cube_spin_env' in block, f'OPT59 {lab} must seed spin state'
skip_block=asm.split('skip_apply:',1)[1].split('\nTOP_SECTION_COUNT',1)[0]
for marker in ['sta cube_spin_env','sta cube_spin_dir','sta cube_spin_step']:
    assert marker in skip_block, f'OPT59 section skip must clear spin state: {marker}'
print('OPT59 beat-spin bidirectional cube audit: PASS')

# OPT60 beat-spin 100% closure checks
assert 'OPT60 BEAT-SPIN 100% CLOSURE' in asm, 'OPT60 title missing'
for marker in ['cube_spin_base_dir:', 'visual_spin_base_reverse:', 'visual_toggle_base_spin_dir:', 'visual_set_base_spin_forward:', 'visual_set_base_spin_reverse:']:
    assert marker in asm, f'OPT60 marker missing: {marker}'
init_block=asm.split('sound_init:',1)[1].split('play:',1)[0]
assert 'sta cube_spin_base_dir' in init_block, 'OPT60 base spin direction must initialize to forward/zero'
spin_block=asm.split('visual_advance_cube_spin:',1)[1].split('visual_update_beat_scale:',1)[0]
assert 'lda cube_spin_base_dir' in spin_block and 'visual_spin_base_reverse:' in spin_block and 'sbc #1' in spin_block, 'OPT60 base/idle spin must support reverse direction'
for lab in ['drum_crash:', 'space_music_crash:']:
    block=asm.split(lab,1)[1].split('        rts',1)[0]
    assert 'visual_toggle_base_spin_dir' in block, f'OPT60 {lab} must toggle persistent base spin direction'
for lab,marker in [('space_music_kick:','visual_set_base_spin_forward'),('space_music_snare:','visual_set_base_spin_reverse'),('space_music_pshhh:','visual_set_base_spin_reverse')]:
    block=asm.split(lab,1)[1].split('        rts',1)[0]
    assert marker in block, f'OPT60 {lab} must set persistent base spin direction with {marker}'
skip_block=asm.split('skip_apply:',1)[1].split('\nTOP_SECTION_COUNT',1)[0]
assert 'sta cube_spin_base_dir' in skip_block, 'OPT60 section skip must reset persistent base spin before transition preset applies'
print('OPT60 beat-spin 100% closure audit: PASS')


# OPT61 ACME branch-range closure checks
lead_entry = asm.split('trig_lead:',1)[1].split('trig_lead_note_in_range:',1)[0]
assert 'bne trig_lead_note_present' in lead_entry and 'jmp trig_lead_off' in lead_entry, 'OPT61: lead zero-note guard must use short branch + absolute JMP'
assert 'bcc trig_lead_note_in_range' in lead_entry and lead_entry.count('jmp trig_lead_off') >= 2, 'OPT61: lead high-note guard must use short branch + absolute JMP'
assert 'beq trig_lead_off' not in lead_entry and 'bcs trig_lead_off' not in lead_entry, 'OPT61: long relative branches to trig_lead_off must not return'
print('OPT61 ACME branch-range closure audit: PASS')


# OPT62 clean release checks
assert '!to "c64_asc_ubercube.prg",cbm' in asm, 'OPT62: output PRG name must be c64_asc_ubercube.prg'
assert 'C64 ASC UBERCUBE' in asm, 'OPT62: release title must be C64 ASC UBERCUBE'
for dead in ['skip_wrap_intro:', 'section_lo:', 'section_hi:', 'visual_trigger_spin_forward_slow:', 'visual_clamp_cube_index_a:']:
    assert not re.search(r'^'+re.escape(dead), asm, re.M), f'OPT62: obsolete dead code/label still present: {dead}'
print('OPT62 c64_asc_ubercube clean release audit: PASS')
