	.p816
	.a16
	.i16

	.import	RESET, lz4dec, rnd, seed_rnd
	.import	init_pixmap, make_pixmap, load_pixmap
	.import	init_cca, step_cca
	.export	main

	.segment "TITLE"
	.byte "CYCLIC CELLULAR AUTO "

	;; https://snes.nesdev.org/wiki/ROM_header
	.segment "ROMINFO"
	.byte	$30			; FastROM, LoROM
	.byte	0
	.byte	$06			; 64KB
	.byte	0,0,0,0
	.word	$aaaa, $5555

	.segment "VECTORS"
	.addr	0,0,0,0,0,VBLANK,0,0
	.addr	0,0,0,0,0,0,RESET,0

	.zeropage
xscr:	.res	2
yscr:	.res	2
draw_state:
	.res	1

        ;; draw_state enum
GLOBAL_IDLE = 0
CCA_IDLE    = 1
CCA_BLIT2   = 2
CCA_BLIT1   = 3

.macro	blit
	.local	lp
	lda	#CCA_IDLE
lp:	cmp	draw_state
	bne	lp
	lda	#CCA_BLIT1
	sta	draw_state
.endmacro

	.segment "CODE"

.proc	main
	sep	#$20
	rep	#$10
	.a8
	.i16

	phk
	plb

	lda	#$01			; Enable FastROM
	sta	$420d

	stz	$4300			; DMA0: linear forward copy A->B
	lda	#$22			; into CGRAM
	sta	$4301
	stz	$2121			; Load palette starting at 0
	lda	#^colors		; Set DMA source address
	ldx	#(colors & $ffff)
	stx	$4302
	sta	$4304
	ldx	#colors_end-colors	; Set DMA transfer size
	stx	$4305
	lda	#$01			; Send DMA
	sta	$420b

	lda	#^gfxdat		; Decompress into WRAM
	ldx	#(gfxdat & $ffff)
	ldy	#$0000
	jsr	lz4dec

	lda	#$01			; Blit result into VRAM
	sta	$4300
	lda	#$18
	sta	$4301
	stx	$4305			; "Final address" is length
	lda	#$7f
	ldx	#$0000
	stx	$4302
	sta	$4304
	stz	$2116			; Copy into VRAM $0000
	stz	$2117
	lda	#$01
	sta	$420b

	jsr	init_pixmap

	ldx	#$0000			; zero out the scroll registers
	stx	xscr
	stx	yscr
	lda	#CCA_IDLE		; and initialize draw state
	sta	draw_state

	rep	#$20
	.a16
	lda	#$000a			; Match sega port for now
	ldx	#$0001
	jsr	seed_rnd
	sep	#$20
	.a8

	jsr	init_cca

	lda	#$7f
	ldx	#$0000
	jsr	make_pixmap
	ldx	#$6000
	ldy	#$8000
	jsr	load_pixmap
	ldx	#$7000
	ldy	#$9000
	jsr	load_pixmap

	lda	#$01			; Mode 1, 4BPP/4BPP/2BPP
	sta	$2105
	lda	#$63			; BG1 Tilemap at $6000, 64x64
	sta	$2107
	lda	#$73			; BG2 Tilemap at $7000, 64x64
	sta	$2108
	lda	#$03			; Enable BG1 and BG2
	sta	$212c
	lda	#$0f			; Enable display
	sta	$2100

	lda	$4210			; Clear VBLANK flag
	lda	#$81			; Enable joypad auto-read
	sta	$4200			; and VBLANK NMI

loop:	ldx	#$0000
	ldy	#$4000
	jsr	step_cca

	lda	#$7f
	ldx	#$0000
	jsr	make_pixmap
	blit

	ldx	#$4000
	ldy	#$0000
	jsr	step_cca

	lda	#$7f
	ldx	#$4000
	jsr	make_pixmap
	blit
	bra	loop
.endproc

.proc	VBLANK
	jml	:+
:	rep	#$30
	phb
	pha
	phx
	phy
	sep	#$30			; Need .i8 here so that TAX
	.a8				; doesn't pollute our jump address
	.i8				; with the leftover accumulator high
	lda	#$80			; byte, even in .a8 mode!
	pha
	plb
	lda	draw_state
	asl	a
	tax
	rep	#$10
	.i16
	jmp	(vtable,x)
vtable:	.addr	do_global_idle, do_cca_idle, do_cca_blit2, do_cca_blit1

do_cca_blit1:
	ldx	#$6000
	ldy	#$8000
	bra	doblit

do_cca_blit2:
	ldx	#$7000
	ldy	#$9000
	;; Fall through to doblit

doblit:	jsr	load_pixmap
	jsr	read_joy
	dec	draw_state
	bra	done

do_cca_idle:
	jsr	wait_for_joy
	jsr	read_joy		; TODO: Handle start button

do_global_idle:
done:	rep	#$30
	ply
	plx
	pla
	plb
	rti
.endproc

	;; Wait until the controller has started, then finished, reading.
.proc	wait_for_joy
:	lda	$4212			; Has the controller started reading?
	lsr	a
	bcc	:-
:	lda	$4212			; Is the controller ready?
	lsr	a
	bcs	:-
	rts
.endproc

	;; Read controller. Update x_scr and y_scr, START in carry
.proc	read_joy
	lda	$4219			; Read the directional part
	rep	#$20			; We'll need 16-bit memory here
	.a16
	lsr	a			; Right?
	bcc	:+
	inc	xscr
:	lsr	a
	bcc	:+			; Left?
	dec	xscr
:	lsr	a			; Down?
	bcc	:+
	inc	yscr
:	lsr	a			; Up?
	bcc	:+
	dec	yscr
:	sep	#$30			; Set scroll values
	.a8
	.i8
	ldx	xscr
	ldy	xscr+1
	stx	$210d
	sty	$210d
	stx	$210f
	sty	$210f
	ldx	yscr
	ldy	yscr+1
	stx	$210e
	sty	$210e
	stx	$2110
	sty	$2110
	lsr	a			; Start?
	rep	#$10
	.i16
	rts
.endproc

colors:	.incbin "res/bumberpal.bin"
colors_end:

gfxdat:	.incbin "res/lz4gfx.bin"
musdat: .incbin "res/lz4mus.bin"

	.segment "BANK1"
digidata:
	.incbin "spc_digi.bin", $200
digidata_end:
