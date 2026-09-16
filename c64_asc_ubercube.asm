!cpu 6510
!to "c64_asc_ubercube.prg",cbm

; =====================================================================
; C64 ASC UBERCUBE / OPT62 RELEASE CLEANUP
; EURO PULSEGRID FIX20 / OPT61 BRANCH-RANGE CLOSURE / OPT60 BEAT-SPIN 100% CLOSURE / OPT59 BEAT-SPIN BIDIRECTIONAL CUBE / OPT58 100% CLOSURE / OPT57 FINAL AUDIT CLEANUP / OPT51 TOP-SECTION SPACE EFFECT / OPT52 LEAD-REACTIVE VISUALS / OPT53 SPACE SECTION-EFFECT-MUSIC JUMP / OPT56 SPACE LIVE-SYNC FINAL CLOSURE
; Commodore 64 / ACME assembler
; PAL 50Hz, 1:1 TRUE XYZ cube, SPACE jumps next section/effect/music/tail with safe closure.
; Audit fixes:
; - Correct $0314 KERNAL IRQ tail: JMP $EA31, no stack corruption.
; - Correct SID filter mode/routing in build sections: $D417=$33, $D418=$1F.
; - Correct 1000-byte screen/color clear without touching sprite pointers.
; - Carry-safe text plotting and beat dilation.
; - No out-of-range relative branches in long paths.
; - OPT41: saturating frame_tick counter, robust 50Hz visual sync, final SPACE-swap closure.
; - OPT43: SPACE swaps section + effect_mode + safe cube tail_mode.
; - OPT45: final tail/section/effect/beat-zoom closure; symmetric erase/draw + zoom audit.
; - OPT46: full drum beat-awareness: kick/snare/hat/crash/lift/pshhh zoom + safe spark eyecandy.
; - OPT47: adds bounded beat-ring eyecandy around the cube core, erased every frame.
; - OPT48: hyper-optimized fixed eyecandy: unrolled direct screen/color stores for sparks, rings and rails.
; - OPT50: beat-pump zoom envelope: cube grows/shrinks to drums without runtime scaling.
; - OPT59: beat-driven cube spin acceleration supports forward and reverse rotation.
; - OPT60: persistent base spin direction can run forward or reverse after beat/SPACE toggles.
; - OPT61: long lead-note guard branches converted to short branch + absolute JMP, ACME-safe.
; - OPT62: renamed clean release to c64_asc_ubercube and removed obsolete compatibility tables/helpers.
; - OPT53: SPACE jump now cycles section + visual effect + tail + music transition mode.
; - OPT56: top_section_index now follows natural song playback, so SPACE always jumps from the live current section.
; - OPT51: SPACE cycles top-level song sections and triggers a bounded section-jump effect.
; - OPT42: bounded 2-frame visual tick queue, release polish and dead-instruction cleanup.
; =====================================================================

V1F      = $d400
V1PW     = $d402
V1CTL    = $d404
V1AD     = $d405
V1SR     = $d406
V2F      = $d407
V2PW     = $d409
V2CTL    = $d40b
V2AD     = $d40c
V2SR     = $d40d
V3F      = $d40e
V3CTL    = $d412
V3AD     = $d413
V3SR     = $d414
FLO      = $d415
FHI      = $d416
FRES     = $d417
FMODE    = $d418

PAT_LEAD = $f7
ORD_PTR  = $f9
PAT_BASS = $fb
PAT_DRUM = $fd
VISUAL_PTR = $02
CUBE_PTR   = $04

SCREEN_RAM = $0400
COLOR_RAM  = $d800
STEPFRAMES = 5

* = $0801
        !byte $0c,$08,$0a,$00,$9e,$32,$30,$36,$34,$00,$00,$00
* = $0810

init:
        sei
        jsr tune_init
        jsr visual_init
        lda #$ff
        sta $dc02
        lda #$00
        sta $dc03
        lda #$ff
        sta $dc00
        lda #$7f
        sta $dc0d
        sta $dd0d
        lda $dc0d
        lda $dd0d
        lda #$01
        sta $d01a
        lda #$1b
        sta $d011
        lda #$00
        sta $d012
        lda #<irq
        sta $0314
        lda #>irq
        sta $0315
        lda #$01
        sta $d019
        cli
main_visual_loop:
        lda frame_tick
        beq main_visual_loop
        dec frame_tick          ; OPT41: consume exactly one queued IRQ tick
        jsr scan_space_skip
        jsr visual_update
        jmp main_visual_loop

; Called through KERNAL IRQ vector $0314.
; KERNAL has already saved A/X/Y; custom $0314 handlers must tail-call $EA31.
irq:
        lda #$01
        sta $d019
        jsr play
        lda frame_tick          ; OPT42: bounded tick queue, not lossy 0/1 flag
        cmp #$02                ; cap backlog to 2 visual frames: no runaway catch-up
        bcs irq_frame_tick_full
        inc frame_tick
irq_frame_tick_full:
        jmp $ea31

tune_init:
        jsr sound_init
        lda #<order
        sta ORD_PTR
        lda #>order
        sta ORD_PTR+1
        lda #0
        sta frame_cnt
        lda #$ff
        sta step
        jsr next_order
        jsr next_step
        rts

sound_init:
        lda #0
        ldx #0
sound_init_loop:
        sta $d400,x
        inx
        cpx #$19
        bne sound_init_loop
        lda #$0f
        sta FMODE
        lda #$00
        sta FRES
        lda #$09
        sta V1AD
        lda #$f8
        sta V1SR
        lda #$08
        sta V2AD
        lda #$f8
        sta V2SR
        lda #$02
        sta V3AD
        lda #$f2
        sta V3SR
        lda #0
        sta kick_env
        sta lead_env
        sta lead_visual_env
        sta lead_visual_type
        sta bass_env
        sta drum_env
        sta flt_lfo
        sta flt_cnt
        sta drum_visual_type
        sta drum_visual_env
        sta pwm_phase
        sta v2_gate_ctl
        sta v2_off_ctl
        sta v1_base_lo
        sta v1_base_hi
        sta v2_base_lo
        sta v2_base_hi
        sta song_flags
        sta space_latch
        sta skip_request
        sta top_section_index
        sta music_jump_mode
        sta music_jump_env
        sta frame_tick
        sta vis_frame
        sta vis_char
        sta vis_color
        sta shimmer_phase
        sta shimmer_mode
        sta pshhh_env
        sta sidechain_env
        sta bass_tail
        sta lead_tail
        sta legato_phase
        sta cube_scale_env
        sta cube_spin_env
        sta cube_spin_dir
        sta cube_spin_step
        sta cube_spin_base_dir
        sta cube_glow_env
        sta mix_glue_env
        sta visual_clear_request
        sta eyecandy_phase
        sta eyecandy_char
        sta eyecandy_color
        sta effect_mode
        sta tail_mode
        sta beat_pulse_env
        sta beat_spark_phase
        sta beat_spark_char
        sta beat_spark_color
        lda #$ff
        sta prev_cube_index
        sta prev_tail_index1
        sta prev_tail_index2
        rts

play:
        ; OPT34: apply SPACE section skip inside IRQ/play, not in main loop.
        ; This avoids racing ORD_PTR/PAT_* with the music engine.
        lda skip_request
        beq play_no_skip_request
        lda #0
        sta skip_request
        jsr skip_to_next_part
        rts                     ; OPT55: section/effect/music jump is a complete tick
                                ; do not also advance old frame_cnt in same IRQ
play_no_skip_request:
        inc frame_cnt
        lda frame_cnt
        cmp #STEPFRAMES
        bcc play_no_step
        lda #0
        sta frame_cnt
        jsr next_step
play_no_step:
        jsr fx_kick
        jsr fx_filter
        jsr fx_pwm
        jsr fx_lead
        jsr fx_bass
        jsr lead_visual_decay
        jsr fx_drum_visual_decay
        jsr fx_music_jump_decay
        rts

next_step:
        inc step
        lda step
        cmp #16
        bcc next_step_trig
        lda #0
        sta step
        jsr next_order
next_step_trig:
        jsr trig_bass
        jsr trig_drum
        jsr trig_lead
        rts

next_order:
        ldy #0
        lda (ORD_PTR),y
        cmp #$ff
        bne next_order_read
        lda #<order
        sta ORD_PTR
        lda #>order
        sta ORD_PTR+1
next_order_read:
        ; OPT56: remember the actual order entry being loaded before ORD_PTR
        ; advances. If this entry is a top-section boundary, synchronize
        ; top_section_index so SPACE jumps from the live song position, not
        ; merely from the last SPACE press.
        lda ORD_PTR
        sta skip_target_lo
        lda ORD_PTR+1
        sta skip_target_hi
        jsr sync_top_section_index_from_order
        ldy #0
        lda (ORD_PTR),y
        tay
        lda bpat_lo,y
        sta PAT_BASS
        lda bpat_hi,y
        sta PAT_BASS+1
        ldy #1
        lda (ORD_PTR),y
        tay
        lda dpat_lo,y
        sta PAT_DRUM
        lda dpat_hi,y
        sta PAT_DRUM+1
        ldy #2
        lda (ORD_PTR),y
        tay
        lda lpat_lo,y
        sta PAT_LEAD
        lda lpat_hi,y
        sta PAT_LEAD+1
        ldy #3
        lda (ORD_PTR),y
        sta song_flags
        clc
        lda ORD_PTR
        adc #4
        sta ORD_PTR
        lda ORD_PTR+1
        adc #0
        sta ORD_PTR+1
        rts

; OPT56: keep SPACE top-section jump aligned with natural playback.
; Called from next_order_read while skip_target_lo/hi still contain the
; exact order-entry pointer being loaded. If it is one of the top-level
; section starts, top_section_index is synchronized to that live section.
sync_top_section_index_from_order:
        ldx #0
sync_top_section_loop:
        lda top_section_lo,x
        cmp skip_target_lo
        bne sync_top_section_next
        lda top_section_hi,x
        cmp skip_target_hi
        bne sync_top_section_next
        stx top_section_index
        rts
sync_top_section_next:
        inx
        cpx #TOP_SECTION_COUNT
        bne sync_top_section_loop
        rts

trig_bass:
        ldy step
        lda (PAT_BASS),y
        beq trig_bass_off
        cmp #97              ; OPT37: corrupt-pattern guard, freq table has 96 notes
        bcs trig_bass_off
        tax
        dex
        lda freqlo,x
        sta V1F
        sta v1_base_lo
        lda freqhi,x
        sta V1F+1
        sta v1_base_hi
        lda #$12
        sta bass_env
        lda #$06
        sta bass_tail
        lda #$41
        sta V1CTL
        rts
trig_bass_off:
        lda bass_tail
        beq trig_bass_really_off
        dec bass_tail
        lda #$41
        sta V1CTL
        rts
trig_bass_really_off:
        lda #$40
        sta V1CTL
        rts

trig_lead:
        ldy step
        lda (PAT_LEAD),y
        bne trig_lead_note_present
        jmp trig_lead_off
trig_lead_note_present:
        cmp #97              ; OPT37: corrupt-pattern guard, freq table has 96 notes
        bcc trig_lead_note_in_range
        jmp trig_lead_off
trig_lead_note_in_range:
        tax
        dex
        lda freqlo,x
        sta V2F
        sta v2_base_lo
        lda freqhi,x
        sta V2F+1
        sta v2_base_hi
        lda #$18
        sta lead_env
        ; OPT52: lead-note reactive visual pulse. This is independent from
        ; drum_visual_type, so kicks still own the strongest beat zoom while
        ; lead notes add shimmer/colour/mini-zoom on melody hits.
        lda #$0c
        sta lead_visual_env
        lda #1
        sta lead_visual_type
        lda beat_pulse_env
        cmp #$06
        bcs trig_lead_beat_pulse_ok
        lda #$06
        sta beat_pulse_env
trig_lead_beat_pulse_ok:
        lda cube_scale_env
        cmp #$08
        bcs trig_lead_zoom_ok
        lda #$08
        sta cube_scale_env
trig_lead_zoom_ok:
        lda cube_spin_env
        cmp #$04
        bcs trig_lead_spin_ok
        lda song_flags
        and #$01
        beq trig_lead_spin_forward
        lda #1
        sta cube_spin_dir
        jmp trig_lead_spin_seed
trig_lead_spin_forward:
        lda #0
        sta cube_spin_dir
trig_lead_spin_seed:
        lda #1
        sta cube_spin_step
        lda #$04
        sta cube_spin_env
trig_lead_spin_ok:
        lda #$05
        sta lead_tail
        lda song_flags
        and #$01
        beq trig_lead_pulse
        lda #$23
        sta v2_gate_ctl
        lda #$22
        sta v2_off_ctl
        lda #1
        sta shimmer_mode
        lda #2
        sta lead_visual_type
        jmp trig_lead_gate
trig_lead_pulse:
        lda #$41
        sta v2_gate_ctl
        lda #$40
        sta v2_off_ctl
        lda #0
        sta shimmer_mode
trig_lead_gate:
        lda v2_gate_ctl
        sta V2CTL
        rts
trig_lead_off:
        lda lead_tail
        beq trig_lead_real_off
        dec lead_tail
        lda v2_gate_ctl
        beq trig_lead_tail_default
        sta V2CTL
        rts
trig_lead_tail_default:
        lda #$41
        sta V2CTL
        rts
trig_lead_real_off:
        lda v2_off_ctl
        beq trig_lead_off_default
        sta V2CTL
        rts
trig_lead_off_default:
        lda #$40
        sta V2CTL
        rts

trig_drum:
        ldy step
        lda (PAT_DRUM),y
        beq trig_drum_none
        cmp #1
        bne trig_drum_not_kick
        jmp drum_kick
trig_drum_not_kick:
        cmp #2
        bne trig_drum_not_snare
        jmp drum_snare
trig_drum_not_snare:
        cmp #3
        bne trig_drum_not_hat
        jmp drum_hat
trig_drum_not_hat:
        cmp #4
        bne trig_drum_not_crash
        jmp drum_crash
trig_drum_not_crash:
        cmp #5
        bne trig_drum_not_lift
        jmp drum_lift
trig_drum_not_lift:
        cmp #6
        bne trig_drum_none
        jmp drum_pshhh
trig_drum_none:
        rts

sid_drum_hard_silence:
        ; OPT36: deterministic V3 cleanup for section skips and retriggers.
        lda #$08              ; TEST, gate off
        sta V3CTL
        lda #$00
        sta V3CTL
        lda #0
        sta V3F
        sta V3F+1
        rts

drum_kick:
        jsr sid_drum_hard_silence
        lda #1
        sta drum_visual_type
        lda #$16
        sta drum_visual_env
        sta beat_pulse_env
        inc beat_spark_phase
        jsr visual_trigger_spin_forward_fast
        lda #$02
        sta V3AD
        lda #$f2
        sta V3SR
        lda #$1f
        sta kick_env
        lda #$16
        sta sidechain_env
        lda #$20              ; OPT50: strong trigger-only beat zoom pump
        sta cube_scale_env
        lda #$14
        sta cube_glow_env
        lda #$12
        sta mix_glue_env
        lda #$24
        sta drum_env
        lda #0
        sta pshhh_env
        lda #$08
        sta V3CTL
        lda #$00
        sta V3F
        lda #$0c
        sta V3F+1
        lda #$11
        sta V3CTL
        rts

drum_snare:
        jsr sid_drum_hard_silence
        lda #2
        sta drum_visual_type
        lda #$10
        sta drum_visual_env
        sta beat_pulse_env
        inc beat_spark_phase
        jsr visual_trigger_spin_reverse_snap
        lda #$12              ; OPT50: snare gives medium snap zoom
        sta cube_scale_env
        lda #$04
        sta V3AD
        lda #$84
        sta V3SR
        lda #0
        sta kick_env
        lda #$0a
        sta drum_env
        lda #$60
        sta V3F
        lda #$18
        sta V3F+1
        lda #$81
        sta V3CTL
        rts

drum_hat:
        jsr sid_drum_hard_silence
        lda #3
        sta drum_visual_type
        lda #$06
        sta drum_visual_env
        sta beat_pulse_env
        inc beat_spark_phase
        lda #1
        sta cube_spin_dir
        lda #1
        sta cube_spin_step
        lda #$04
        sta cube_spin_env
        lda #$07              ; OPT50: hat gives quick micro shrink/tick
        sta cube_scale_env
        lda #$02
        sta V3AD
        lda #$43
        sta V3SR
        lda #0
        sta kick_env
        lda #$04
        sta drum_env
        lda #$f8
        sta V3F
        lda #$2d
        sta V3F+1
        lda #$81
        sta V3CTL
        rts

