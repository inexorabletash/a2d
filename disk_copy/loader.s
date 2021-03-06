;;; ============================================================
;;; Overlay for Disk Copy - $1800 - $19FF (file 2/4)
;;;
;;; Compiled as part of desktop.s
;;; ============================================================

;;; Within `disk_copy` scope, settings are an overlay on top of
;;; the auxlc segment in the aux LC.

SETTINGS := $F180

.proc part2
        .org $1800

        jmp     start

;;; ============================================================

io_buf := $1C00
load_buf := $4000

        DEFINE_OPEN_PARAMS open_params, filename, io_buf
filename:   PASCAL_STRING kFilenameDeskTop

        DEFINE_READ_PARAMS read_params, 0, 0
        DEFINE_SET_MARK_PARAMS set_mark_params, kOverlayDiskCopy3Offset
        DEFINE_CLOSE_PARAMS close_params

        .byte   $00,$00

buf1:   .addr   load_buf
dest1:  .addr   kOverlayDiskCopy3Address
len1:   .word   kOverlayDiskCopy3Length

buf2:   .addr   kOverlayDiskCopy4Address
len2:   .word   kOverlayDiskCopy4Length

;;; ============================================================

start:
        ;; Set stack pointers to arbitrarily low values for use when
        ;; interrupts occur. DeskTop does not utilize this convention,
        ;; so the values are set low so that interrupts which do (for
        ;; example, the IIgs Control Panel) don't trash DeskTop's use
        ;; of the stacks.
        ;; See the Apple IIe Technical Reference Manual, pp. 153-154
        lda     #$41
        sta     ALTZPON
        sta     $0100           ; Main stack pointer, in Aux ZP
        sta     $0101           ; Aux stack pointer, in Aux ZP
        sta     ALTZPOFF

        ;; Free up system bitmap
        ldx     #BITMAP_SIZE-3
        lda     #0
L183F:  sta     BITMAP+1,x
        dex
        bpl     L183F

        MLI_CALL OPEN, open_params
        bcs     fail
        lda     open_params::ref_num
        sta     read_params::ref_num
        sta     set_mark_params::ref_num

        MLI_CALL SET_MARK, set_mark_params
        bcs     fail
        copy16  buf1, read_params::data_buffer
        copy16  len1, read_params::request_count
        MLI_CALL READ, read_params
        bcs     fail
        jsr     copy_to_lc

        copy16  buf2, read_params::data_buffer
        copy16  len2, read_params::request_count
        MLI_CALL READ, read_params
        bcs     fail
        MLI_CALL CLOSE, close_params
        bcs     fail

        jsr     load_settings

        sta     ALTZPON
        lda     LCBANK1
        lda     LCBANK1

        jmp     auxlc__start

;;; This mimics the original behavior - just hang if the load fails.
;;; TODO: Do something better here, e.g. ProDOS QUIT.
fail:   jmp     fail

;;; ============================================================
;;; Copy first chunk to the Language Card

.proc copy_to_lc
        src := $6
        end := $8
        dst := $A

        ;; Bank in AUX LC
        sta     ALTZPON
        lda     LCBANK1
        lda     LCBANK1
        txa
        asl     a
        tax

        ;; Set up pointers
        lda     buf1
        sta     src
        clc
        adc     len1
        sta     end
        lda     buf1+1
        sta     src+1
        adc     len1+1
        sta     end+1
        lda     dest1
        sta     dst
        lda     dest1+1
        sta     dst+1

        ;; Do the copy
        ldy     #0
loop:   lda     (src),y
        sta     (dst),y
        inc     src
        inc     dst
        lda     src
        bne     :+
        inc     src+1
        inc     dst+1
:       lda     src+1
        cmp     end+1
        bne     loop
        lda     src
        cmp     end
        bne     loop

        ;; Bank in ROM
        sta     ALTZPOFF
        lda     ROMIN2
        rts
.endproc

;;; ============================================================

        ;; Already .included: "../lib/load_settings.s"
        DEFINEPROC_LOAD_SETTINGS io_buf, load_buf

;;; ============================================================

        PAD_TO $1A00

.endproc ; part2