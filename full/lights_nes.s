        .segment "HEADER"
        .byte   "NES",$1a,$01,$01,$01,$00

        .import __OAM_START__

        .zeropage
zptr:   .res    2
count:  .res    1

        .code
reset:  sei
        cld

        ;; Wait two frames.
        bit     $2002
:       bit     $2002
        bpl     :-
:       bit     $2002
        bpl     :-

        ;; Mask out sound IRQs.
        lda     #$40
        sta     $4017
        lda     #$00
        sta     $4010

        ;; Disable all graphics.
        sta     $2000
        sta     $2001

        ;; Clear out RAM.
        tax
:       sta     $000,x
        sta     $100,x
        sta     $200,x
        sta     $300,x
        sta     $400,x
        sta     $500,x
        sta     $600,x
        sta     $700,x
        inx
        bne     :-

        ;; Reset the stack pointer.
        dex
        txs

        ;; Clear out SPR-RAM.
        lda     #>__OAM_START__
        sta     $4014

        ;; Clear out the name tables at $2000-$2400.
        lda     #$20
        sta     $2006
        lda     #$00
        sta     $2006
        ldx     #$08
        tay
:       sta     $2007
        iny
        bne     :-
        dex
        bne     :-

        ;; Load the initial screen into place

        ;; Draw the title
        lda     #<screen_logo
        ldx     #>screen_logo
        jsr     rom_to_vidbuf
        jsr     vram_writes

        ;; Draw board edges and first row
        lda     #<init_screen
        ldx     #>init_screen
        jsr     rom_to_vidbuf
        jsr     vram_writes

        ;; Truncate to first draw command
        lda     #$00
        sta     vidbuf+init_screen_row-init_screen

        ;; Change the upper-left tile for mid-board rows
        lda     #$09
        sta     vidbuf+3

        ;; And draw four more copies of it down the screen
        lda     #$04
        sta     count
:       clc
        lda     vidbuf+1
        adc     #64
        sta     vidbuf+1
        bcc     :+
        inc     vidbuf+2
:       jsr     vram_writes
        dec     count
        bne     :--

        lda     #$00
        sta     vidbuf

        ;; The board is shfited 8 pixels right so buttons and attribute table cells line up.
        ;; Set basic PPU registers. Load everything from $0000,
        ;; and use the $2000 nametable. Don't hide the left 8 pixels.
        ;; Don't enable sprites.
        lda     #$80
        sta     $2000
        lda     #$0e
        sta     $2001
        cli

loop:   jmp     loop

irq:    rti

vblank: pha
        txa
        pha
        tya
        pha

        lda     #>__OAM_START__ ; Update sprite data
        sta     $4014

        jsr     vram_writes     ; Update name/attr tables

        lda     #$08            ; Reset scroll
        sta     $2005
        sta     $2005

        ;; TODO: Update controllers

        pla
        tay
        pla
        tax
        pla
        rti

        .bss
        .align 128
vidbuf: .res 128

        .code

rom_to_vidbuf:
        sta     zptr
        stx     zptr+1
        ldy     #$00
@lp:    lda     (zptr),y
        beq     @done
        sta     vidbuf,y
        iny
        tax
        inx
        inx
@blk:   lda     (zptr),y
        sta     vidbuf,y
        iny
        dex
        bne     @blk
        beq     @lp
@done:  rts

vram_writes:
        ldy     #$00
@lp:    lda     vidbuf,y
        beq     @done
        iny
        tax
        lda     vidbuf+1,y
        sta     $2006
        lda     vidbuf,y
        sta     $2006
        iny
        iny
@blk:   lda     vidbuf,y
        sta     $2007
        iny
        dex
        bne     @blk
        beq     @lp
@done:  rts


        .segment "VECTORS"
        .word   vblank,reset,irq

        .segment "RODATA"

init_screen:
        .byte   44
        .word   $214b
        .byte   8,1,2,1,2,1,2,1,2,1,2,10,0,0,0,0
        .byte   0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
        .byte   9,3,4,3,4,3,4,3,4,3,4,10
init_screen_row:
        .byte   12
        .word   $212b
        .byte   5,6,6,6,6,6,6,6,6,6,6,7
        .byte   12
        .word   $228b
        .byte   11,12,12,12,12,12,12,12,12,12,12,13
        .byte   32
        .word   $3f00
        .byte   $0f,$00,$0f,$10,$0f,$00,$16,$10,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
        .byte   $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f
        .byte   0