drum_crash:
        jsr sid_drum_hard_silence
        lda #4
        sta drum_visual_type
        lda #$18
        sta drum_visual_env
        sta beat_pulse_env
        inc beat_spark_phase
        lda cube_spin_dir
        eor #1
        sta cube_spin_dir
        jsr visual_toggle_base_spin_dir
        lda #3
        sta cube_spin_step
        lda #$12
        sta cube_spin_env
        lda #$24              ; OPT50: crash gets maximum grow pulse
        sta cube_scale_env
        lda #$18
        sta cube_glow_env
        lda #$06
        sta V3AD
        lda #$34
        sta V3SR
        lda #0
        sta kick_env
        lda #$12
        sta drum_env
        lda #$0c
        sta pshhh_env
        lda #$ff
        sta V3F
        lda #$3f
        sta V3F+1
        lda #$81
        sta V3CTL
        rts

drum_lift:
        jsr sid_drum_hard_silence
        lda #5
        sta drum_visual_type
        lda #$14
        sta drum_visual_env
        sta beat_pulse_env
        inc beat_spark_phase
        jsr visual_trigger_spin_forward_fast
        lda #$18              ; OPT50: lift swells into beat
        sta cube_scale_env
        lda #$07
        sta V3AD
        lda #$24
        sta V3SR
        lda #0
        sta kick_env
        lda #$0c
        sta drum_env
        lda #$0a
        sta pshhh_env
        lda step
        asl
        asl
        ora #$40
        sta V3F
        lda #$2a
        sta V3F+1
        lda #$81
        sta V3CTL
        rts

drum_pshhh:
        jsr sid_drum_hard_silence
        lda #6
        sta drum_visual_type
        lda #$12
        sta drum_visual_env
        sta beat_pulse_env
        inc beat_spark_phase
        lda #1
        sta cube_spin_dir
        lda #1
        sta cube_spin_step
        lda #$08
        sta cube_spin_env
        lda #$0c              ; OPT50: pshhh uses soft rebound/shrink
        sta cube_scale_env
        lda #$10
        sta cube_glow_env
        lda #$08
        sta V3AD
        lda #$22
        sta V3SR
        lda #0
        sta kick_env
        lda #$08
        sta drum_env
        lda #$0c
        sta pshhh_env
        lda #$f0
        sta V3F
        lda #$38
        sta V3F+1
        lda #$81
        sta V3CTL
        rts

fx_drum_visual_decay:
        lda drum_visual_env
        beq fx_drum_visual_clear
        dec drum_visual_env
        jmp fx_beat_pulse_decay
fx_drum_visual_clear:
        lda #0
        sta drum_visual_type
fx_beat_pulse_decay:
        lda beat_pulse_env
        beq fx_beat_pulse_done
        dec beat_pulse_env
fx_beat_pulse_done:
        rts

fx_music_jump_decay:
        ; OPT57: music_jump_env is no longer dead state; it decays once per play tick.
        lda music_jump_env
        beq fx_music_jump_done
        dec music_jump_env
fx_music_jump_done:
        rts

fx_kick:
        lda kick_env
        beq fx_kick_pshhh
        dec kick_env
        lda kick_env
        asl
        asl
        clc
        adc #$18
        sta V3F
        lda #$08
        sta V3F+1
        rts
fx_kick_pshhh:
        lda pshhh_env
        beq fx_kick_drum_decay
        dec pshhh_env
        lda pshhh_env
        and #$01
        bne fx_pshhh_hold_gate
        lda pshhh_env
        asl
        asl
        ora #$40
        sta V3F
        lda pshhh_env
        lsr
        lsr
        clc
        adc #$18
        sta V3F+1
fx_pshhh_hold_gate:
        lda #$81
        sta V3CTL
        rts
fx_kick_drum_decay:
        lda drum_env
        beq fx_kick_off
        dec drum_env
        lda drum_env
        bne fx_kick_keep
fx_kick_off:
        lda #0
        sta pshhh_env
        sta drum_env
        lda #$00              ; OPT36: hard gate+wave off, avoids hanging noise
        sta V3CTL
fx_kick_keep:
        rts

; OPT34: real build-section SID filter. This is not a visual EQ/level meter;
; it is a musical SID low-pass tension sweep used only when song_flags bit1 is set.
fx_filter:
        lda song_flags
        and #$02
        beq fx_filter_raw
        lda song_flags
        and #$01
        bne fx_filter_raw       ; final chorus stays raw/loud
        inc flt_cnt
        lda flt_cnt
        and #$03
        bne fx_filter_build_store
        inc flt_lfo
fx_filter_build_store:
        lda flt_lfo
        asl
        clc
        adc #$30
        sta FHI                 ; cutoff high byte sweep
        lda flt_lfo
        and #$07
        sta FLO                 ; cutoff low 3 bits
        lda #$f3                ; resonance 15 + route voice 1+2
        sta FRES
        lda #$1f                ; low-pass + volume 15
        sta FMODE
        rts
fx_filter_raw:
        lda #$00
        sta FRES
        lda #$0f
        sta FMODE
        rts

fx_pwm:
        inc pwm_phase
        lda sidechain_env
        beq fx_pwm_no_pump_decay
        dec sidechain_env
fx_pwm_no_pump_decay:
        lda mix_glue_env
        beq fx_pwm_no_glue_decay
        dec mix_glue_env
fx_pwm_no_glue_decay:
        lda pwm_phase
        and #$7f
        clc
        adc #$20
        sta V1PW
        lda sidechain_env
        beq fx_pwm_bass_no_duck
        lda #$07
        jmp fx_pwm_bass_store_hi
fx_pwm_bass_no_duck:
        lda #$08
fx_pwm_bass_store_hi:
        sta V1PW+1
        lda pwm_phase
        asl
        eor pwm_phase
        clc
        adc legato_phase
        and #$7f
        clc
        adc #$50
        sta V2PW
        lda #$08
        sta V2PW+1
        inc legato_phase
        rts

fx_lead:
        lda v2_base_lo
        sta V2F
        lda v2_base_hi
        sta V2F+1
        lda lead_env
        beq fx_lead_done
        dec lead_env
        inc shimmer_phase
        lda shimmer_mode
        beq fx_lead_done
        lda shimmer_phase
        and #$07
        bne fx_lead_sync_saw
        lda #$15
        sta V2CTL
        rts
fx_lead_sync_saw:
        lda v2_gate_ctl
        sta V2CTL
fx_lead_done:
        rts

lead_visual_decay:
        lda lead_visual_env
        beq lead_visual_clear
        dec lead_visual_env
        rts
lead_visual_clear:
        lda #0
        sta lead_visual_type
        rts

fx_bass:
        lda v1_base_lo
        sta V1F
        lda v1_base_hi
        sta V1F+1
        lda bass_env
        beq fx_bass_sustain_sidechain
        dec bass_env
        lda bass_env
        asl
        asl
        clc
        adc #$24
        sta V1PW
        lda sidechain_env
        beq fx_bass_env_no_duck
        lda #$07
        jmp fx_bass_env_store_hi
fx_bass_env_no_duck:
        lda #$08
fx_bass_env_store_hi:
        sta V1PW+1
        rts
fx_bass_sustain_sidechain:
        lda sidechain_env
        beq fx_bass_done
        lda #$40
        sta V1PW
        lda #$07
        sta V1PW+1
fx_bass_done:
        rts

; =====================================================================
; OPT40 SPACE next part/section swap
; - Poll keyboard in main loop only.
; - SPACE is edge-detected: one press = exactly one next-section swap.
; - Small cooldown filters keyboard bounce so SPACE cannot double-jump.
; - Main loop only sets skip_request. The IRQ/play path consumes it safely
;   before advancing the music row, then clears panel/SID state.
; =====================================================================
scan_space_skip:
        lda skip_cooldown
        beq scan_space_scan
        dec skip_cooldown
scan_space_scan:
        ; FIX54: real C64 keyboard matrix SPACE = column 7 low, row bit 4 low.
        ; Previous OPT53 used column 4 / row 7 ($ef/$80), so SPACE never
        ; triggered on a real C64/Vice keyboard matrix.
        lda #$7f
        sta $dc00
        lda $dc01
        and #$10              ; bit clear = SPACE pressed
        bne scan_space_released
        lda space_latch
        bne scan_space_done
        lda #1
        sta space_latch
        lda skip_cooldown
        bne scan_space_done   ; debounce: latch press but do not jump twice
        lda #1
        sta skip_request      ; consumed inside play/IRQ, not here
        lda #$08
        sta skip_cooldown
        jmp scan_space_done
scan_space_released:
        lda #0
        sta space_latch
scan_space_done:
        lda #$ff
        sta $dc00
        rts

skip_to_next_part:
        ; OPT51: SPACE cycles explicit top-level sections, not merely the next
        ; order pointer after ORD_PTR. This makes SPACE useful live: intro ->
        ; verse -> build -> chorus -> verse2 -> build2 -> chorus2 -> break ->
        ; final -> outro -> intro. The actual pointer mutation still happens
        ; only inside play/IRQ via skip_request, so main-loop keyboard polling
        ; cannot race the music engine.
        inc top_section_index
        lda top_section_index
        cmp #TOP_SECTION_COUNT
        bcc skip_top_section_index_ok
        lda #0
        sta top_section_index
skip_top_section_index_ok:
        tax
        lda top_section_lo,x
        sta ORD_PTR
        lda top_section_hi,x
        sta ORD_PTR+1
        jmp skip_apply

skip_apply:
        jsr sid_drum_hard_silence
        ; OPT37: reset melodic gates on section jumps too. next_step immediately retriggers
        ; valid notes, but this prevents stale gate/sync/ring state during rapid SPACE skips.
        lda #$40
        sta V1CTL
        lda #$00
        sta V2CTL
        sta v2_gate_ctl
        sta v2_off_ctl
        jsr visual_cycle_effect_tail_swap
        jsr space_cycle_music_mode
        lda #$ff
        sta step
        lda #0
        sta frame_cnt
        sta kick_env
        sta drum_env
        sta pshhh_env
        sta sidechain_env
        sta bass_tail
        sta lead_tail
        sta lead_visual_env
        sta lead_visual_type
        sta drum_visual_env
        sta drum_visual_type
        sta beat_spark_char
        sta beat_spark_color
        sta cube_spin_env
        sta cube_spin_dir
        sta cube_spin_step
        sta cube_spin_base_dir
        sta skip_cooldown
        lda #$1e              ; OPT51: visible SPACE section-jump zoom punch
        sta cube_scale_env
        jsr visual_trigger_spin_forward_fast
        lda #$10              ; OPT51: bounded section-jump spark/ring envelope
        sta beat_pulse_env
        lda #$04              ; crash/star style for the transition effect
        sta drum_visual_type
        lda #$0c
        sta drum_visual_env
        lda #1
        sta visual_clear_request
        sta eyecandy_phase
        sta eyecandy_char
        sta eyecandy_color
        lda #$ff
        sta prev_cube_index
        sta prev_tail_index1
        sta prev_tail_index2
        jsr next_order
        jsr next_step
        jsr space_apply_music_transition
        rts

space_cycle_music_mode:
        ; OPT53: SPACE cycles a small musical transition preset as well as
        ; section/effect/tail. This is intentionally state-only until the
        ; new section has been loaded; space_apply_music_transition injects
        ; the short safe musical hit after next_order/next_step.
        inc music_jump_mode
        lda music_jump_mode
        and #$03
        sta music_jump_mode
        rts

space_apply_music_transition:
        ; OPT53: one-shot musical transition after SPACE section swap.
        ; Mode 0 = kick punch, 1 = crash, 2 = pshhh/lift, 3 = snare snap.
        lda #$08
        sta music_jump_env
        lda music_jump_mode
        and #$03
        beq space_music_kick
        cmp #1
        beq space_music_crash
        cmp #2
        beq space_music_pshhh
space_music_snare:
        jsr visual_set_base_spin_reverse
        jsr visual_trigger_spin_reverse_snap
        lda #$12
        sta cube_scale_env
        lda #$08
        sta beat_pulse_env
        lda #$02
        sta drum_visual_type
        lda #$08
        sta drum_visual_env
        rts
space_music_kick:
        jsr visual_set_base_spin_forward
        jsr visual_trigger_spin_forward_fast
        lda #$20
        sta cube_scale_env
        lda #$10
        sta beat_pulse_env
        lda #$01
        sta drum_visual_type
        lda #$0c
        sta drum_visual_env
        rts
space_music_crash:
        lda cube_spin_dir
        eor #1
        sta cube_spin_dir
        jsr visual_toggle_base_spin_dir
        lda #3
        sta cube_spin_step
        lda #$12
        sta cube_spin_env
        lda #$24
        sta cube_scale_env
        lda #$12
        sta beat_pulse_env
        lda #$04
        sta drum_visual_type
        lda #$0e
        sta drum_visual_env
        lda #$0c
        sta pshhh_env
        rts
space_music_pshhh:
        jsr visual_set_base_spin_reverse
        lda #1
        sta cube_spin_dir
        lda #1
        sta cube_spin_step
        lda #$08
        sta cube_spin_env
        lda #$18
        sta cube_scale_env
        lda #$0c
        sta beat_pulse_env
        lda #$05
        sta drum_visual_type
        lda #$0c
        sta drum_visual_env
        lda #$08
        sta pshhh_env
        rts

visual_cycle_effect_tail_swap:
        ; OPT44/OPT51: every SPACE top-section swap also advances a small
        ; visual preset and cube-tail mode. This is deliberately cheap,
        ; IRQ-safe, and forces a full visual clear so old tail/cube cells
        ; cannot ghost across sections/effects.
        inc effect_mode
        lda effect_mode
        and #$03
        sta effect_mode
        inc tail_mode
        lda tail_mode
        and #$03
        sta tail_mode
        lda #$ff
        sta prev_tail_index1
        sta prev_tail_index2
        lda #1
        sta visual_clear_request
        rts

TOP_SECTION_COUNT = 10

top_section_lo:
        !byte <order_intro,<order_verse1,<order_build1,<order_chorus1,<order_verse2
        !byte <order_build2,<order_chorus2,<order_break,<order_final,<order_outro
top_section_hi:
        !byte >order_intro,>order_verse1,>order_build1,>order_chorus1,>order_verse2
        !byte >order_build2,>order_chorus2,>order_break,>order_final,>order_outro


visual_init:
        lda #$1b
        sta $d011
        lda #$08
        sta $d016
        lda #$14
        sta $d018
        lda #0
        sta $d020
        sta $d021
        jsr visual_clear_screen
        rts

visual_update:
        ; OPT59: beat-driven bidirectional spin. Default is stable forward
        ; one-phase rotation; drum/lead/SPACE triggers can temporarily speed
        ; it up or reverse it while the frame index remains clamped to 0..15.
        jsr visual_advance_cube_spin
        jsr visual_update_beat_scale
        jsr visual_pick_style
        ; OPT36: if a section skip or explicit reset requested a clean panel,
        ; do one full safe screen clear before dirty-rendering resumes.
        lda visual_clear_request
        beq visual_no_full_clear_request
        lda #0
        sta visual_clear_request
        sta eyecandy_phase
        sta eyecandy_char
        sta eyecandy_color
        lda #$ff
        sta prev_cube_index
        sta prev_tail_index1
        sta prev_tail_index2
        jsr visual_clear_screen
visual_no_full_clear_request:
        ; OPT23: no top-line/border effect; keep VIC border/background stable.
        jsr visual_erase_previous_tails
        jsr visual_erase_previous_cube
        jsr visual_erase_beat_sparks
        jsr visual_erase_beat_rings
        jsr visual_draw_panel_eyecandy
        jsr visual_draw_beat_sparks
        jsr visual_draw_beat_rings
        jsr visual_draw_cube_tails
        jsr visual_draw_cube
        rts

visual_advance_cube_spin:
        lda cube_spin_env
        beq visual_spin_base_forward
        dec cube_spin_env
        lda cube_spin_step
        and #$03
        bne visual_spin_have_step
        lda #1
        sta cube_spin_step
visual_spin_have_step:
        lda cube_spin_dir
        and #$01
        bne visual_spin_reverse
visual_spin_forward:
        lda vis_frame
        clc
        adc cube_spin_step
        and #$0f
        sta vis_frame
        rts
visual_spin_reverse:
        lda vis_frame
        sec
        sbc cube_spin_step
        and #$0f
        sta vis_frame
        rts
visual_spin_base_forward:
        ; OPT60: even the base/idle cube spin can now run both ways.
        ; Beat envelopes still own temporary speed/direction above; when they
        ; decay, cube_spin_base_dir decides the stable rotation direction.
        lda cube_spin_base_dir
        and #$01
        bne visual_spin_base_reverse
        inc vis_frame
        lda vis_frame
        and #$0f
        sta vis_frame
        rts
