; vim: set et ts=8 sw=8 sts=8 fdm=marker syntax=64tass:

        SID_NAME = "Old_Level_2.sid"
        SID_LOAD = $1000
        SID_INIT = $1000
        SID_PLAY = $1003

        BG_COLOR = $0b
        FG_COLOR = $0d

        BITMAP = $2000

        ZP = $02

        PLOT_SPEEDCODE = $4000
        CLEAR_SPEEDCODE = $6000

        PLOT_COUNT = 256
        PLOT_INDEX = ZP + 16


; @brief        Add 40 to word at \1
;
; @clobbers     A,C
; @safe         X,Y
add40 .macro
        lda \1
        clc
        adc #40
        sta \1
        bcc +
        inc \1 + 1
+
.endm


;------------------------------------------------------------------------------
; BASIC SYS line
;------------------------------------------------------------------------------
        * = $0801

        .word (+), 2017
        .null $9e, format("%d", start)
+       .word 0

start
        jmp init

init
        jsr $fda3
        sei
        lda #$35
        sta $01
        lda #$7f
        sta $dc0d
        ldx #0
        stx $dc0e
        inx
        stx $d01a
        lda #0
        sta $d020
        lda #BG_COLOR
        sta $d021

        ; clear screen
        ldx #0
-       lda #$20
        sta $0400,x
        sta $0500,x
        sta $0600,x
        sta $06e8,x
        lda #BG_COLOR
        sta $d800,x
        sta $d900,x
        sta $da00,x
        sta $dae8,x
        inx
        bne -

        ; clear plot area
        ldx #0
        txa
-
    .for row = 0, row < 8, row +=1
        sta BITMAP + row * 256,x
    .next
        inx
        bne -


        jsr render_matrix
        jsr precalc_sinus

        jsr prepare_speedcode

        jsr render_x_movement

        lda #0
        sta PLOT_INDEX
        jsr SID_INIT

        lda $dc0d
        lda $dd0d
        lda $d019

        lda #$1b
        sta $d011
        lda #$32
        sta $d012

        lda #<irq1
        ldx #>irq1
        sta $fffe
        stx $ffff
        lda #<nmi
        ldx #>nmi
        sta $fffc
        stx $fffd
        sta $fffa
        stx $fffb

        lda #$091
        sta $d019
        cli
        jmp *

; Play music
irq1
        pha
        txa
        pha
        tya
        pha

        lda #$18
        sta $d018

        dec $d020
        jsr SID_PLAY
        inc $d020

        lda #<irq2
        ldx #>irq2
        ldy #$72
do_irq
        sta $fffe
        stx $ffff
        sty $d012

        inc $d019
        pla
        tya
        pla
        tax
        pla
nmi     rti

irq2
        pha
        txa
        pha
        tya
        pha

        ldx #7
-       dex
        bne -

        lda #$15
        sta $d018
        lda #5
        sta $d020

        ldx PLOT_INDEX
        lda #0
        jsr CLEAR_SPEEDCODE

        lda #2
        sta $d020

        inc PLOT_INDEX
        ldx PLOT_INDEX

        jsr PLOT_SPEEDCODE

        lda #0
        sta $d020

        lda #<irq1
        ldx #>irq1
        ldy #$32
        jmp do_irq



; Render charset matrix of 32 x 8 chars
;
; @clobbers     all
;
render_matrix .proc

        vidram = ZP
        colram = ZP + 2

        lda #$04
        ldx #$04
        ldy #$d8

        sta vidram
        stx vidram + 1
        sta colram
        sty colram + 1

        ldx #0
-
        ldy #0
-
        tya
        asl a
        asl a
        asl a
        sta xtmp + 1
        txa
        clc             ; probably not needed, the ASL's don't shift out a bit
xtmp    adc #0
        sta (vidram),y
        lda #FG_COLOR
        sta (colram),y
        iny
        cpy #32
        bne -

        #add40 vidram
        #add40 colram

        inx
        cpx #8
        bne --
        rts
.pend

; requires a sinus of 512 bytes

plot_template
        ldy sinusy,x    ; 0
        lda $2000,y     ; 3
        ora #$00        ; 6
        sta $2000,y     ; 8
plot_template_end


clear_template
        ldy sinusy,x
        sta $2000,y
clear_template_end


; Generate speedcode, filling in the actual operands comes later
;
prepare_speedcode .proc

        dest = ZP

        ; Plotting speedcode

        lda #<PLOT_SPEEDCODE
        ldx #>PLOT_SPEEDCODE
        sta dest
        stx dest +1

        ldx #0
more1
        ldy #plot_template_end - plot_template - 1