screen_logo:
        .byte   12
        .word   $208b
        .byte   14,15,16,17,18,19,20,21,22,23,24,25
        .byte   16
        .word   $20a9
        .byte   26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41
        ;; Temporary: Set some stuff in the attribute tables so we
        ;; have a pretty pattern
        .byte   3
        .word   $23d3
        .byte   $50,$40,$10
        .byte   3
        .word   $23db
        .byte   $41,$51,$01
        .byte   3
        .word   $23e3
        .byte   $51,$41,$11
        ;; End temporary section
        .byte   0

        .segment "CHR0"
        ;; 0: Blank
        .byte   $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        ;; 1-4: Button (NW-NE-SW-SE)
        .byte   $ff,$e0,$c0,$c0,$c0,$c0,$c0,$c0,$ff,$ff,$ff,$bf,$bf,$bf,$bf,$bf
        .byte   $ff,$03,$01,$01,$01,$01,$01,$01,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
        .byte   $c0,$c0,$c0,$c0,$c0,$e0,$ff,$ff,$bf,$bf,$bf,$bf,$bf,$9f,$c0,$ff
        .byte   $01,$01,$01,$01,$01,$03,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$07,$ff
        ;; 5-7: Board top (NW-N-NE)
        .byte   $00,$00,$00,$00,$00,$01,$03,$07,$00,$00,$00,$00,$00,$01,$03,$06
        .byte   $00,$00,$00,$00,$00,$ff,$ff,$ff,$00,$00,$00,$00,$00,$ff,$ff,$ff
        .byte   $00,$00,$00,$00,$00,$80,$c0,$e0,$00,$00,$00,$00,$00,$80,$c0,$60
        ;; 8: First Board Edge W
        .byte   $0f,$0f,$1f,$1f,$1f,$1f,$1f,$1f,$07,$07,$07,$07,$07,$07,$07,$07
        ;; 9: Board Edge W
        .byte   $1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f,$07,$07,$07,$07,$07,$07,$07,$07
        ;; 10: Board Edge E
        .byte   $e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0,$e0
        ;; 11-13: Board bottom (SW-S-SE)
        .byte   $1f,$1f,$1f,$0f,$07,$00,$00,$00,$06,$03,$01,$00,$00,$00,$00,$00
        .byte   $ff,$ff,$ff,$ff,$ff,$00,$00,$00,$ff,$ff,$ff,$00,$00,$00,$00,$00
        .byte   $e0,$c0,$c0,$80,$00,$00,$00,$00,$60,$c0,$80,$00,$00,$00,$00,$00
        ;; 14-41: Logo (12, then 16 tiles)
        .byte   $00,$01,$00,$01,$01,$03,$03,$06,$00,$01,$00,$01,$01,$03,$03,$06
        .byte   $00,$f0,$c0,$80,$80,$00,$00,$11,$00,$f0,$c0,$80,$80,$00,$00,$11
        .byte   $00,$f3,$66,$4c,$cc,$98,$98,$98,$00,$f3,$66,$4c,$cc,$98,$98,$98
        .byte   $00,$d3,$31,$21,$01,$03,$02,$e6,$00,$d3,$31,$21,$01,$03,$02,$e6
        .byte   $00,$9e,$0c,$08,$08,$f8,$08,$08,$00,$9e,$0c,$08,$08,$f8,$08,$08
        .byte   $00,$fe,$92,$10,$10,$10,$30,$30,$00,$fe,$92,$10,$10,$10,$30,$30
        .byte   $00,$3a,$66,$62,$70,$38,$1c,$0e,$00,$3a,$66,$62,$70,$38,$1c,$0e
        .byte   $00,$03,$06,$0c,$0c,$0c,$0c,$06,$00,$03,$06,$0c,$0c,$0c,$0c,$06
        .byte   $00,$c7,$63,$31,$19,$19,$19,$0c,$00,$c7,$63,$31,$19,$19,$19,$0c
        .byte   $00,$bb,$8a,$08,$0c,$84,$84,$84,$00,$bb,$8a,$08,$0c,$84,$84,$84
        .byte   $00,$fd,$65,$20,$30,$30,$10,$18,$00,$fd,$65,$20,$30,$30,$10,$18
        .byte   $00,$80,$80,$c0,$c0,$20,$20,$10,$00,$80,$80,$c0,$c0,$20,$20,$10
        .byte   $00,$00,$00,$00,$00,$05,$2a,$00,$00,$00,$00,$00,$00,$05,$2a,$00
        .byte   $00,$00,$00,$00,$00,$ff,$ff,$00,$00,$00,$00,$00,$00,$ff,$ff,$00
        .byte   $06,$0c,$1f,$00,$00,$ff,$ff,$00,$06,$0c,$1f,$00,$00,$ff,$ff,$00
        .byte   $31,$63,$e7,$00,$00,$ff,$ff,$00,$31,$63,$e7,$00,$00,$ff,$ff,$00
        .byte   $18,$18,$8f,$00,$00,$ff,$ff,$00,$18,$18,$8f,$00,$00,$ff,$ff,$00
        .byte   $46,$c6,$8f,$00,$00,$ff,$ff,$00,$46,$c6,$8f,$00,$00,$ff,$ff,$00
        .byte   $18,$18,$3c,$00,$00,$ff,$ff,$00,$18,$18,$3c,$00,$00,$ff,$ff,$00
        .byte   $30,$30,$78,$00,$00,$ff,$ff,$00,$30,$30,$78,$00,$00,$ff,$ff,$00
        .byte   $46,$66,$5c,$00,$00,$ff,$ff,$00,$46,$66,$5c,$00,$00,$ff,$ff,$00
        .byte   $06,$03,$01,$00,$00,$ff,$ff,$00,$06,$03,$01,$00,$00,$ff,$ff,$00
        .byte   $0c,$18,$f0,$00,$00,$ff,$ff,$00,$0c,$18,$f0,$00,$00,$ff,$ff,$00
        .byte   $86,$c6,$7c,$00,$00,$ff,$ff,$00,$86,$c6,$7c,$00,$00,$ff,$ff,$00
        .byte   $08,$0c,$1e,$00,$00,$ff,$ff,$00,$08,$0c,$1e,$00,$00,$ff,$ff,$00
        .byte   $00,$18,$18,$00,$00,$ff,$ff,$00,$00,$18,$18,$00,$00,$ff,$ff,$00
        .byte   $00,$00,$00,$00,$00,$ff,$ff,$00,$00,$00,$00,$00,$00,$ff,$ff,$00
        .byte   $00,$00,$00,$00,$00,$a0,$54,$00,$00,$00,$00,$00,$00,$a0,$54,$00