visual_spin_base_reverse:
        lda vis_frame
        sec
        sbc #1
        and #$0f
        sta vis_frame
        rts

visual_trigger_spin_forward_fast:
        lda #0
        sta cube_spin_dir
        lda #2
        sta cube_spin_step
        lda #$0c
        sta cube_spin_env
        rts

visual_trigger_spin_reverse_snap:
        lda #1
        sta cube_spin_dir
        lda #2
        sta cube_spin_step
        lda #$08
        sta cube_spin_env
        rts


visual_toggle_base_spin_dir:
        ; OPT60: persistent direction toggle. Used by crash/SPACE to make
        ; the cube continue spinning the other way after the beat burst ends.
        lda cube_spin_base_dir
        eor #1
        and #1
        sta cube_spin_base_dir
        rts

visual_set_base_spin_forward:
        lda #0
        sta cube_spin_base_dir
        rts

visual_set_base_spin_reverse:
        lda #1
        sta cube_spin_base_dir
        rts

visual_update_beat_scale:
        ; OPT50: true beat-pump zoom. Drum triggers load cube_scale_env once;
        ; this routine only decays it. That gives visible grow -> normal ->
        ; smaller rebound instead of pinning the cube large while drum_visual_env
        ; is nonzero. Rotation phase remains strict 1:1 and zoom still uses
        ; precomputed frame banks, never runtime dilation.
visual_scale_decay:
        lda cube_scale_env
        beq visual_scale_glow_decay
        dec cube_scale_env
visual_scale_glow_decay:
        lda cube_glow_env
        beq visual_scale_done
        dec cube_glow_env
visual_scale_done:
        rts

visual_pick_style:
        lda #$2a
        sta vis_char
        lda #$01
        sta vis_color
        lda song_flags
        and #$01
        beq visual_not_chorus_style
        lda #$51
        sta vis_char
        lda #$07
        sta vis_color
        lda song_flags
        cmp #$03
        bne visual_not_chorus_style
        lda #$a0
        sta vis_char
        lda #$01
        sta vis_color
visual_not_chorus_style:
        lda song_flags
        and #$02
        beq visual_not_build_style
        lda song_flags
        and #$01
        bne visual_not_build_style
        lda #$2b
        sta vis_char
        lda #$0e
        sta vis_color
visual_not_build_style:
        ; OPT31: drum-sensitive cube style. This is deliberately cheap:
        ; only glyph/color/frame selection changes, never top-line or border.
        lda drum_visual_env
        beq visual_style_no_drum
        lda drum_visual_type
        cmp #1
        beq visual_style_kick
        cmp #2
        beq visual_style_snare
        cmp #3
        beq visual_style_hat
        cmp #4
        beq visual_style_crash
        cmp #5
        beq visual_style_lift
        cmp #6
        beq visual_style_pshhh
        jmp visual_style_no_drum
visual_style_kick:
        lda #$a0
        sta vis_char
        lda #$0a
        sta vis_color
        rts
visual_style_snare:
        lda #$2b
        sta vis_char
        lda #$01
        sta vis_color
        rts
visual_style_hat:
        lda #$2e
        sta vis_char
        lda #$03
        sta vis_color
        rts
visual_style_crash:
        lda #$2a
        sta vis_char
        lda #$01
        sta vis_color
        rts
visual_style_lift:
        lda #$51
        sta vis_char
        lda #$0e
        sta vis_color
        rts
visual_style_pshhh:
        lda #$2e
        sta vis_char
        lda #$0b
        sta vis_color
        rts
visual_style_no_drum:
        lda lead_visual_env
        beq visual_style_no_lead
        lda lead_visual_type
        cmp #2
        beq visual_style_lead_chorus
        lda #$2b              ; OPT52: lead hit = electric plus shimmer
        sta vis_char
        lda #$0d              ; light green lead sparkle
        sta vis_color
        rts
visual_style_lead_chorus:
        lda #$2a              ; chorus lead = star shimmer
        sta vis_char
        lda #$07              ; yellow euphoric lead
        sta vis_color
        rts
visual_style_no_lead:
        rts

; OPT25: top-line/border flash routine removed completely.
; OPT30: frame stream has a hard guard so malformed/missing $ff data can never hang.
; OPT31: drum-sensitive cube style/frame wobble, still no top-line/border writes.
; OPT32: fixed pointer-walk byte stride and added draw-loop stream guard.
; OPT33: lead patterns lowered by one octave and cube rotation cadence is fixed 1:1.
; OPT34: 50 Hz visual sync, IRQ-safe skip request, build filter, bounded 3D cube data.
; OPT36: strict cube bounds audit, section-skip full clear, and hard V3 drum cleanup.
; OPT38: safe panel eyecandy outside cube bounds, no top-line/border writes.
; OPT42: frame_tick is a bounded 0..2 counter; main loop DEC-consumes one visual frame.
; OPT43: SPACE cycles section + effect_mode + safe two-slot cube tail_mode.
; OPT46: fully beat-aware zoom and fixed-position drum spark eyecandy.
; OPT47: bounded beat-ring cells add extra beat eyecandy without dirty artifacts.
; OPT48: fixed spark/ring/rail/corner eyecandy uses unrolled direct stores, removing loop/index and address-calc JSR overhead.
; OPT52: lead voice is now visually beat-reactive: melody gates seed shimmer, mini-zoom, sparks and panel colour.
; OPT57: audit cleanup: documented 1000-byte visible clear, hard cube-index clamp, and active music_jump_env decay.
; OPT49: cube/tail plot path calculates address once and derives Color RAM pointer from Screen RAM high byte.

visual_clear_screen:
        lda #$20
        ldx #0
visual_clear_loop:
        ; OPT57: clear exactly visible 1000 bytes: 3 full pages + $e8 bytes.
        ; Do not clear $07e8-$07ff sprite pointers / non-visible tail.
        sta SCREEN_RAM,x
        sta SCREEN_RAM+$100,x
        sta SCREEN_RAM+$200,x
        cpx #$e8
        bcs visual_clear_skip_p3
        sta SCREEN_RAM+$300,x
visual_clear_skip_p3:
        inx
        bne visual_clear_loop
        lda #$01
        ldx #0
visual_color_loop:
        ; OPT57: same visible 1000-cell clear for Color RAM.
        sta COLOR_RAM,x
        sta COLOR_RAM+$100,x
        sta COLOR_RAM+$200,x
        cpx #$e8
        bcs visual_color_skip_p3
        sta COLOR_RAM+$300,x
visual_color_skip_p3:
        inx
        bne visual_color_loop
        rts



; OPT48: hyper-optimized fixed beat spark/ring eyecandy.
; Fixed coordinates are already audited, so this uses direct absolute stores
; instead of plot_x/plot_y + bounds-check + JSR for each cell.
visual_erase_beat_sparks:
        lda #$20
        jsr visual_store_beat_spark_chars_a
        lda #$01
        jsr visual_store_beat_spark_colors_a
        rts

visual_draw_beat_sparks:
        lda beat_pulse_env
        beq visual_draw_beat_sparks_done
        jsr visual_pick_beat_spark_style
        lda beat_spark_char
        jsr visual_store_beat_spark_chars_a
        lda beat_spark_color
        jsr visual_store_beat_spark_colors_a
visual_draw_beat_sparks_done:
        rts

visual_pick_beat_spark_style:
        ldx drum_visual_type
        bne visual_pick_beat_spark_from_lut
        lda lead_visual_env
        beq visual_pick_beat_spark_from_lut
        lda lead_visual_type
        cmp #2
        beq visual_pick_lead_chorus_spark
        lda #$2b
        sta beat_spark_char
        lda #$0d
        sta beat_spark_color
        rts
visual_pick_lead_chorus_spark:
        lda #$2a
        sta beat_spark_char
        lda #$07
        sta beat_spark_color
        rts
visual_pick_beat_spark_from_lut:
        ; OPT58: hard-clamp LUT index. Valid drum_visual_type is 0..6;
        ; corrupt/future values must never read past beat_spark_*_lut.
        cpx #7
        bcc visual_pick_beat_spark_lut_ok
        ldx #0
visual_pick_beat_spark_lut_ok:
        lda beat_spark_char_lut,x
        sta beat_spark_char
        lda beat_spark_color_lut,x
        sta beat_spark_color
        rts

visual_store_beat_spark_chars_a:
        sta $04cb
        sta $04ec
        sta $0544
        sta $0563
        sta $06ab
        sta $06cc
        sta $0724
        sta $0743
        rts

visual_store_beat_spark_colors_a:
        sta $d8cb
        sta $d8ec
        sta $d944
        sta $d963
        sta $daab
        sta $dacc
        sta $db24
        sta $db43
        rts

beat_spark_char_lut:
        !byte $2a,$a0,$2b,$2e,$2a,$51,$2e
beat_spark_color_lut:
        !byte $01,$0a,$01,$03,$01,$0e,$0b

; OPT48: direct-store beat rings. Same style LUT as sparks.
visual_erase_beat_rings:
        lda #$20
        jsr visual_store_beat_ring_chars_a
        lda #$01
        jsr visual_store_beat_ring_colors_a
        rts

visual_draw_beat_rings:
        lda beat_pulse_env
        beq visual_draw_beat_rings_done
        jsr visual_pick_beat_spark_style
        lda beat_spark_char
        jsr visual_store_beat_ring_chars_a
        lda beat_spark_color
        jsr visual_store_beat_ring_colors_a
visual_draw_beat_rings_done:
        rts

visual_store_beat_ring_chars_a:
        sta $04b2
        sta $04b3
        sta $04b4
        sta $04b5
        sta $0759
        sta $075e
        sta $0758
        sta $075f
        sta $04ff
        sta $0508
        sta $0706
        sta $0711
        rts

visual_store_beat_ring_colors_a:
        sta $d8b2
        sta $d8b3
        sta $d8b4
        sta $d8b5
        sta $db59
        sta $db5e
        sta $db58
        sta $db5f
        sta $d8ff
        sta $d908
        sta $db06
        sta $db11
        rts

; OPT38: safe eyecandy. Fixed side rails + corner sparkles outside the cube bounds.
; No top-line, no border writes, no dirty-state dependency, and no moving stale pixels.

visual_draw_panel_eyecandy:
        inc eyecandy_phase
        jsr visual_pick_eyecandy_style
        lda eyecandy_char
        jsr visual_store_rail_chars_a
        lda eyecandy_color
        jsr visual_store_rail_colors_a

        ; four fixed corner spark cells, flicker only by glyph/color, never by position
        lda eyecandy_phase
        and #$03
        bne visual_corner_plus
        lda #$2a
        jmp visual_corner_store_char
visual_corner_plus:
        lda #$2b
visual_corner_store_char:
        sta eyecandy_char
        lda eyecandy_char
        jsr visual_store_corner_chars_a
        lda eyecandy_color
        jsr visual_store_corner_colors_a
        rts

visual_pick_eyecandy_style:
        lda #$2e
        sta eyecandy_char
        lda #$0c
        sta eyecandy_color
        lda effect_mode
        beq visual_eyecandy_mode_done
        cmp #1
        bne visual_eyecandy_mode2
        lda #$2b
        sta eyecandy_char
        lda #$06
        sta eyecandy_color
        jmp visual_eyecandy_mode_done
visual_eyecandy_mode2:
        cmp #2
        bne visual_eyecandy_mode3
        lda #$51
        sta eyecandy_char
        lda #$0e
        sta eyecandy_color
        jmp visual_eyecandy_mode_done
visual_eyecandy_mode3:
        lda #$2a
        sta eyecandy_char
        lda #$07
        sta eyecandy_color
visual_eyecandy_mode_done:
        lda song_flags
        and #$02
        beq visual_eyecandy_not_build
        lda #$2b
        sta eyecandy_char
        lda #$0e
        sta eyecandy_color
visual_eyecandy_not_build:
        lda song_flags
        and #$01
        beq visual_eyecandy_not_chorus
        lda #$51
        sta eyecandy_char
        lda #$07
        sta eyecandy_color
visual_eyecandy_not_chorus:
        lda drum_visual_env
        beq visual_eyecandy_check_lead
        ldx drum_visual_type
        ; OPT58: same 0..6 clamp before fixed eyecandy LUT lookup.
        cpx #7
        bcc visual_eyecandy_drum_lut_ok
        ldx #0
visual_eyecandy_drum_lut_ok:
        lda beat_spark_char_lut,x
        sta eyecandy_char
        lda beat_spark_color_lut,x
        sta eyecandy_color
        rts
visual_eyecandy_check_lead:
        lda lead_visual_env
        beq visual_eyecandy_done
        lda lead_visual_type
        cmp #2
        beq visual_eyecandy_lead_chorus
        lda #$2b
        sta eyecandy_char
        lda #$0d
        sta eyecandy_color
        rts
visual_eyecandy_lead_chorus:
        lda #$2a
        sta eyecandy_char
        lda #$07
        sta eyecandy_color
visual_eyecandy_done:
        rts

visual_store_rail_chars_a:
        sta $04a2
        sta $051a
        sta $0592
        sta $060a
        sta $0682
        sta $06fa
        sta $0772
        sta $04c5
        sta $053d
        sta $05b5
        sta $062d
        sta $06a5
        sta $071d
        sta $0795
        rts

visual_store_rail_colors_a:
        sta $d8a2
        sta $d91a
        sta $d992
        sta $da0a
        sta $da82
        sta $dafa
        sta $db72
        sta $d8c5
        sta $d93d
        sta $d9b5
        sta $da2d
        sta $daa5
        sta $db1d
        sta $db95
        rts

visual_store_corner_chars_a:
        sta $047d
        sta $049a
        sta $0775
        sta $0792
        rts

visual_store_corner_colors_a:
        sta $d87d
        sta $d89a
        sta $db75
        sta $db92
        rts

; OPT21: Removed legacy heavy visual effects here:
; - VU/level meter
; - sparkle top strip
; - glam side columns
; - starfield
; - heavy cube shadow/depth duplicate
; OPT43 restores a *safe* minimal cube-tail mode with its own erase slots.

visual_erase_previous_tails:
        lda prev_tail_index1
        cmp #$ff
        beq visual_erase_tail2_check
        jsr visual_erase_cube_index_a
visual_erase_tail2_check:
        lda prev_tail_index2
        cmp #$ff
        beq visual_erase_tails_done
        jsr visual_erase_cube_index_a
visual_erase_tails_done:
        lda #$ff
        sta prev_tail_index1
        sta prev_tail_index2
        rts

visual_clamp_cube_index_x:
        ; OPT57: hard clamp all cube-frame table indices to 0..47.
        ; Future effect banks or corrupt state cannot overrun cube_frame_lo/hi.
        cpx #48
        bcc visual_clamp_cube_index_ok
        ldx #0
visual_clamp_cube_index_ok:
        rts


visual_erase_cube_index_a:
        tax
        jsr visual_clamp_cube_index_x
        lda cube_frame_lo,x
        sta CUBE_PTR
        lda cube_frame_hi,x
        sta CUBE_PTR+1
        lda #$c8
        sta cube_stream_guard
visual_erase_index_loop:
        lda cube_stream_guard
        beq visual_erase_index_done
        dec cube_stream_guard
        ldy #0
        lda (CUBE_PTR),y
        cmp #$ff
        beq visual_erase_index_done
        sta plot_x
        jsr visual_cube_ptr_inc
        ldy #0
        lda (CUBE_PTR),y
        sta plot_y
        jsr visual_cube_ptr_inc
        jsr visual_erase_plot
        jmp visual_erase_index_loop
visual_erase_index_done:
        rts

visual_draw_cube_tails:
        lda tail_mode
        beq visual_draw_tails_none
        lda vis_frame
        sec
        sbc #1
        and #$0f
        tax
        stx prev_tail_index1
        lda tail_mode
        cmp #3
        bne visual_tail1_only
        txa
        sec
        sbc #1
        and #$0f
        sta prev_tail_index2
visual_tail1_only:
        lda prev_tail_index1
        jsr visual_draw_tail_index_a
        lda prev_tail_index2
        cmp #$ff
        beq visual_draw_tails_done
        jsr visual_draw_tail_index_a
visual_draw_tails_done:
        rts
visual_draw_tails_none:
        lda #$ff
        sta prev_tail_index1
        sta prev_tail_index2
        rts

visual_draw_tail_index_a:
        tax
        jsr visual_clamp_cube_index_x
        lda cube_frame_lo,x
        sta CUBE_PTR
        lda cube_frame_hi,x
        sta CUBE_PTR+1
        lda #$c8
        sta cube_stream_guard