-       lda plot_template,y
        sta (dest),y
        dey
        bpl -

        ; set xsinus + offset
        ldy #1
        txa
        sta (dest),y

        lda dest
        clc
        adc #plot_template_end - plot_template
        sta dest
        bcc +
        inc dest + 1
+
        inx
        bne more1

        ldy #0
        lda #$60        ; RTS
        sta (dest),y

        ; Clear speedcode
        lda #<CLEAR_SPEEDCODE
        ldx #>CLEAR_SPEEDCODE
        sta dest
        stx dest +1

        ldx #0
more2
        ldy #clear_template_end - clear_template - 1
-       lda clear_template,y
        sta (dest),y
        dey
        bpl -
        ; patch index
        ldy #1
        txa
        sta (dest),y

        lda dest
        clc
        adc #clear_template_end - clear_template
        sta dest
        bcc +
        inc dest + 1
+
        inx
        bne more2

        ldy #0
        lda #$60
        sta (dest),y
        rts
.pend


render_x_movement .proc

        plot = ZP
        clear = ZP + 2
        index = ZP + 4
        pixel = ZP + 5

        lda #<PLOT_SPEEDCODE
        ldx #>PLOT_SPEEDCODE
        sta plot
        stx plot + 1

        lda #<CLEAR_SPEEDCODE
        ldx #>CLEAR_SPEEDCODE
        sta clear
        stx clear + 1

        lda #0
        sta index
more
        ldy index
        ldx sinusx,y

        lda xlo,x

        ; store LSB
        ldy #4
        sta (plot),y
        ldy #9
        sta (plot),y
        ldy #4
        sta (clear),y

        ; store MSB
        lda xhi,x
        ldy #5
        sta (plot),y
        ldy #10
        sta (plot),y
        ldy #5
        sta (clear),y

        ; store ORA bit
        lda xbit,x
        ldy #7
        sta (plot),y

        lda plot
        clc
        adc #plot_template_end - plot_template
        sta plot
        bcc +
        inc plot + 1
+
        lda clear
        clc
        adc #clear_template_end - clear_template
        sta clear
        bcc +
        inc clear +1
+
        inc index
        bne more
        rts
.pend

params

xoff1   .byte 0
xadc1   .byte $fe
xspd1   .byte 1

xoff2   .byte 40
xadc2   .byte 1
xspd2   .byte 1

yoff1   .byte 72
yadc1   .byte 4
yspd1   .byte 3

yoff2   .byte 0
yadc2   .byte $fd
yspd2   .byte 1

params_end


; Precalculate both X and Y sinus tables
;
; @clobbers     all
;
precalc_sinus   .proc

        xidx1 = ZP
        xidx2 = ZP + 1
        yidx1 = ZP + 2
        yidx2 = ZP + 3

        lda xoff1
        sta xidx1
        lda xoff2
        sta xidx2

        lda yoff1
        sta yidx1
        lda yoff2
        sta yidx2

        ldx #0
-
        ldy xidx1
        lda xsinus1,y
        clc
        ldy xidx2
        adc xsinus2,y
        sta sinusx,x
        sta sinusx + 256,x

        ldy yidx1
        lda ysinus1,y
        clc
        ldy yidx2
        adc ysinus2,y
        sta sinusy,x
        sta sinusy + 256,x

        lda xidx1
        clc
        adc xadc1
        sta xidx1
        lda xidx2
        clc
        adc xadc2
        sta xidx2

        lda yidx1
        clc
        adc yadc1
        sta yidx1
        lda yidx2
        clc
        adc yadc2
        sta yidx2

        inx
        bne -
        rts
.pend



        * = $2800
;
; Various tables: source and target sinus tables and helper tables
;

        .align 256

        ; $00-$bf
xsinus1 .byte 95.5 + 95.5 * sin(range(256) * rad(360.0/256))
        ; $00-$3f
xsinus2 .byte 31.5 + 31.5 * sin(range(256) * rad(360.0/256))

        ; $00-$2f
ysinus1 .byte 23.5 + 23.5 * sin(range(256) * rad(360.0/256))
        ; $00-$0f
ysinus2 .byte 7.5 + 7.5 * sin(range(256) * rad(360.0/256))


sinusx  .fill PLOT_COUNT * 2, 0
sinusy  .fill PLOT_COUNT * 2, 0

; Helper tables


xlo
    .for msb = 0, msb < 8, msb += 1
        .fill 8, $00
        .fill 8, $40
        .fill 8, $80
        .fill 8, $c0
    .next

xhi
    .for msb = 0, msb < 8, msb += 1
        .fill 32, >(BITMAP + msb * 256)
    .next

xbit
    .for b = 0, b < 512, b += 1
        .byte 1 << (7 - (b & 7))
    .next


;
; Some music, an awesome old tune by Link
;
        * = SID_LOAD

.binary SID_NAME, $7e
