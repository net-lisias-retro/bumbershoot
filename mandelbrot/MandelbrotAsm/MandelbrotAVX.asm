;;; *********************************************************************
;;; MANDELBROT SET GENERATOR
;;; Vectorized AVX2 x86_64 floating-point implementation
;;; (c) 2024 Michael C. Martin
;;; Made available under the MIT License; see README.md
;;; *********************************************************************

	OPTION AVXENCODING:NO_EVEX

	_text	SEGMENT

mandelbrotAVX	PROC FRAME
	push	rdi
	.PUSHREG rdi
	push	rsi
	.PUSHREG rsi
	sub	rsp, 104
	.ALLOCSTACK 104
	movdqa	[rsp], xmm6
	.SAVEXMM128 xmm6, 0
	movdqa	[rsp+16], xmm7
	.SAVEXMM128	xmm7, 16
	movdqa	[rsp+32], xmm8
	.SAVEXMM128 xmm8, 32
	movdqa	[rsp+48], xmm9
	.SAVEXMM128 xmm9, 48
	movdqa	[rsp+64], xmm10
	.SAVEXMM128 xmm10, 64
	movdqa	[rsp+80], xmm11
	.SAVEXMM128 xmm11, 80
	.ENDPROLOG
	;; Juggle arguments so that they look like we used the Linux ABI internally
	mov	edi, r9d
	mov	rsi, [rsp+160]

	;; Quit immediately if edge is nonpositive or vals is null.
	test	edi,edi
	jle	finis
	test	rsi,rsi
	jz	finis
	;; Also quit immediately if edge isn't divisible by 4.
	mov	eax,edi
	and	eax,3
	jnz	finis

	;; Set up constants we'll use in the main loop. Rarely used constants
	;; are put into xmm8+ since instructions using those are longer.
	vzeroupper			; remove any phantom ymm hazards
	vbroadcastsd	ymm8,four	; ymm8 = 4.0 x 4
	movapd	xmm9,xmm0		; ymm9 = xmin
	movapd	xmm10,xmm1		; ymm10 = ymax
	cvtsi2sd	xmm11,edi	; ymm11 = step (width / edge)
	divsd	xmm2,xmm11
	movapd	xmm11,xmm2
	vbroadcastsd	ymm9,xmm9	; Replicate constants to all
	vbroadcastsd	ymm10,xmm10	; entries in the YMM registers
	vbroadcastsd	ymm11,xmm11
	vmulpd	ymm12,ymm11,steps	; ymm12 = 0/1/2/3 * step

	;; At this point xmm0-7 are all free for use in the inner loop. For
	;; this scalar implementation, xmm7 is unused, but we'll need it
	;; once we start parallelizing.

	;; Row and column iterators. Set up row or point-specific constants.
	xor	r8d,r8d			; Row iterator
rows:	neg	r8d
	cvtsi2sd	xmm1,r8d	; y = (-iy * step) + ymax
	neg	r8d
	mulsd	xmm1,xmm11
	addsd	xmm1,xmm10
	vbroadcastsd	ymm1,xmm1	; Both pixels have identical y

	xor	r9d,r9d			; Column iterator
cols:	cvtsi2sd	xmm0,r9d	; x = (ix * step) + xmin
	vbroadcastsd	ymm0,xmm0
	vmulpd	ymm0,ymm0,ymm11
	vaddpd	ymm0,ymm0,ymm12
	vaddpd	ymm0,ymm0,ymm9

	;; Apply Z = Z*Z+C until |Z|>4 or 1000 iterations
	xor	edx,edx			; Clear iteration count
	vpxor	ymm2,ymm2,ymm2		; Start at 0 + 0i
	vpxor	ymm3,ymm3,ymm3
	vpxor	ymm7,ymm7,ymm7		; Start at 0 count
do_pt:	vmulpd	ymm4,ymm2,ymm2		; store squares of Z's
	vmulpd	ymm5,ymm3,ymm3		; components
	vaddpd	ymm6,ymm4,ymm5		; |Z| <= 4?
	vcmplepd	ymm6,ymm6,ymm8
	vpsubq	ymm7,ymm7,ymm6		; Contribute true results to sum
	vmovmskpd	ecx,ymm6	; Were *any* cells incremented?
	test	ecx,ecx
	jz	found
	vmulpd	ymm3,ymm3,ymm2		; b=2ab+y
	vsubpd	ymm4,ymm4,ymm5		; a2 = a2-b2+x
	vaddpd	ymm3,ymm3,ymm3
	vaddpd	ymm2,ymm4,ymm0		; a = a2
	vaddpd	ymm3,ymm3,ymm1
	inc	edx
	cmp	edx,1000
	jb	do_pt

	;; Write iteration count into output buffer and increment result
found:	movd	edx,xmm7
	mov	[rsi],dx
	unpckhpd	xmm7,xmm7
	movd	edx,xmm7
	mov	[rsi+2],dx
	vextractf128	xmm7,ymm7,1
	movd	edx,xmm7
	mov	[rsi+4],dx
	unpckhpd	xmm7,xmm7
	mov	[rsi+6],dx
	add	rsi,8

	;; Wrap up the column and row loops.
	add	r9d,4
	cmp	r9d,edi
	jl	cols
	inc	r8d
	cmp	r8d,edi
	jl	rows

finis:
	movdqa	xmm11, [rsp+80]
	movdqa	xmm10, [rsp+64]
	movdqa	xmm9, [rsp+48]
	movdqa	xmm8, [rsp+32]
	movdqa	xmm7, [rsp+16]
	movdqa	xmm6, [rsp]
	add	rsp, 104
	pop	rsi
	pop	rdi
	ret
mandelbrotAVX	ENDP

	_text	ENDS

	_data	SEGMENT
	align	16
steps	REAL8	0.0, 1.0, 2.0, 3.0
four REAL8	4.0
	_data	ENDS
	END