visual_tail_draw_loop:
        lda cube_stream_guard
        beq visual_tail_draw_done
        dec cube_stream_guard
        ldy #0
        lda (CUBE_PTR),y
        cmp #$ff
        beq visual_tail_draw_done
        sta plot_x
        jsr visual_cube_ptr_inc
        ldy #0
        lda (CUBE_PTR),y
        sta plot_y
        jsr visual_cube_ptr_inc
        jsr visual_plot_tail_cell
        jmp visual_tail_draw_loop
visual_tail_draw_done:
        rts

visual_plot_tail_cell:
        ; OPT49: calculate bounds/address once. Color RAM has the same low
        ; offset as screen RAM, high byte = screen high + $d4 ($04->$d8).
        jsr visual_calc_screen_addr
        bcs visual_tail_cell_done
        ldy #0
        lda tail_mode
        cmp #2
        bcc visual_tail_dot
        lda #$2b
        jmp visual_tail_store_char
visual_tail_dot:
        lda #$2e
visual_tail_store_char:
        sta (VISUAL_PTR),y
        lda VISUAL_PTR+1
        clc
        adc #$d4
        sta VISUAL_PTR+1
        lda effect_mode
        beq visual_tail_color_dim
        cmp #1
        bne visual_tail_color_mode2
        lda #$06
        jmp visual_tail_color_store
visual_tail_color_mode2:
        cmp #2
        bne visual_tail_color_mode3
        lda #$0b
        jmp visual_tail_color_store
visual_tail_color_mode3:
        lda #$07
        jmp visual_tail_color_store
visual_tail_color_dim:
        lda #$0c
visual_tail_color_store:
        sta (VISUAL_PTR),y
visual_tail_cell_done:
        rts

visual_erase_previous_cube:
        lda prev_cube_index
        cmp #$ff
        bne visual_erase_have_previous
        rts
visual_erase_have_previous:
        tax
        jsr visual_clamp_cube_index_x
        lda cube_frame_lo,x
        sta CUBE_PTR
        lda cube_frame_hi,x
        sta CUBE_PTR+1
        lda #$c8                 ; OPT34: hard stream guard, max 200 XY pairs
        sta cube_stream_guard
visual_erase_loop:
        lda cube_stream_guard
        beq visual_erase_done
        dec cube_stream_guard
        ; OPT29: pointer-walk frame stream. Do NOT use Y as a long
        ; byte offset: several true-XYZ pulsed frames are >255 bytes,
        ; and indexed sentinel scanning wraps Y and freezes on first beat.
        ldy #0
        lda (CUBE_PTR),y
        cmp #$ff
        beq visual_erase_done
        sta plot_x
        jsr visual_cube_ptr_inc
        ldy #0
        lda (CUBE_PTR),y
        sta plot_y
        jsr visual_cube_ptr_inc
        jsr visual_erase_plot
        jmp visual_erase_loop
visual_erase_done:
        rts

visual_erase_plot:
        ; OPT28: erase only the real XYZ raster point. Runtime dilation was
        ; removed because first beat could overload the frame budget.
        jsr visual_calc_screen_addr
        bcs visual_erase_done_plot
        ldy #0
        lda #$20
        sta (VISUAL_PTR),y
visual_erase_done_plot:
        rts

visual_draw_cube:
        lda vis_frame
        tax
        ; OPT45: beat zoom in/out using precomputed frame banks.
        ; High zoom envelope selects precomputed pulsed frames (+16 = zoom in).
        ; Late decay selects precomputed rebound frames (+32 = zoom out).
        ; This keeps 1:1 rotation while apparent cube size breathes on drums.
        lda cube_scale_env
        cmp #$12              ; OPT50: early envelope = grow/zoom-in
        bcs visual_frame_zoom_in
        cmp #$04              ; envelope nearly gone = back to normal
        bcc visual_frame_normal
        cmp #$0a              ; late envelope = smaller rebound/zoom-out
        bcs visual_frame_normal
        txa
        clc
        adc #32
        tax
        jmp visual_frame_selected
visual_frame_zoom_in:
        txa
        clc
        adc #16
        tax
        jmp visual_frame_selected
visual_frame_normal:
visual_frame_selected:
        jsr visual_clamp_cube_index_x
        stx prev_cube_index
        lda cube_frame_lo,x
        sta CUBE_PTR
        lda cube_frame_hi,x
        sta CUBE_PTR+1
        lda #$c8                 ; OPT34: hard stream guard, max 200 XY pairs
        sta cube_stream_guard
visual_draw_loop:
        lda cube_stream_guard        ; OPT32: draw guard too, not only erase
        beq visual_draw_done
        dec cube_stream_guard
        ; OPT29: pointer-walk frame stream. Safe for any frame length.
        ; This fixes the freeze that happened when first beat selected
        ; pulsed XYZ frames whose $ff sentinel was beyond Y=$ff.
        ldy #0
        lda (CUBE_PTR),y
        cmp #$ff
        beq visual_draw_done
        sta plot_x
        jsr visual_cube_ptr_inc
        ldy #0
        lda (CUBE_PTR),y
        sta plot_y
        jsr visual_cube_ptr_inc
        jsr visual_plot
        jmp visual_draw_loop
visual_draw_done:
        rts

visual_cube_ptr_inc:
        inc CUBE_PTR               ; OPT32: exactly one byte per stream read
        bne visual_cube_ptr_inc_done
        inc CUBE_PTR+1
visual_cube_ptr_inc_done:
        rts

visual_plot:
        ; OPT49: one bounds/table pass per cube point. We compute the screen
        ; address once, store the character, then retarget the same pointer to
        ; color RAM by adding $d4 to the high byte ($0400->$d800).
        jsr visual_calc_screen_addr
        bcs visual_plot_done
        ldy #0
        lda vis_char
        sta (VISUAL_PTR),y
        lda VISUAL_PTR+1
        clc
        adc #$d4
        sta VISUAL_PTR+1
        lda plot_y
        cmp #10
        bcs visual_plot_not_high
        lda #$01
        jmp visual_plot_store_color
visual_plot_not_high:
        cmp #16
        bcs visual_plot_low_depth
        lda vis_color
        jmp visual_plot_store_color
visual_plot_low_depth:
        lda song_flags
        and #$01
        beq visual_plot_low_nonchorus
        lda #$08
        jmp visual_plot_store_color
visual_plot_low_nonchorus:
        lda #$0c
visual_plot_store_color:
        sta (VISUAL_PTR),y
visual_plot_done:
        rts

visual_calc_screen_addr:
        lda plot_y
        cmp #25
        bcs visual_calc_addr_bad
        lda plot_x
        cmp #40
        bcs visual_calc_addr_bad
        ldx plot_y
        lda mul40_lo,x
        clc
        adc plot_x
        sta VISUAL_PTR
        lda mul40_hi,x
        adc #>SCREEN_RAM
        sta VISUAL_PTR+1
        clc
        rts

visual_calc_addr_bad:
        sec
        rts

; OPT26: dead visual overlay data/routines removed. Cube frames are generated from exact XYZ model.
mul40_lo:
        !byte $00,$28,$50,$78,$a0,$c8,$f0,$18,$40,$68,$90,$b8,$e0,$08,$30,$58,$80,$a8,$d0,$f8,$20,$48,$70,$98,$c0
mul40_hi:
        !byte $00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03

; OPT26: TRUE XYZ CUBE DATA
; OPT33: 1:1 full rotation data. Frames 00..15 are exact 360/16 phase steps.
; The visual loop advances exactly one phase per redraw, so frame 15 wraps to 00 without skipped phases.
; Drum/beat response uses pulsed frame selection and style only, not rotation phase jumps.
; Canonical 3D cube model: eight exact vertices at x/y/z = +/-1.
; Projection pipeline: XYZ vertex -> 1:1 periodic rotate X/Y/Z -> perspective -> C64 text-cell Bresenham edges.
; Row 0 is never emitted, preserving the no-top-line requirement.
; OPT37: canonical XYZ model is documented but not assembled as unused binary data.
; Vertices q4: (-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
;              (-1,-1, 1),(1,-1, 1),(1,1, 1),(-1,1, 1).
; Edges: 0-1,1-2,2-3,3-0,4-5,5-6,6-7,7-4,0-4,1-5,2-6,3-7.
; Rotation: 16 exact cyclic phases, frame N -> N+1 -> wrap 15 to 0.
; The assembled cube_fr*/cube_pu*/cube_zo* streams below are generated/rasterized 1:1 output.
; OPT45: cube_pu = beat zoom-in, cube_zo = beat rebound/zoom-out.
cube_frame_lo:
        !byte <cube_fr00,<cube_fr01,<cube_fr02,<cube_fr03,<cube_fr04,<cube_fr05,<cube_fr06,<cube_fr07,<cube_fr08,<cube_fr09,<cube_fr10,<cube_fr11,<cube_fr12,<cube_fr13,<cube_fr14,<cube_fr15,<cube_pu00,<cube_pu01,<cube_pu02,<cube_pu03,<cube_pu04,<cube_pu05,<cube_pu06,<cube_pu07,<cube_pu08,<cube_pu09,<cube_pu10,<cube_pu11,<cube_pu12,<cube_pu13,<cube_pu14,<cube_pu15,<cube_zo00,<cube_zo01,<cube_zo02,<cube_zo03,<cube_zo04,<cube_zo05,<cube_zo06,<cube_zo07,<cube_zo08,<cube_zo09,<cube_zo10,<cube_zo11,<cube_zo12,<cube_zo13,<cube_zo14,<cube_zo15
cube_frame_hi:
        !byte >cube_fr00,>cube_fr01,>cube_fr02,>cube_fr03,>cube_fr04,>cube_fr05,>cube_fr06,>cube_fr07,>cube_fr08,>cube_fr09,>cube_fr10,>cube_fr11,>cube_fr12,>cube_fr13,>cube_fr14,>cube_fr15,>cube_pu00,>cube_pu01,>cube_pu02,>cube_pu03,>cube_pu04,>cube_pu05,>cube_pu06,>cube_pu07,>cube_pu08,>cube_pu09,>cube_pu10,>cube_pu11,>cube_pu12,>cube_pu13,>cube_pu14,>cube_pu15,>cube_zo00,>cube_zo01,>cube_zo02,>cube_zo03,>cube_zo04,>cube_zo05,>cube_zo06,>cube_zo07,>cube_zo08,>cube_zo09,>cube_zo10,>cube_zo11,>cube_zo12,>cube_zo13,>cube_zo14,>cube_zo15
cube_fr00:
        !byte 9,8,10,8,11,8,12,8,13,8,14,8,15,8,16,8
        !byte 17,8,18,8,19,8,20,8,21,8,22,8,22,9,22,10
        !byte 22,11,22,12,22,13,23,14,23,15,23,16,23,17,23,18
        !byte 23,19,22,19,21,19,20,18,19,18,18,18,17,18,16,18
        !byte 15,18,14,17,13,17,12,17,11,17,11,16,11,15,10,14
        !byte 10,13,10,12,10,11,9,10,9,9,9,8,18,8,19,8
        !byte 20,8,21,8,22,8,23,8,24,7,25,7,26,7,27,7
        !byte 28,7,29,7,29,8,29,9,29,10,29,11,29,12,29,13
        !byte 29,14,29,15,28,15,27,15,26,15,25,15,24,14,23,14
        !byte 22,14,21,14,20,14,19,14,19,13,19,12,18,11,18,10
        !byte 18,9,18,8,9,8,10,8,11,8,12,8,13,8,14,8
        !byte 15,8,16,8,17,8,18,8,22,8,23,8,24,8,25,8
        !byte 26,7,27,7,28,7,29,7,23,19,24,18,25,18,26,17
        !byte 27,16,28,16,29,15,11,17,12,17,13,16,14,16,15,15
        !byte 16,15,17,15,18,14,19,14
        !byte $ff

cube_fr01:
        !byte 10,8,11,8,12,9,13,9,14,10,15,10,15,11,15,12
        !byte 16,13,16,14,16,15,16,16,17,17,17,18,17,19,16,18
        !byte 15,17,14,17,13,16,12,15,12,14,11,13,11,12,11,11
        !byte 11,10,10,9,10,8,22,7,23,7,24,7,25,7,26,8
        !byte 27,8,28,8,29,8,30,8,30,9,30,10,30,11,30,12
        !byte 30,13,30,14,30,15,30,16,29,16,28,15,27,15,26,14
        !byte 25,14,24,13,23,13,23,12,23,11,22,10,22,9,22,8
        !byte 22,7,10,8,11,8,12,8,13,8,14,8,15,8,16,7
        !byte 17,7,18,7,19,7,20,7,21,7,22,7,15,10,16,10
        !byte 17,10,18,10,19,9,20,9,21,9,22,9,23,9,24,9
        !byte 25,9,26,9,27,8,28,8,29,8,30,8,17,19,18,19
        !byte 19,19,20,18,21,18,22,18,23,18,24,17,25,17,26,17
        !byte 27,17,28,16,29,16,30,16,12,15,13,15,14,15,15,14
        !byte 16,14,17,14,18,14,19,14,20,14,21,13,22,13,23,13
        !byte $ff

cube_fr02:
        !byte 12,9,11,9,10,9,10,10,11,11,11,12,12,13,12,14
        !byte 12,15,13,16,13,17,14,18,14,19,14,18,15,17,15,16
        !byte 15,15,14,14,14,13,13,12,13,11,12,10,12,9,24,7
        !byte 25,7,26,7,27,7,28,7,28,8,28,9,29,10,29,11
        !byte 29,12,29,13,30,14,30,15,30,16,29,15,28,15,27,14
        !byte 26,14,26,13,25,12,25,11,25,10,25,9,24,8,24,7
        !byte 12,9,13,9,14,9,15,8,16,8,17,8,18,8,19,8
        !byte 20,8,21,7,22,7,23,7,24,7,10,9,11,9,12,9
        !byte 13,9,14,9,15,8,16,8,17,8,18,8,19,8,20,8
        !byte 21,8,22,8,23,8,24,7,25,7,26,7,27,7,28,7
        !byte 14,19,15,19,16,19,17,18,18,18,19,18,20,18,21,18
        !byte 22,17,23,17,24,17,25,17,26,17,27,17,28,16,29,16
        !byte 30,16,15,16,16,16,17,16,18,15,19,15,20,15,21,15
        !byte 22,15,23,15,24,14,25,14,26,14
        !byte $ff

cube_fr03:
        !byte 14,10,13,9,12,8,11,8,10,7,10,8,10,9,11,10
        !byte 11,11,11,12,11,13,11,14,12,15,12,16,12,17,13,17
        !byte 14,17,15,17,15,16,15,15,15,14,14,13,14,12,14,11
        !byte 14,10,25,9,25,8,26,7,26,6,26,5,26,6,27,7
        !byte 27,8,28,9,28,10,28,11,29,12,29,13,30,14,30,15
        !byte 29,16,28,16,28,15,27,14,27,13,26,12,26,11,25,10
        !byte 25,9,14,10,15,10,16,10,17,10,18,10,19,10,20,9
        !byte 21,9,22,9,23,9,24,9,25,9,10,7,11,7,12,7
        !byte 13,7,14,6,15,6,16,6,17,6,18,6,19,6,20,6
        !byte 21,6,22,5,23,5,24,5,25,5,26,5,12,17,13,17
        !byte 14,17,15,17,16,17,17,16,18,16,19,16,20,16,21,16
        !byte 22,16,23,16,24,16,25,16,26,15,27,15,28,15,29,15
        !byte 30,15,15,17,16,17,17,17,18,17,19,17,20,17,21,17
        !byte 22,16,23,16,24,16,25,16,26,16,27,16,28,16
        !byte $ff

cube_fr04:
        !byte 13,12,13,11,12,10,12,9,12,8,11,7,11,6,11,7
        !byte 12,8,12,9,12,10,12,11,13,12,13,13,13,14,13,15
        !byte 14,16,14,17,14,18,14,17,14,16,13,15,13,14,13,13
        !byte 13,12,24,11,24,10,25,9,25,8,26,7,26,6,27,7
        !byte 27,8,28,9,29,10,30,11,30,12,31,13,30,14,29,15
        !byte 28,16,27,17,26,16,26,15,25,14,25,13,24,12,24,11
        !byte 13,12,14,12,15,12,16,12,17,12,18,12,19,11,20,11
        !byte 21,11,22,11,23,11,24,11,11,6,12,6,13,6,14,6
        !byte 15,6,16,6,17,6,18,6,19,6,20,6,21,6,22,6
        !byte 23,6,24,6,25,6,26,6,13,14,14,14,15,14,16,14
        !byte 17,14,18,14,19,14,20,14,21,14,22,13,23,13,24,13
        !byte 25,13,26,13,27,13,28,13,29,13,30,13,31,13,14,18
        !byte 15,18,16,18,17,18,18,18,19,18,20,18,21,17,22,17
        !byte 23,17,24,17,25,17,26,17,27,17
        !byte $ff

cube_fr05:
        !byte 10,12,11,11,11,10,12,9,12,8,13,7,13,6,14,5
        !byte 15,6,16,7,17,8,17,9,18,10,19,11,18,12,17,13
        !byte 16,14,16,15,15,16,14,17,13,18,12,17,12,16,11,15
        !byte 11,14,10,13,10,12,20,12,21,11,22,10,23,9,24,9
        !byte 25,8,26,7,27,8,28,8,29,9,30,10,31,11,32,11
        !byte 33,12,32,13,31,14,30,14,29,15,28,16,27,17,26,17
        !byte 25,18,24,17,23,16,22,15,22,14,21,13,20,12,10,12
        !byte 11,12,12,12,13,12,14,12,15,12,16,12,17,12,18,12
        !byte 19,12,20,12,14,5,15,5,16,5,17,6,18,6,19,6
        !byte 20,6,21,6,22,6,23,7,24,7,25,7,26,7,19,11
        !byte 20,11,21,11,22,11,23,11,24,11,25,11,26,12,27,12
        !byte 28,12,29,12,30,12,31,12,32,12,33,12,13,18,14,18
        !byte 15,18,16,18,17,18,18,18,19,18,20,18,21,18,22,18
        !byte 23,18,24,18,25,18
        !byte $ff

cube_fr06:
        !byte 8,10,9,9,10,9,11,8,12,8,13,7,14,7,15,6
        !byte 16,6,17,5,18,5,19,4,20,5,21,6,22,6,23,7
        !byte 24,8,25,9,26,9,27,10,28,11,27,12,26,12,25,13
        !byte 24,13,23,14,22,14,21,15,20,15,19,16,18,16,17,17
        !byte 16,17,15,18,14,18,13,17,12,16,12,15,11,14,10,13
        !byte 9,12,9,11,8,10,15,12,16,12,17,11,18,11,19,10
        !byte 20,10,21,9,22,9,23,8,24,8,25,9,26,10,27,11
        !byte 28,11,29,12,30,13,31,14,30,14,29,15,28,15,27,16
        !byte 26,16,25,16,24,17,23,17,22,18,21,18,20,17,19,16
        !byte 18,15,17,14,16,13,15,12,8,10,9,10,10,11,11,11
        !byte 12,11,13,11,14,12,15,12,19,4,20,5,21,6,22,6
        !byte 23,7,24,8,28,11,29,12,30,13,31,14,14,18,15,18
        !byte 16,18,17,18,18,18,19,18,20,18,21,18
        !byte $ff

cube_fr07:
        !byte 11,8,12,8,13,8,14,8,15,7,16,7,17,7,18,7
        !byte 19,7,20,7,21,7,22,7,23,6,24,6,25,6,26,6
        !byte 27,6,28,7,28,8,29,9,29,10,30,11,30,12,31,13
        !byte 31,14,32,15,31,15,30,15,29,16,28,16,27,16,26,16
        !byte 25,16,24,17,23,17,22,17,21,17,20,17,19,17,18,18
        !byte 17,18,16,18,15,17,15,16,14,15,14,14,13,13,13,12
        !byte 12,11,12,10,11,9,11,8,11,10,12,10,13,10,14,9
        !byte 15,9,16,9,17,9,18,9,19,9,20,8,21,8,22,8
        !byte 23,8,23,9,24,10,24,11,25,12,25,13,26,14,26,15
        !byte 25,15,24,15,23,16,22,16,21,16,20,16,19,16,18,16
        !byte 17,17,16,17,15,17,14,16,14,15,13,14,13,13,12,12
        !byte 12,11,11,10,11,8,11,9,11,10,27,6,26,7,25,7
        !byte 24,8,23,8,32,15,31,15,30,15,29,15,28,15,27,15
        !byte 26,15,16,18,15,17
        !byte $ff

cube_fr08:
        !byte 20,8,21,8,22,8,23,9,24,9,25,9,26,9,27,9
        !byte 28,9,29,10,30,10,31,10,32,10,31,11,31,12,30,13
        !byte 29,14,29,15,28,16,28,17,27,18,26,18,25,18,24,18
        !byte 23,18,22,18,21,18,20,18,19,18,18,18,17,18,16,18
        !byte 15,18,16,17,16,16,17,15,17,14,18,13,18,12,19,11
        !byte 19,10,20,9,20,8,13,6,14,6,15,6,16,7,17,7
        !byte 18,7,19,7,20,7,21,8,22,8,23,8,22,9,22,10
        !byte 21,11,21,12,20,13,20,14,19,14,18,14,17,14,16,14
        !byte 15,14,14,14,13,14,12,14,11,14,10,14,10,13,11,12
        !byte 11,11,12,10,12,9,12,8,13,7,13,6,20,8,19,8
        !byte 18,7,17,7,16,7,15,7,14,6,13,6,32,10,31,10
        !byte 30,10,29,9,28,9,27,9,26,9,25,8,24,8,23,8
        !byte 27,18,26,17,25,17,24,16,23,16,22,15,21,15,20,14
        !byte 15,18,14,17,13,16,12,16,11,15,10,14
        !byte $ff

cube_fr09:
        !byte 26,13,27,13,28,14,29,14,30,15,31,15,30,15,29,16
        !byte 28,16,27,16,26,16,25,17,24,17,23,17,22,17,21,18
        !byte 20,18,19,18,18,18,17,18,16,18,15,17,14,17,13,17
        !byte 12,17,11,17,12,17,13,16,14,16,15,16,16,16,17,15
        !byte 18,15,19,15,20,15,21,14,22,14,23,14,24,14,25,13
        !byte 26,13,21,4,22,5,23,6,24,6,25,7,26,8,25,8
        !byte 24,9,23,9,22,9,21,10,20,10,19,10,18,11,17,11
        !byte 16,11,15,10,14,10,13,10,12,10,11,9,10,9,9,9
        !byte 10,9,11,8,12,8,13,7,14,7,15,6,16,6,17,6
        !byte 18,5,19,5,20,4,21,4,26,13,25,12,25,11,24,10
        !byte 24,9,23,8,23,7,22,6,22,5,21,4,31,15,30,14
        !byte 30,13,29,12,28,11,27,10,27,9,26,8,19,18,19,17
        !byte 18,16,18,15,18,14,18,13,17,12,17,11,11,17,11,16
        !byte 10,15,10,14,10,13,10,12,9,11,9,10,9,9
        !byte $ff

cube_fr10:
        !byte 23,18,24,17,23,17,22,16,21,16,20,16,19,16,18,15
        !byte 17,15,16,15,15,15,14,14,13,14,12,14,11,14,10,14
        !byte 9,14,8,14,9,14,10,15,11,15,12,15,13,15,14,16
        !byte 15,16,16,16,17,16,18,17,19,17,20,17,21,17,22,18
        !byte 23,18,31,9,30,10,29,11,28,11,27,10,26,10,25,10
        !byte 24,10,23,9,22,9,21,9,20,9,19,8,18,8,17,7
        !byte 16,6,15,5,16,5,17,6,18,6,19,6,20,6,21,7
        !byte 22,7,23,7,24,7,25,8,26,8,27,8,28,8,29,9
        !byte 30,9,31,9,23,18,24,17,25,16,26,15,27,14,27,13
        !byte 28,12,29,11,30,10,31,9,24,17,25,16,26,15,27,14
        !byte 27,13,28,12,29,11,13,14,14,13,15,12,16,11,16,10
        !byte 17,9,18,8,8,14,9,13,10,12,10,11,11,10,12,9
        !byte 13,8,13,7,14,6,15,5
        !byte $ff

cube_fr11:
        !byte 16,19,16,18,16,17,16,16,15,15,15,14,14,13,14,12
        !byte 13,11,13,10,12,9,11,9,10,10,9,10,10,11,11,12
        !byte 11,13,12,14,13,15,14,16,14,17,15,18,16,19,31,16
        !byte 30,15,29,14,28,14,27,13,26,12,26,11,25,10,24,9
        !byte 24,8,23,7,24,7,25,6,26,6,27,7,27,8,28,9
        !byte 28,10,29,11,29,12,30,13,30,14,31,15,31,16,16,19
        !byte 17,19,18,19,19,18,20,18,21,18,22,18,23,18,24,17
        !byte 25,17,26,17,27,17,28,17,29,16,30,16,31,16,16,16
        !byte 17,16,18,15,19,15,20,15,21,15,22,14,23,14,24,14
        !byte 25,14,26,13,27,13,12,9,13,9,14,9,15,8,16,8
        !byte 17,8,18,8,19,8,20,8,21,7,22,7,23,7,9,10
        !byte 10,10,11,10,12,9,13,9,14,9,15,9,16,8,17,8
        !byte 18,8,19,8,20,7,21,7,22,7,23,7,24,6,25,6
        !byte 26,6
        !byte $ff

cube_fr12:
        !byte 9,16,10,15,11,14,11,13,12,12,13,11,14,10,14,9
        !byte 15,8,16,7,16,6,17,5,16,6,15,7,15,8,14,9
        !byte 13,10,13,11,12,12,11,13,10,14,10,15,9,16,23,19
        !byte 23,18,23,17,23,16,23,15,23,14,24,13,25,12,26,11
        !byte 27,10,28,9,29,8,29,9,30,10,30,11,31,12,31,13
        !byte 30,14,29,15,28,15,27,16,26,17,25,18,24,18,23,19
        !byte 9,16,10,16,11,16,12,17,13,17,14,17,15,17,16,18
        !byte 17,18,18,18,19,18,20,18,21,19,22,19,23,19,13,11
        !byte 14,11,15,12,16,12,17,12,18,13,19,13,20,13,21,13
        !byte 22,14,23,14,17,5,18,5,19,6,20,6,21,6,22,6
        !byte 23,7,24,7,25,7,26,7,27,8,28,8,29,8,14,9
        !byte 15,9,16,9,17,10,18,10,19,10,20,10,21,11,22,11
        !byte 23,11,24,11,25,12,26,12,27,12,28,12,29,13,30,13
        !byte 31,13
        !byte $ff

cube_fr13:
        !byte 7,12,8,11,9,11,10,10,11,9,12,9,13,8,14,8
        !byte 15,7,16,7,17,7,18,6,19,6,20,6,21,6,22,6
        !byte 23,6,24,5,25,5,26,5,25,6,24,7,23,8,22,9
        !byte 21,10,20,11,19,12,18,12,17,12,16,12,15,12,14,12
        !byte 13,12,12,12,11,12,10,12,9,12,8,12,7,12,16,17
        !byte 17,16,18,15,19,14,20,13,21,12,22,12,23,12,24,12
        !byte 25,12,26,12,27,12,28,12,29,12,30,12,31,12,30,13
        !byte 30,14,29,15,28,16,28,17,27,18,26,18,25,18,24,18
        !byte 23,18,22,18,21,17,20,17,19,17,18,17,17,17,16,17
        !byte 7,12,8,13,9,13,10,14,11,14,12,15,13,15,14,16
        !byte 15,16,16,17,15,7,16,8,17,9,18,10,19,10,20,11
        !byte 21,12,26,5,27,6,27,7,28,8,29,9,30,10,30,11
        !byte 31,12,19,12,20,13,21,14,22,14,23,15,24,16,25,17
        !byte 26,17,27,18
        !byte $ff

cube_fr14:
        !byte 8,10,9,10,10,9,11,9,12,8,13,8,14,7,15,7
        !byte 16,7,17,6,18,6,19,5,20,5,21,5,22,6,23,6
        !byte 24,7,25,7,26,8,27,8,28,9,29,9,30,10,31,10
        !byte 30,11,29,11,28,12,27,12,26,13,25,13,24,14,23,14
        !byte 22,15,21,15,20,16,19,16,18,17,17,17,16,16,15,15
        !byte 14,15,13,14,12,13,11,12,10,12,9,11,8,10,13,13
        !byte 14,13,15,12,16,12,17,11,18,11,19,10,20,10,21,9
        !byte 22,9,23,10,24,10,25,11,26,12,27,12,28,13,29,13
        !byte 30,14,29,15,28,15,27,16,26,16,25,17,24,17,23,18
        !byte 22,18,21,19,20,19,19,18,18,17,17,16,16,16,15,15
        !byte 14,14,13,13,8,10,9,11,10,11,11,12,12,12,13,13
        !byte 20,5,21,6,21,7,22,8,22,9,31,10,31,11,30,12
        !byte 30,13,30,14,17,17,18,18,19,18,20,19
        !byte $ff

cube_fr15:
        !byte 9,9,10,9,11,8,12,8,13,8,14,8,15,7,16,7
        !byte 17,7,18,7,19,6,20,6,21,6,22,6,23,5,24,5
        !byte 24,6,25,7,25,8,26,9,26,10,27,11,27,12,28,13
        !byte 28,14,29,15,29,16,28,16,27,16,26,16,25,16,24,17
        !byte 23,17,22,17,21,17,20,17,19,17,18,17,17,17,16,18
        !byte 15,18,14,18,13,18,12,18,12,17,11,16,11,15,11,14
        !byte 10,13,10,12,10,11,9,10,9,9,15,10,16,10,17,10
        !byte 18,9,19,9,20,9,21,9,22,9,23,9,24,8,25,8
        !byte 26,8,26,9,27,10,27,11,28,12,28,13,29,14,29,15
        !byte 28,15,27,15,26,15,25,15,24,15,23,16,22,16,21,16
        !byte 20,16,19,16,18,16,17,16,17,15,16,14,16,13,16,12
        !byte 15,11,15,10,9,9,10,9,11,9,12,10,13,10,14,10
        !byte 15,10,24,5,25,6,25,7,26,8,29,16,29,15,12,18
        !byte 13,18,14,17,15,17,16,16,17,16
        !byte $ff

cube_pu00:
        !byte 7,8,8,8,9,8,10,8,11,8,12,8,13,8,14,8
        !byte 15,8,16,8,17,8,18,8,19,8,20,8,21,8,22,8
        !byte 22,9,22,10,22,11,22,12,22,13,23,14,23,15,23,16
        !byte 23,17,23,18,23,19,23,20,22,20,21,20,20,19,19,19
        !byte 18,19,17,19,16,18,15,18,14,18,13,18,12,18,11,17
        !byte 10,17,9,17,9,16,9,15,8,14,8,13,8,12,8,11
        !byte 7,10,7,9,7,8,18,7,19,7,20,7,21,7,22,7
        !byte 23,7,24,7,25,7,26,7,27,7,28,7,29,7,30,7
        !byte 31,7,31,8,31,9,31,10,31,11,31,12,31,13,31,14
        !byte 31,15,31,16,30,16,29,16,28,15,27,15,26,15,25,15
        !byte 24,15,23,15,22,14,21,14,20,14,19,14,19,13,19,12
        !byte 19,11,18,10,18,9,18,8,18,7,7,8,8,8,9,8
        !byte 10,8,11,8,12,8,13,7,14,7,15,7,16,7,17,7
        !byte 18,7,22,8,23,8,24,8,25,8,26,8,27,7,28,7
        !byte 29,7,30,7,31,7,23,20,24,19,25,19,26,18,27,18
        !byte 28,17,29,17,30,16,31,16,9,17,10,17,11,16,12,16
        !byte 13,16,14,15,15,15,16,15,17,15,18,14,19,14
        !byte $ff

cube_pu01:
        !byte 8,8,9,8,10,8,11,9,12,9,13,9,14,9,14,10
        !byte 15,11,15,12,15,13,15,14,16,15,16,16,16,17,16,18
        !byte 17,19,17,20,16,19,15,19,14,18,13,17,12,17,11,16
        !byte 11,15,10,14,10,13,9,12,9,11,9,10,8,9,8,8
        !byte 22,6,23,6,24,6,25,6,26,6,27,7,28,7,29,7
        !byte 30,7,31,7,32,7,32,8,32,9,32,10,32,11,32,12
        !byte 32,13,32,14,32,15,32,16,32,17,31,17,30,16,29,16
        !byte 28,16,27,15,26,15,25,15,24,14,23,14,23,13,23,12
        !byte 23,11,22,10,22,9,22,8,22,7,22,6,8,8,9,8
        !byte 10,8,11,8,12,7,13,7,14,7,15,7,16,7,17,7
        !byte 18,7,19,6,20,6,21,6,22,6,14,9,15,9,16,9
        !byte 17,9,18,9,19,8,20,8,21,8,22,8,23,8,24,8
        !byte 25,8,26,8,27,8,28,7,29,7,30,7,31,7,32,7
        !byte 17,20,18,20,19,20,20,19,21,19,22,19,23,19,24,19
        !byte 25,18,26,18,27,18,28,18,29,18,30,17,31,17,32,17
        !byte 11,16,12,16,13,16,14,15,15,15,16,15,17,15,18,15
        !byte 19,15,20,14,21,14,22,14,23,14
        !byte $ff

cube_pu02:
        !byte 11,8,10,8,9,8,9,9,10,10,10,11,10,12,11,13
        !byte 11,14,11,15,12,16,12,17,12,18,13,19,13,20,13,19
        !byte 14,18,14,17,14,16,14,15,13,14,13,13,12,12,12,11
        !byte 12,10,11,9,11,8,25,7,26,7,27,6,28,6,29,6
        !byte 29,7,30,8,30,9,30,10,30,11,31,12,31,13,31,14
        !byte 31,15,32,16,32,17,31,16,30,16,29,15,28,15,27,14
        !byte 27,13,26,12,26,11,26,10,26,9,25,8,25,7,11,8
        !byte 12,8,13,8,14,8,15,8,16,8,17,8,18,7,19,7
        !byte 20,7,21,7,22,7,23,7,24,7,25,7,9,8,10,8
        !byte 11,8,12,8,13,8,14,7,15,7,16,7,17,7,18,7
        !byte 19,7,20,7,21,7,22,7,23,7,24,6,25,6,26,6
        !byte 27,6,28,6,29,6,13,20,14,20,15,20,16,20,17,19
        !byte 18,19,19,19,20,19,21,19,22,19,23,18,24,18,25,18
        !byte 26,18,27,18,28,18,29,17,30,17,31,17,32,17,14,16
        !byte 15,16,16,16,17,16,18,15,19,15,20,15,21,15,22,15
        !byte 23,15,24,14,25,14,26,14,27,14
        !byte $ff

cube_pu03:
        !byte 13,10,12,9,11,9,10,8,9,8,8,7,8,8,9,9
        !byte 9,10,9,11,9,12,10,13,10,14,10,15,10,16,11,17
        !byte 11,18,12,18,13,18,14,18,15,18,15,17,14,16,14,15
        !byte 14,14,14,13,13,12,13,11,13,10,26,8,26,7,27,6
        !byte 27,5,27,4,27,5,28,6,28,7,29,8,29,9,30,10
        !byte 30,11,31,12,31,13,32,14,32,15,31,15,30,16,29,16
        !byte 29,15,28,14,28,13,27,12,27,11,27,10,26,9,26,8
        !byte 13,10,14,10,15,10,16,10,17,9,18,9,19,9,20,9
        !byte 21,9,22,9,23,8,24,8,25,8,26,8,8,7,9,7
        !byte 10,7,11,7,12,6,13,6,14,6,15,6,16,6,17,6
        !byte 18,5,19,5,20,5,21,5,22,5,23,5,24,4,25,4
        !byte 26,4,27,4,11,18,12,18,13,18,14,18,15,17,16,17
        !byte 17,17,18,17,19,17,20,17,21,17,22,16,23,16,24,16
        !byte 25,16,26,16,27,16,28,16,29,15,30,15,31,15,32,15
        !byte 15,18,16,18,17,18,18,18,19,17,20,17,21,17,22,17
        !byte 23,17,24,17,25,17,26,16,27,16,28,16,29,16
        !byte $ff

cube_pu04:
        !byte 12,12,12,11,11,10,11,9,11,8,11,7,10,6,10,5
        !byte 10,6,10,7,11,8,11,9,11,10,11,11,11,12,12,13
        !byte 12,14,12,15,12,16,13,17,13,18,13,19,13,18,13,17
        !byte 13,16,12,15,12,14,12,13,12,12,24,11,25,10,25,9
        !byte 26,8,26,7,27,6,27,5,28,6,29,7,29,8,30,9
        !byte 31,10,32,11,32,12,33,13,32,14,31,15,30,16,29,17
        !byte 28,18,27,17,27,16,26,15,26,14,25,13,25,12,24,11
        !byte 12,12,13,12,14,12,15,12,16,12,17,12,18,11,19,11
        !byte 20,11,21,11,22,11,23,11,24,11,10,5,11,5,12,5
        !byte 13,5,14,5,15,5,16,5,17,5,18,5,19,5,20,5
        !byte 21,5,22,5,23,5,24,5,25,5,26,5,27,5,12,15
        !byte 13,15,14,15,15,15,16,15,17,15,18,14,19,14,20,14
        !byte 21,14,22,14,23,14,24,14,25,14,26,14,27,14,28,13
        !byte 29,13,30,13,31,13,32,13,33,13,13,19,14,19,15,19
        !byte 16,19,17,19,18,19,19,19,20,19,21,18,22,18,23,18
        !byte 24,18,25,18,26,18,27,18,28,18
        !byte $ff

cube_pu05:
        !byte 8,12,9,11,9,10,10,9,11,8,11,7,12,6,12,5
        !byte 13,4,14,5,15,6,16,7,16,8,17,9,18,10,19,11
        !byte 18,12,17,13,16,14,15,15,15,16,14,17,13,18,12,19
        !byte 11,18,11,17,10,16,10,15,9,14,9,13,8,12,20,12
        !byte 21,11,22,10,23,9,24,8,25,7,26,6,27,7,28,7
        !byte 29,8,30,9,31,9,32,10,33,11,34,11,35,12,34,13
        !byte 33,14,32,14,31,15,30,16,29,17,28,17,27,18,26,19
        !byte 25,18,24,17,23,16,23,15,22,14,21,13,20,12,8,12
        !byte 9,12,10,12,11,12,12,12,13,12,14,12,15,12,16,12
        !byte 17,12,18,12,19,12,20,12,13,4,14,4,15,4,16,4
        !byte 17,5,18,5,19,5,20,5,21,5,22,5,23,6,24,6
        !byte 25,6,26,6,19,11,20,11,21,11,22,11,23,11,24,11
        !byte 25,11,26,11,27,12,28,12,29,12,30,12,31,12,32,12
        !byte 33,12,34,12,35,12,12,19,13,19,14,19,15,19,16,19
        !byte 17,19,18,19,19,19,20,19,21,19,22,19,23,19,24,19
        !byte 25,19,26,19
        !byte $ff

cube_pu06:
        !byte 6,10,7,9,8,9,9,8,10,8,11,7,12,7,13,6
        !byte 14,6,15,5,16,5,17,4,18,4,19,3,20,4,21,4
        !byte 22,5,23,6,24,7,25,7,26,8,27,9,28,10,29,10
        !byte 30,11,29,11,28,12,27,12,26,13,25,13,24,14,23,14
        !byte 22,15,21,15,20,16,19,16,18,17,17,17,16,18,15,18
        !byte 14,19,13,19,12,18,11,17,11,16,10,15,9,14,8,13
        !byte 8,12,7,11,6,10,15,12,16,12,17,11,18,11,19,10
        !byte 20,10,21,10,22,9,23,9,24,8,25,8,26,9,27,10
        !byte 28,10,29,11,30,12,31,13,32,13,33,14,32,14,31,15
        !byte 30,15,29,16,28,16,27,17,26,17,25,17,24,18,23,18
        !byte 22,19,21,19,20,18,19,17,18,16,18,15,17,14,16,13
        !byte 15,12,6,10,7,10,8,10,9,11,10,11,11,11,12,11
        !byte 13,12,14,12,15,12,19,3,20,4,21,5,22,6,23,6
        !byte 24,7,25,8,30,11,31,12,32,13,33,14,13,19,14,19
        !byte 15,19,16,19,17,19,18,19,19,19,20,19,21,19
        !byte $ff

cube_pu07:
        !byte 9,7,10,7,11,7,12,7,13,7,14,6,15,6,16,6
        !byte 17,6,18,6,19,6,20,6,21,6,22,6,23,6,24,5
        !byte 25,5,26,5,27,5,28,5,29,6,29,7,30,8,30,9
        !byte 31,10,32,11,32,12,33,13,33,14,34,15,33,15,32,15
        !byte 31,16,30,16,29,16,28,16,27,16,26,17,25,17,24,17
        !byte 23,17,22,18,21,18,20,18,19,18,18,18,17,19,16,19
        !byte 15,19,14,18,14,17,13,16,13,15,12,14,12,13,11,12
        !byte 11,11,10,10,10,9,9,8,9,7,10,10,11,10,12,10
        !byte 13,10,14,9,15,9,16,9,17,9,18,9,19,9,20,8
        !byte 21,8,22,8,23,8,24,9,24,10,25,11,25,12,26,13
        !byte 26,14,27,15,26,15,25,15,24,16,23,16,22,16,21,16
        !byte 20,17,19,17,18,17,17,17,16,18,15,18,14,18,13,17
        !byte 13,16,12,15,12,14,11,13,11,12,10,11,10,10,9,7
        !byte 9,8,10,9,10,10,28,5,27,6,26,6,25,7,24,7
        !byte 23,8,34,15,33,15,32,15,31,15,30,15,29,15,28,15
        !byte 27,15,15,19,14,18
        !byte $ff

cube_pu08:
        !byte 20,7,21,7,22,7,23,8,24,8,25,8,26,8,27,9
        !byte 28,9,29,9,30,9,31,9,32,10,33,10,34,10,33,11
        !byte 33,12,32,13,31,14,31,15,30,16,29,17,29,18,28,19
        !byte 27,19,26,19,25,19,24,19,23,19,22,19,21,19,20,19
        !byte 19,19,18,19,17,19,16,19,15,19,14,19,15,18,15,17
        !byte 16,16,16,15,17,14,17,13,18,12,18,11,19,10,19,9
        !byte 20,8,20,7,12,5,13,5,14,5,15,6,16,6,17,6
        !byte 18,6,19,6,20,6,21,7,22,7,23,7,24,7,23,8
        !byte 23,9,22,10,22,11,21,12,21,13,20,14,19,14,18,14
        !byte 17,14,16,14,15,14,14,14,13,14,12,14,11,14,10,14
        !byte 9,14,8,14,8,13,9,12,9,11,10,10,10,9,11,8
        !byte 11,7,12,6,12,5,20,7,19,7,18,6,17,6,16,6
        !byte 15,6,14,5,13,5,12,5,34,10,33,10,32,9,31,9
        !byte 30,9,29,8,28,8,27,8,26,8,25,7,24,7,28,19
        !byte 27,18,26,18,25,17,24,16,23,16,22,15,21,15,20,14
        !byte 14,19,13,18,12,17,11,16,10,16,9,15,8,14
        !byte $ff

cube_pu09:
        !byte 27,14,28,14,29,15,30,15,31,16,32,16,31,16,30,16
        !byte 29,16,28,17,27,17,26,17,25,17,24,17,23,17,22,18
        !byte 21,18,20,18,19,18,18,18,17,18,16,18,15,18,14,18
        !byte 13,18,12,18,11,18,10,18,9,18,10,18,11,18,12,17
        !byte 13,17,14,17,15,17,16,16,17,16,18,16,19,16,20,16
        !byte 21,15,22,15,23,15,24,15,25,14,26,14,27,14,21,3
        !byte 22,4,23,5,24,6,25,6,26,7,27,8,26,8,25,9
        !byte 24,9,23,9,22,9,21,10,20,10,19,10,18,10,17,11
        !byte 16,11,15,11,14,10,13,10,12,10,11,9,10,9,9,9
        !byte 8,8,7,8,8,8,9,7,10,7,11,7,12,6,13,6
        !byte 14,5,15,5,16,5,17,4,18,4,19,4,20,3,21,3
        !byte 27,14,26,13,26,12,25,11,25,10,24,9,24,8,23,7
        !byte 23,6,22,5,22,4,21,3,32,16,31,15,31,14,30,13
        !byte 29,12,29,11,28,10,28,9,27,8,19,18,19,17,18,16
        !byte 18,15,17,14,17,13,16,12,16,11,9,18,9,17,9,16
        !byte 8,15,8,14,8,13,8,12,8,11,7,10,7,9,7,8
        !byte $ff

cube_pu10:
        !byte 24,19,24,18,23,18,22,17,21,17,20,17,19,17,18,16
        !byte 17,16,16,16,15,16,14,15,13,15,12,15,11,15,10,15
        !byte 9,14,8,14,7,14,6,14,7,14,8,15,9,15,10,15
        !byte 11,15,12,16,13,16,14,16,15,17,16,17,17,17,18,17
        !byte 19,18,20,18,21,18,22,18,23,19,24,19,32,8,31,9
        !byte 31,10,30,11,29,11,28,10,27,10,26,10,25,9,24,9
        !byte 23,9,22,8,21,8,20,8,19,7,18,7,17,6,16,5
        !byte 15,4,16,4,17,4,18,5,19,5,20,5,21,5,22,6
        !byte 23,6,24,6,25,6,26,7,27,7,28,7,29,7,30,8
        !byte 31,8,32,8,24,19,25,18,25,17,26,16,27,15,28,14
        !byte 28,13,29,12,30,11,31,10,31,9,32,8,24,18,25,17
        !byte 26,16,27,15,27,14,28,13,29,12,30,11,12,15,13,14
        !byte 14,13,14,12,15,11,16,10,17,9,17,8,18,7,6,14
        !byte 7,13,8,12,9,11,10,10,11,9,11,8,12,7,13,6
        !byte 14,5,15,4
        !byte $ff

cube_pu11:
        !byte 15,20,15,19,16,18,16,17,16,16,15,15,15,14,14,13
        !byte 13,12,12,11,12,10,11,9,10,9,9,10,8,10,7,10
        !byte 8,11,9,12,9,13,10,14,11,15,12,16,13,17,13,18
        !byte 14,19,15,20,33,16,32,15,31,15,30,14,29,14,28,13
        !byte 27,12,27,11,26,10,26,9,25,8,25,7,24,6,25,6
        !byte 26,5,27,5,28,6,28,7,29,8,29,9,30,10,30,11
        !byte 31,12,31,13,32,14,32,15,33,16,15,20,16,20,17,20
        !byte 18,19,19,19,20,19,21,19,22,18,23,18,24,18,25,18
        !byte 26,18,27,17,28,17,29,17,30,17,31,16,32,16,33,16
        !byte 16,16,17,16,18,15,19,15,20,15,21,15,22,14,23,14
        !byte 24,14,25,14,26,13,27,13,28,13,11,9,12,9,13,9
        !byte 14,8,15,8,16,8,17,8,18,7,19,7,20,7,21,7
        !byte 22,6,23,6,24,6,7,10,8,10,9,9,10,9,11,9
        !byte 12,9,13,8,14,8,15,8,16,8,17,7,18,7,19,7
        !byte 20,7,21,6,22,6,23,6,24,6,25,5,26,5,27,5
        !byte $ff

cube_pu12:
        !byte 8,17,9,16,9,15,10,14,11,13,11,12,12,11,13,10
        !byte 13,9,14,8,14,7,15,6,15,5,16,4,15,5,14,6
        !byte 14,7,13,8,12,9,12,10,11,11,11,12,10,13,10,14
        !byte 9,15,9,16,8,17,24,20,24,19,24,18,24,17,24,16
        !byte 24,15,24,14,25,13,26,12,27,11,28,10,29,9,30,8
        !byte 31,9,31,10,32,11,32,12,33,13,32,14,31,15,30,15
        !byte 29,16,28,17,27,18,26,18,25,19,24,20,8,17,9,17
        !byte 10,17,11,18,12,18,13,18,14,18,15,18,16,19,17,19
        !byte 18,19,19,19,20,19,21,19,22,20,23,20,24,20,12,11
        !byte 13,11,14,12,15,12,16,12,17,12,18,13,19,13,20,13
        !byte 21,13,22,14,23,14,24,14,16,4,17,4,18,5,19,5
        !byte 20,5,21,5,22,6,23,6,24,6,25,7,26,7,27,7
        !byte 28,7,29,8,30,8,13,8,14,8,15,9,16,9,17,9
        !byte 18,9,19,10,20,10,21,10,22,10,23,11,24,11,25,11
        !byte 26,11,27,12,28,12,29,12,30,12,31,13,32,13,33,13
        !byte $ff

cube_pu13:
        !byte 5,12,6,11,7,11,8,10,9,9,10,9,11,8,12,7
        !byte 13,7,14,6,15,6,16,6,17,5,18,5,19,5,20,5
        !byte 21,5,22,5,23,4,24,4,25,4,26,4,25,5,24,6
        !byte 23,7,22,8,21,9,20,10,19,11,18,12,17,12,16,12
        !byte 15,12,14,12,13,12,12,12,11,12,10,12,9,12,8,12
        !byte 7,12,6,12,5,12,15,18,16,17,17,16,18,15,19,14
        !byte 20,13,21,12,22,12,23,12,24,12,25,12,26,12,27,12
        !byte 28,12,29,12,30,12,31,12,32,12,33,12,32,13,32,14
        !byte 31,15,30,16,30,17,29,18,29,19,28,20,27,20,26,20
        !byte 25,20,24,19,23,19,22,19,21,19,20,19,19,19,18,18
        !byte 17,18,16,18,15,18,5,12,6,13,7,13,8,14,9,14
        !byte 10,15,11,16,12,16,13,17,14,17,15,18,14,6,15,7
        !byte 16,8,17,9,18,9,19,10,20,11,21,12,26,4,27,5
        !byte 28,6,29,7,30,8,30,9,31,10,32,11,33,12,18,12
        !byte 19,13,20,14,21,14,22,15,23,16,24,17,25,18,26,18
        !byte 27,19,28,20
        !byte $ff

cube_pu14:
        !byte 6,9,7,9,8,8,9,8,10,7,11,7,12,6,13,6
        !byte 14,6,15,5,16,5,17,4,18,4,19,3,20,3,21,3
        !byte 22,4,23,4,24,5,25,5,26,6,27,6,28,7,29,7
        !byte 30,8,31,8,32,9,33,9,32,9,31,10,30,10,29,11
        !byte 28,11,27,12,26,12,25,13,24,13,23,14,22,14,21,15
        !byte 20,15,19,16,18,16,17,17,16,17,15,16,14,15,13,15
        !byte 12,14,11,13,10,12,9,11,8,11,7,10,6,9,12,14
        !byte 13,13,14,13,15,12,16,12,17,11,18,11,19,10,20,10
        !byte 21,9,22,9,23,10,24,10,25,11,26,11,27,12,28,12
        !byte 29,13,30,13,31,14,30,15,29,15,28,16,27,16,26,17
        !byte 25,17,24,18,23,18,22,19,21,19,20,20,19,19,18,18
        !byte 17,18,16,17,15,16,14,15,13,15,12,14,6,9,7,10
        !byte 8,11,9,12,10,12,11,13,12,14,20,3,20,4,21,5
        !byte 21,6,21,7,22,8,22,9,33,9,33,10,32,11,32,12
        !byte 31,13,31,14,16,17,17,18,18,19,19,19,20,20
        !byte $ff

cube_pu15:
        !byte 7,8,8,8,9,8,10,7,11,7,12,7,13,7,14,6
        !byte 15,6,16,6,17,6,18,6,19,5,20,5,21,5,22,5
        !byte 23,4,24,4,25,4,25,5,26,6,26,7,27,8,27,9
        !byte 28,10,28,11,28,12,29,13,29,14,30,15,30,16,29,16
        !byte 28,16,27,16,26,17,25,17,24,17,23,17,22,17,21,17
        !byte 20,18,19,18,18,18,17,18,16,18,15,18,14,19,13,19
        !byte 12,19,11,19,11,18,10,17,10,16,10,15,9,14,9,13
        !byte 8,12,8,11,8,10,7,9,7,8,14,9,15,9,16,9
        !byte 17,8,18,8,19,8,20,8,21,8,22,8,23,7,24,7
        !byte 25,7,26,7,27,8,27,9,28,10,28,11,29,12,29,13
        !byte 30,14,30,15,29,15,28,15,27,15,26,16,25,16,24,16
        !byte 23,16,22,16,21,16,20,17,19,17,18,17,17,17,17,16
        !byte 16,15,16,14,15,13,15,12,15,11,14,10,14,9,7,8
        !byte 8,8,9,8,10,8,11,9,12,9,13,9,14,9,25,4
        !byte 25,5,26,6,26,7,30,16,30,15,11,19,12,19,13,18
        !byte 14,18,15,18,16,17,17,17
        !byte $ff

; OPT45: zoom-out/rebound frames generated from canonical normal frames.
cube_zo00:
        !byte 11,9,12,9,12,9,13,9,14,9,15,9,16,9,17,9,17,9,18,9,19,9,20,9
        !byte 21,9,22,9,22,10,22,10,22,11,22,12,22,13,23,14,23,15,23,15,23,16,23,17
        !byte 23,18,22,18,21,18,20,17,19,17,18,17,17,17,17,17,16,17,15,16,14,16,13,16
        !byte 12,16,12,15,12,15,12,14,12,13,12,12,12,11,11,10,11,10,11,9,18,9,19,9
        !byte 20,9,21,9,22,9,23,9,23,8,24,8,25,8,26,8,27,8,28,8,28,9,28,10
        !byte 28,10,28,11,28,12,28,13,28,14,28,15,27,15,26,15,25,15,24,15,23,14,23,14
        !byte 22,14,21,14,20,14,19,14,19,13,19,12,18,11,18,10,18,10,18,9,11,9,12,9
        !byte 12,9,13,9,14,9,15,9,16,9,17,9,17,9,18,9,22,9,23,9,23,9,24,9
        !byte 25,8,26,8,27,8,28,8,23,18,23,17,24,17,25,16,26,15,27,15,28,15,12,16
        !byte 13,16,14,15,15,15,16,15,17,15,17,15,18,14,19,14
        !byte $ff

cube_zo01:
        !byte 12,9,12,9,13,10,14,10,15,10,16,10,16,11,16,12,17,13,17,14,17,15,17,15
        !byte 17,16,17,17,17,18,17,17,16,16,15,16,14,15,13,15,13,14,12,13,12,12,12,11
        !byte 12,10,12,10,12,9,22,8,23,8,23,8,24,8,25,9,26,9,27,9,28,9,28,9
        !byte 28,10,28,10,28,11,28,12,28,13,28,14,28,15,28,15,28,15,27,15,26,15,25,14
        !byte 24,14,23,13,23,13,23,12,23,11,22,10,22,10,22,9,22,8,12,9,12,9,13,9
        !byte 14,9,15,9,16,9,17,8,17,8,18,8,19,8,20,8,21,8,22,8,16,10,17,10
        !byte 17,10,18,10,19,10,20,10,21,10,22,10,23,10,23,10,24,10,25,10,26,9,27,9
        !byte 28,9,28,9,17,18,18,18,19,18,20,17,21,17,22,17,23,17,23,16,24,16,25,16
        !byte 26,16,27,15,28,15,28,15,13,15,14,15,15,15,16,14,17,14,17,14,18,14,19,14
        !byte 20,14,21,13,22,13,23,13
        !byte $ff

cube_zo02:
        !byte 13,10,12,10,12,10,12,10,12,11,12,12,13,13,13,14,13,15,14,15,14,16,15,17
        !byte 15,18,15,17,16,16,16,15,16,15,15,14,15,13,14,12,14,11,13,10,13,10,23,8
        !byte 24,8,25,8,26,8,27,8,27,9,27,10,28,10,28,11,28,12,28,13,28,14,28,15
        !byte 28,15,28,15,27,15,26,14,25,14,25,13,24,12,24,11,24,10,24,10,23,9,23,8
        !byte 13,10,14,10,15,10,16,9,17,9,17,9,18,9,19,9,20,9,21,8,22,8,23,8
        !byte 23,8,12,10,12,10,13,10,14,10,15,10,16,9,17,9,17,9,18,9,19,9,20,9
        !byte 21,9,22,9,23,9,23,8,24,8,25,8,26,8,27,8,15,18,16,18,17,18,17,17
        !byte 18,17,19,17,20,17,21,17,22,16,23,16,23,16,24,16,25,16,26,16,27,15,28,15
        !byte 28,15,16,15,17,15,17,15,18,15,19,15,20,15,21,15,22,15,23,15,23,14,24,14
        !byte 25,14
        !byte $ff

cube_zo03:
        !byte 15,10,14,10,13,9,12,9,12,8,12,9,12,10,12,10,12,11,12,12,12,13,12,14
        !byte 13,15,13,15,13,16,14,16,15,16,16,16,16,15,16,15,16,14,15,13,15,12,15,11
        !byte 15,10,24,10,24,9,25,8,25,7,25,6,25,7,26,8,26,9,27,10,27,10,27,11
        !byte 28,12,28,13,28,14,28,15,28,15,27,15,27,15,26,14,26,13,25,12,25,11,24,10
        !byte 24,10,15,10,16,10,17,10,17,10,18,10,19,10,20,10,21,10,22,10,23,10,23,10
        !byte 24,10,12,8,12,8,13,8,14,8,15,7,16,7,17,7,17,7,18,7,19,7,20,7
        !byte 21,7,22,6,23,6,23,6,24,6,25,6,13,16,14,16,15,16,16,16,17,16,17,15
        !byte 18,15,19,15,20,15,21,15,22,15,23,15,23,15,24,15,25,15,26,15,27,15,28,15
        !byte 28,15,16,16,17,16,17,16,18,16,19,16,20,16,21,16,22,15,23,15,23,15,24,15
        !byte 25,15,26,15,27,15
        !byte $ff

cube_zo04:
        !byte 14,12,14,11,13,10,13,10,13,9,12,8,12,7,12,8,13,9,13,10,13,10,13,11
        !byte 14,12,14,13,14,14,14,15,15,15,15,16,15,17,15,16,15,15,14,15,14,14,14,13
        !byte 14,12,23,11,23,10,24,10,24,9,25,8,25,7,26,8,26,9,27,10,28,10,28,11
        !byte 28,12,29,13,28,14,28,15,27,15,26,16,25,15,25,15,24,14,24,13,23,12,23,11
        !byte 14,12,15,12,16,12,17,12,17,12,18,12,19,11,20,11,21,11,22,11,23,11,23,11
        !byte 12,7,13,7,14,7,15,7,16,7,17,7,17,7,18,7,19,7,20,7,21,7,22,7
        !byte 23,7,23,7,24,7,25,7,14,14,15,14,16,14,17,14,17,14,18,14,19,14,20,14
        !byte 21,14,22,13,23,13,23,13,24,13,25,13,26,13,27,13,28,13,28,13,29,13,15,17
        !byte 16,17,17,17,17,17,18,17,19,17,20,17,21,16,22,16,23,16,23,16,24,16,25,16
        !byte 26,16
        !byte $ff

cube_zo05:
        !byte 12,12,12,11,12,10,13,10,13,9,14,8,14,7,15,6,16,7,17,8,17,9,17,10
        !byte 18,10,19,11,18,12,17,13,17,14,17,15,16,15,15,16,14,17,13,16,13,15,12,15
        !byte 12,14,12,13,12,12,20,12,21,11,22,10,23,10,23,10,24,9,25,8,26,9,27,9
        !byte 28,10,28,10,29,11,30,11,31,12,30,13,29,14,28,14,28,15,27,15,26,16,25,16
        !byte 24,17,23,16,23,15,22,15,22,14,21,13,20,12,12,12,12,12,13,12,14,12,15,12
        !byte 16,12,17,12,17,12,18,12,19,12,20,12,15,6,16,6,17,6,17,7,18,7,19,7
        !byte 20,7,21,7,22,7,23,8,23,8,24,8,25,8,19,11,20,11,21,11,22,11,23,11
        !byte 23,11,24,11,25,12,26,12,27,12,28,12,28,12,29,12,30,12,31,12,14,17,15,17
        !byte 16,17,17,17,17,17,18,17,19,17,20,17,21,17,22,17,23,17,23,17,24,17
        !byte $ff

cube_zo06:
        !byte 10,10,11,10,12,10,12,9,13,9,14,8,15,8,16,7,17,7,17,6,18,6,19,5
        !byte 20,6,21,7,22,7,23,8,23,9,24,10,25,10,26,10,27,11,26,12,25,12,24,13
        !byte 23,13,23,14,22,14,21,15,20,15,19,15,18,15,17,16,17,16,16,17,15,17,14,16
        !byte 13,15,13,15,12,14,12,13,11,12,11,11,10,10,16,12,17,12,17,11,18,11,19,10
        !byte 20,10,21,10,22,10,23,9,23,9,24,10,25,10,26,11,27,11,28,12,28,13,29,14
        !byte 28,14,28,15,27,15,26,15,25,15,24,15,23,16,23,16,22,17,21,17,20,16,19,15
        !byte 18,15,17,14,17,13,16,12,10,10,11,10,12,11,12,11,13,11,14,11,15,12,16,12
        !byte 19,5,20,6,21,7,22,7,23,8,23,9,27,11,28,12,28,13,29,14,15,17,16,17
        !byte 17,17,17,17,18,17,19,17,20,17,21,17
        !byte $ff

cube_zo07:
        !byte 12,9,13,9,14,9,15,9,16,8,17,8,17,8,18,8,19,8,20,8,21,8,22,8
        !byte 23,7,23,7,24,7,25,7,26,7,27,8,27,9,28,10,28,10,28,11,28,12,29,13
        !byte 29,14,30,15,29,15,28,15,28,15,27,15,26,15,25,15,24,15,23,16,23,16,22,16
        !byte 21,16,20,16,19,16,18,17,17,17,17,17,16,16,16,15,15,15,15,14,14,13,14,12
        !byte 13,11,13,10,12,10,12,9,12,10,13,10,14,10,15,10,16,10,17,10,17,10,18,10
        !byte 19,10,20,9,21,9,22,9,23,9,23,10,23,10,23,11,24,12,24,13,25,14,25,15
        !byte 24,15,23,15,23,15,22,15,21,15,20,15,19,15,18,15,17,16,17,16,16,16,15,15
        !byte 15,15,14,14,14,13,13,12,13,11,12,10,12,9,12,10,12,10,26,7,25,8,24,8
        !byte 23,9,23,9,30,15,29,15,28,15,28,15,27,15,26,15,25,15,17,17,16,16
        !byte $ff

cube_zo08:
        !byte 20,9,21,9,22,9,23,10,23,10,24,10,25,10,26,10,27,10,28,10,28,10,29,10
        !byte 30,10,29,11,29,12,28,13,28,14,28,15,27,15,27,16,26,17,25,17,24,17,23,17
        !byte 23,17,22,17,21,17,20,17,19,17,18,17,17,17,17,17,16,17,17,16,17,15,17,15
        !byte 17,14,18,13,18,12,19,11,19,10,20,10,20,9,14,7,15,7,16,7,17,8,17,8
        !byte 18,8,19,8,20,8,21,9,22,9,23,9,22,10,22,10,21,11,21,12,20,13,20,14
        !byte 19,14,18,14,17,14,17,14,16,14,15,14,14,14,13,14,12,14,12,14,12,13,12,12
        !byte 12,11,13,10,13,10,13,9,14,8,14,7,20,9,19,9,18,8,17,8,17,8,16,8
        !byte 15,7,14,7,30,10,29,10,28,10,28,10,27,10,26,10,25,10,24,9,23,9,23,9
        !byte 26,17,25,16,24,16,23,15,23,15,22,15,21,15,20,14,16,17,15,16,14,15,13,15
        !byte 12,15,12,14
        !byte $ff

cube_zo09:
        !byte 25,13,26,13,27,14,28,14,28,15,29,15,28,15,28,15,27,15,26,15,25,15,24,16
        !byte 23,16,23,16,22,16,21,17,20,17,19,17,18,17,17,17,17,17,16,16,15,16,14,16
        !byte 13,16,12,16,13,16,14,15,15,15,16,15,17,15,17,15,18,15,19,15,20,15,21,14
        !byte 22,14,23,14,23,14,24,13,25,13,21,5,22,6,23,7,23,7,24,8,25,9,24,9
        !byte 23,10,23,10,22,10,21,10,20,10,19,10,18,11,17,11,17,11,16,10,15,10,14,10
        !byte 13,10,12,10,12,10,11,10,12,10,12,9,13,9,14,8,15,8,16,7,17,7,17,7
        !byte 18,6,19,6,20,5,21,5,25,13,24,12,24,11,23,10,23,10,23,9,23,8,22,7
        !byte 22,6,21,5,29,15,28,14,28,13,28,12,27,11,26,10,26,10,25,9,19,17,19,16
        !byte 18,15,18,15,18,14,18,13,17,12,17,11,12,16,12,15,12,15,12,14,12,13,12,12
        !byte 11,11,11,10,11,10
        !byte $ff

cube_zo10:
        !byte 23,17,23,16,23,16,22,15,21,15,20,15,19,15,18,15,17,15,17,15,16,15,15,14
        !byte 14,14,13,14,12,14,12,14,11,14,10,14,11,14,12,15,12,15,13,15,14,15,15,15
        !byte 16,15,17,15,17,15,18,16,19,16,20,16,21,16,22,17,23,17,29,10,28,10,28,11
        !byte 27,11,26,10,25,10,24,10,23,10,23,10,22,10,21,10,20,10,19,9,18,9,17,8
        !byte 17,7,16,6,17,6,17,7,18,7,19,7,20,7,21,8,22,8,23,8,23,8,24,9
        !byte 25,9,26,9,27,9,28,10,28,10,29,10,23,17,23,16,24,15,25,15,26,14,26,13
        !byte 27,12,28,11,28,10,29,10,23,16,24,15,25,15,26,14,26,13,27,12,28,11,14,14
        !byte 15,13,16,12,17,11,17,10,17,10,18,9,10,14,11,13,12,12,12,11,12,10,13,10
        !byte 14,9,14,8,15,7,16,6
        !byte $ff

cube_zo11:
        !byte 17,18,17,17,17,16,17,15,16,15,16,14,15,13,15,12,14,11,14,10,13,10,12,10
        !byte 12,10,11,10,12,11,12,12,12,13,13,14,14,15,15,15,15,16,16,17,17,18,29,15
        !byte 28,15,28,14,27,14,26,13,25,12,25,11,24,10,23,10,23,9,23,8,23,8,24,7
        !byte 25,7,26,8,26,9,27,10,27,10,28,11,28,12,28,13,28,14,29,15,29,15,17,18
        !byte 17,18,18,18,19,17,20,17,21,17,22,17,23,17,23,16,24,16,25,16,26,16,27,16
        !byte 28,15,28,15,29,15,17,15,17,15,18,15,19,15,20,15,21,15,22,14,23,14,23,14
        !byte 24,14,25,13,26,13,13,10,14,10,15,10,16,9,17,9,17,9,18,9,19,9,20,9
        !byte 21,8,22,8,23,8,11,10,12,10,12,10,13,10,14,10,15,10,16,10,17,9,17,9
        !byte 18,9,19,9,20,8,21,8,22,8,23,8,23,7,24,7,25,7
        !byte $ff

cube_zo12:
        !byte 11,15,12,15,12,14,12,13,13,12,14,11,15,10,15,10,16,9,17,8,17,7,17,6
        !byte 17,7,16,8,16,9,15,10,14,10,14,11,13,12,12,13,12,14,12,15,11,15,23,18
        !byte 23,17,23,16,23,15,23,15,23,14,23,13,24,12,25,11,26,10,27,10,28,9,28,10
        !byte 28,10,28,11,29,12,29,13,28,14,28,15,27,15,26,15,25,16,24,17,23,17,23,18
        !byte 11,15,12,15,12,15,13,16,14,16,15,16,16,16,17,17,17,17,18,17,19,17,20,17
        !byte 21,18,22,18,23,18,14,11,15,11,16,12,17,12,17,12,18,13,19,13,20,13,21,13
        !byte 22,14,23,14,17,6,18,6,19,7,20,7,21,7,22,7,23,8,23,8,24,8,25,8
        !byte 26,9,27,9,28,9,15,10,16,10,17,10,17,10,18,10,19,10,20,10,21,11,22,11
        !byte 23,11,23,11,24,12,25,12,26,12,27,12,28,13,28,13,29,13
        !byte $ff

cube_zo13:
        !byte 9,12,10,11,11,11,12,10,12,10,13,10,14,9,15,9,16,8,17,8,17,8,18,7
        !byte 19,7,20,7,21,7,22,7,23,7,23,6,24,6,25,6,24,7,23,8,23,9,22,10
        !byte 21,10,20,11,19,12,18,12,17,12,17,12,16,12,15,12,14,12,13,12,12,12,12,12
        !byte 11,12,10,12,9,12,17,16,17,15,18,15,19,14,20,13,21,12,22,12,23,12,23,12
        !byte 24,12,25,12,26,12,27,12,28,12,28,12,29,12,28,13,28,14,28,15,27,15,27,16
        !byte 26,17,25,17,24,17,23,17,23,17,22,17,21,16,20,16,19,16,18,16,17,16,17,16
        !byte 9,12,10,13,11,13,12,14,12,14,13,15,14,15,15,15,16,15,17,16,16,8,17,9
        !byte 17,10,18,10,19,10,20,11,21,12,25,6,26,7,26,8,27,9,28,10,28,10,28,11
        !byte 29,12,19,12,20,13,21,14,22,14,23,15,23,15,24,16,25,16,26,17
        !byte $ff

cube_zo14:
        !byte 10,10,11,10,12,10,12,10,13,9,14,9,15,8,16,8,17,8,17,7,18,7,19,6
        !byte 20,6,21,6,22,7,23,7,23,8,24,8,25,9,26,9,27,10,28,10,28,10,29,10
        !byte 28,11,28,11,27,12,26,12,25,13,24,13,23,14,23,14,22,15,21,15,20,15,19,15
        !byte 18,16,17,16,17,15,16,15,15,15,14,14,13,13,12,12,12,12,11,11,10,10,14,13
        !byte 15,13,16,12,17,12,17,11,18,11,19,10,20,10,21,10,22,10,23,10,23,10,24,11
        !byte 25,12,26,12,27,13,28,13,28,14,28,15,27,15,26,15,25,15,24,16,23,16,23,17
        !byte 22,17,21,18,20,18,19,17,18,16,17,15,17,15,16,15,15,14,14,13,10,10,11,11
        !byte 12,11,12,12,13,12,14,13,20,6,21,7,21,8,22,9,22,10,29,10,29,11,28,12
        !byte 28,13,28,14,17,16,18,17,19,17,20,18
        !byte $ff

cube_zo15:
        !byte 11,10,12,10,12,9,13,9,14,9,15,9,16,8,17,8,17,8,18,8,19,7,20,7
        !byte 21,7,22,7,23,6,23,6,23,7,24,8,24,9,25,10,25,10,26,11,26,12,27,13
        !byte 27,14,28,15,28,15,27,15,26,15,25,15,24,15,23,16,23,16,22,16,21,16,20,16
        !byte 19,16,18,16,17,16,17,17,16,17,15,17,14,17,13,17,13,16,12,15,12,15,12,14
        !byte 12,13,12,12,12,11,11,10,11,10,16,10,17,10,17,10,18,10,19,10,20,10,21,10
        !byte 22,10,23,10,23,9,24,9,25,9,25,10,26,10,26,11,27,12,27,13,28,14,28,15
        !byte 27,15,26,15,25,15,24,15,23,15,23,15,22,15,21,15,20,15,19,15,18,15,17,15
        !byte 17,15,17,14,17,13,17,12,16,11,16,10,11,10,12,10,12,10,13,10,14,10,15,10
        !byte 16,10,23,6,24,7,24,8,25,9,28,15,28,15,13,17,14,17,15,16,16,16,17,15
        !byte 17,15
        !byte $ff


; Song order: four bytes per pattern: bass, drums, lead, flags.
; flags bit0 = chorus lead, bit1 = build filter.
order:
order_intro:
        !byte 0,0,0,0,0,1,0,0,1,1,0,0,1,2,1,0
        !byte 1,2,1,0,2,2,0,0,3,2,1,0,4,2,0,0
order_verse1:
        !byte 1,2,5,0,2,2,5,0,3,2,5,0,4,2,5,0
        !byte 1,2,0,0,2,2,5,0,3,2,0,0,4,2,5,0
        !byte 1,2,5,0,2,2,6,0,3,2,5,0,4,2,6,0
        !byte 1,2,0,0,2,2,5,0,3,2,6,0,4,2,5,0
order_build1:
        !byte 1,3,2,2,2,3,3,2,3,3,2,2,4,3,3,2
        !byte 1,5,6,2,2,5,6,2,3,5,6,2,4,5,6,2
order_chorus1:
        !byte 1,3,1,1,2,3,2,1,3,3,3,1,4,3,4,1
        !byte 1,4,1,1,2,4,2,1,3,4,3,1,4,4,4,1
        !byte 1,3,1,1,2,3,2,1,3,3,3,1,4,3,4,1
        !byte 1,4,7,1,2,4,8,1,3,4,9,1,4,4,10,1
order_verse2:
        !byte 1,2,5,0,2,2,6,0,3,2,5,0,4,2,6,0
        !byte 1,2,0,0,2,2,5,0,3,2,6,0,4,2,5,0
        !byte 1,2,5,0,2,2,5,0,3,2,6,0,4,2,6,0
        !byte 1,2,0,0,2,2,5,0,3,2,0,0,4,2,6,0
order_build2:
        !byte 1,3,2,2,2,3,3,2,3,3,2,2,4,3,3,2
        !byte 1,5,6,2,2,5,6,2,3,5,6,2,4,5,6,2
order_chorus2:
        !byte 1,3,1,1,2,3,2,1,3,3,3,1,4,3,4,1
        !byte 1,4,7,1,2,4,8,1,3,4,9,1,4,4,10,1
        !byte 1,3,7,1,2,3,8,1,3,3,9,1,4,3,10,1
        !byte 1,4,1,1,2,4,8,1,3,4,3,1,4,4,10,1
order_break:
        !byte 0,1,0,2,1,0,5,2,2,1,0,2,3,1,6,2
        !byte 0,6,5,2,1,2,6,2,2,6,5,2,3,5,6,2
order_final:
        !byte 1,5,7,3,2,6,8,3,3,5,9,3,4,6,10,3
        !byte 1,5,7,3,2,6,8,3,3,5,9,3,4,6,10,3
        !byte 1,5,1,3,2,5,8,3,3,5,3,3,4,5,10,3
order_outro:
        !byte 1,2,5,0,2,2,0,0,3,1,0,0,4,1,0,0
        !byte $ff

bsilent: !fill 16,0
bassAm:  !byte 0,0,34,0,0,0,34,0,0,0,34,0,0,0,34,46
bassF:   !byte 0,0,30,0,0,0,30,0,0,0,30,0,0,0,30,42
bassC:   !byte 0,0,37,0,0,0,37,0,0,0,37,0,0,0,37,49
bassG:   !byte 0,0,32,0,0,0,32,0,0,0,32,0,0,0,32,44

dsilent: !fill 16,0
d_basic: !byte 1,0,3,0,2,0,3,3,1,0,3,0,2,0,3,3
d_full:  !byte 1,0,3,0,2,3,3,0,1,0,3,2,5,0,3,4
d_chorus:!byte 1,0,3,2,3,3,3,0,1,0,3,2,5,3,4,2
d_big:   !byte 1,0,3,2,5,3,3,0,1,0,3,2,3,3,4,2
d_lift:  !byte 1,0,3,0,2,3,3,0,1,5,3,0,2,3,4,0
d_pshhh: !byte 0,0,0,0,3,0,0,0,6,0,0,0,3,0,4,0

lsilent: !fill 16,0
leadAm:   !byte 46,0,49,0,53,0,49,0,46,0,49,0,53,0,49,0
leadF:    !byte 46,0,49,0,54,0,49,0,46,0,49,0,54,0,49,0
leadC:    !byte 44,0,49,0,53,0,49,0,44,0,49,0,53,0,49,0
leadG:    !byte 44,0,48,0,51,0,48,0,44,0,48,0,51,0,48,0
verseA:   !byte 34,0,37,0,41,0,37,0,46,0,41,0,37,0,34,0
leadUp:   !byte 34,37,41,46,49,53,56,53,49,46,41,37,34,37,41,46
leadEAm:  !byte 58,0,61,0,65,0,61,0,58,61,65,61,58,61,65,70
leadEF:   !byte 58,0,61,0,66,0,61,0,58,61,66,61,58,61,66,70
leadEC:   !byte 56,0,61,0,65,0,61,0,56,61,65,61,56,61,65,68
leadEG:   !byte 56,0,60,0,63,0,60,0,56,60,63,60,56,60,63,68

bpat_lo: !byte <bsilent,<bassAm,<bassF,<bassC,<bassG
bpat_hi: !byte >bsilent,>bassAm,>bassF,>bassC,>bassG
dpat_lo: !byte <dsilent,<d_basic,<d_full,<d_chorus,<d_big,<d_lift,<d_pshhh
dpat_hi: !byte >dsilent,>d_basic,>d_full,>d_chorus,>d_big,>d_lift,>d_pshhh
lpat_lo: !byte <lsilent,<leadAm,<leadF,<leadC,<leadG,<verseA,<leadUp,<leadEAm,<leadEF,<leadEC,<leadEG
lpat_hi: !byte >lsilent,>leadAm,>leadF,>leadC,>leadG,>verseA,>leadUp,>leadEAm,>leadEF,>leadEC,>leadEG

freqlo:
        !byte $16,$27,$39,$4b,$5f,$74,$8a,$a1,$ba,$d4,$f0,$0e,$2d,$4e,$71,$96,$be,$e7,$14,$42,$74,$a9,$e0,$1b,$5a,$9c,$e2,$2d,$7b,$cf,$27,$85,$e8,$51,$c1,$37,$b4,$38,$c4,$59,$f7,$9d,$4e,$0a,$d0,$a2,$81,$6d,$67,$70,$89,$b2,$ed,$3b,$9c,$13,$a0,$45,$02,$da,$ce,$e0,$11,$64,$da,$76,$39,$26,$40,$89,$04,$b4,$9c,$c0,$23,$c8,$b4,$eb,$72,$4c,$80,$12,$08,$68,$39,$80,$45,$90,$68,$d6,$e3,$99,$00,$24,$10,$d0
freqhi:
        !byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08,$08,$09,$09,$0a,$0a,$0b,$0c,$0d,$0d,$0e,$0f,$10,$11,$12,$13,$14,$15,$17,$18,$1a,$1b,$1d,$1f,$20,$22,$24,$27,$29,$2b,$2e,$31,$34,$37,$3a,$3e,$41,$45,$49,$4e,$52,$57,$5c,$62,$68,$6e,$75,$7c,$83,$8b,$93,$9c,$a5,$af,$b9,$c4,$d0,$dd,$ea,$f8,$06

frame_cnt:  !byte 0
step:       !byte 0
song_flags: !byte 0
kick_env:   !byte 0
lead_env:   !byte 0
lead_visual_env: !byte 0 ; OPT52 melody/lead-triggered visual shimmer envelope
lead_visual_type: !byte 0 ; 0 none, 1 normal lead, 2 chorus/sync lead
bass_env:   !byte 0
drum_env:   !byte 0
flt_lfo:    !byte 0
flt_cnt:    !byte 0
drum_visual_type: !byte 0 ; 0 none, 1 kick, 2 snare, 3 hat, 4 crash, 5 lift, 6 pshhh
drum_visual_env:  !byte 0
pwm_phase:  !byte 0
v2_gate_ctl:!byte 0
v2_off_ctl: !byte 0
v1_base_lo: !byte 0
v1_base_hi: !byte 0
v2_base_lo: !byte 0
v2_base_hi: !byte 0
space_latch:!byte 0
skip_request:!byte 0
skip_cooldown:!byte 0
top_section_index: !byte 0 ; OPT51 current SPACE top-section slot 0..9
music_jump_mode: !byte 0 ; OPT53 SPACE cycles music transition 0..3
music_jump_env:  !byte 0 ; OPT53 short transition marker
skip_target_lo: !byte 0
skip_target_hi: !byte 0
frame_tick: !byte 0
vis_frame: !byte 0
cube_spin_env: !byte 0 ; OPT59 beat spin duration/energy
cube_spin_dir: !byte 0 ; OPT59 0=forward, 1=reverse transient spin
cube_spin_step: !byte 0 ; OPT59 1..3 frame phases per visual tick while spinning
cube_spin_base_dir: !byte 0 ; OPT60 persistent idle spin direction, 0=forward, 1=reverse
vis_char:  !byte 0
vis_color: !byte 0
plot_x:    !byte 0
plot_y:    !byte 0
shimmer_phase: !byte 0
shimmer_mode: !byte 0
pshhh_env: !byte 0
prev_cube_index: !byte $ff
cube_stream_guard: !byte 0
eyecandy_phase: !byte 0
eyecandy_char: !byte 0
eyecandy_color: !byte 0
effect_mode: !byte 0 ; OPT44 SPACE cycles 0..3 panel/effect preset
tail_mode: !byte 0   ; OPT44 SPACE cycles 0=no tail,1/2/3=safe cube trails
beat_pulse_env: !byte 0 ; OPT46 global drum pulse envelope for zoom/sparks
beat_spark_phase: !byte 0
beat_spark_char: !byte 0
beat_spark_color: !byte 0
prev_tail_index1: !byte $ff
prev_tail_index2: !byte $ff
visual_clear_request: !byte 0
sidechain_env: !byte 0
bass_tail: !byte 0
lead_tail: !byte 0
legato_phase: !byte 0
cube_scale_env: !byte 0
cube_glow_env: !byte 0
mix_glue_env: !byte 0
