VDP_DATA	= $C00000
VDP_CONTROL = $C00004
	
SMD_REVISION 	= $A10001
TMSS_REGISTER	= $A14000

SPRITE_TABLE = $D800
	

TYPE_VRAM = %100001
TYPE_CRAM = %101011
VIA_DMA = %100111
WRITE   = %000111
	
VDP_ADDRESS:	 macro 
	move.l	#(((\2 & \3) & 3) << 30) | ((\1 & $3FFF) << 16) | (((\2 & \3) & $FC) << 2) | ((\1 & $C000) >> 14), (VDP_CONTROL).l
endm
	
VDP_ADDRESS_TO_REG:	 macro 
	move.l	#(((\2 & \3) & 3) << 30) | ((\1 & $3FFF) << 16) | (((\2 & \3) & $FC) << 2) | ((\1 & $C000) >> 14), (\4)
endm

;; \1 - tile number
;; \2 - X pos (to 1023)
;; \3 - Y pos (to 511)
;; \4 - height(in cells)
;; \5 - width(in cells)
;; \6 - flip data
;; \7 - palette line
;; \8 - priority
;; \9 - link(draw order)
DEFINE_SPRITE:	macro
	dc.w	\3	
	dc.b	(\5 << 2) | \4
	dc.b	\9
	dc.w	(\8 << 15) | (\7 << 13) | (\6 << 11) | \1
	dc.w	\2
endm

;; \1 - above/below
;; \2 - dy offset (up to 15)
DEFINE_LETTER:	macro
	dc.b	(\1 << 4) | \2
endm
	
	
	org 	0
	dc.l	$FF8000
	dc.l    start
	rept 28
		dc.l	handler
	endr
	dc.l	change_color
	rept 33
		dc.l	handler
	endr

	
	dc.b		"SEGA MEGA DRIVE "
	dc.b		"ALTEHEX 2024.FEB"
	dc.b		"HELLO                                           "
	dc.b		"HELLO                                           "
	dc.b		"GM 00000000-02"
	dc.w		$446E
	dc.b		"J               "
	dc.l		$000000, $1FFFFF
	dc.l		$FF0000, $FFFFFF
	dc.b		"            "
	dc.b		"            "
	dc.b		"                                        "
	dc.b		"JUE             "
	

start:
	tst.b	(SMD_REVISION)
	beq.s   rev_0
	move.l  #'SEGA', (TMSS_REGISTER).l
rev_0:
	
	move.w  #$8000, D1
	move.w  #$100, D2
	lea     vdpValues(PC), A1
	lea     (VDP_CONTROL).l, A2
	moveq	#(vdpValuesEnd - vdpValues - 1), D7
vdp_init:
	move.b  (A1)+, D1
	move.w  D1, (A2)
	add.w   D2, D1
	dbf		D7, vdp_init
	
	VDP_ADDRESS_TO_REG	$20, TYPE_VRAM, VIA_DMA, A2
	
	add.w	#$300, D1
	move.l	#((((letterSprites >> 1) & $FF0000) >> 16) | (((letterSprites >> 1) & $FF) << 16) | ((letterSprites >> 1) & $FF00)), D3
	
set_dma_address:
	sub.w	D2, D1
	move.b	D3, D1
	move.w  D1, (A2)
	lsr.l   #8, D3
	bne.s	set_dma_address
	
	move.w  #($9300 + ((letterSpritesEnd - letterSprites) >> 1) & $FF), (A2)
	move.w  #($9400 + (((letterSpritesEnd - letterSprites) >> 1) & $FF00) >> 8), (A2) 
	VDP_ADDRESS_TO_REG	SPRITE_TABLE, TYPE_VRAM, VIA_DMA, A2
	
	lea     letterRecords(PC), A1
	lea		(letterRecordsRam).l, A3
	moveq	#(letterRecordsEnd - letterRecords - 1), D7
create_letters:	
	move.b  (A1)+, (A3)+
	dbf		D7, create_letters

	
	move.w	#$200, D0
	move.w	#$0E0, D2	
	move.b	#232, D4
	lea		deltaY(PC), A3

	move.w	#$816C, (A2)
	move.w	#$8F08, (A2)
	
	move.w	#$2000, SR
main_loop:
	lea		(letterRecordsRam).l, A1
	moveq	#(letterRecordsEnd - letterRecords - 1) >> 2, D7
.regenerate_sprites:	
	move.l	(A1), D1 	; Get the next four letters
	moveq	#4 - 1, D6
.next:
	rol.l	#8, D1		; Move on to the next letter
	move.b	D1, D5
	andi.b	#$F, D5	; Get a dy index (see deltaY below)
	move.b	(A3, D5), D5; Get a dy
	btst   	#4, D1		; Check if we're above or below
	beq		.below
	neg.w	D5			; If above, negate the dy (we'll subtract it)
.below:
	add.w	D4, D5		; Get the final coordinate
	move.w	D5,	VDP_DATA - VDP_CONTROL(A2)	; Copy the final coordinate
	
	addq.b	#1, D1 	 	; Next phase
	dbf 	D6, .next

	move.l	D1, (A1)	; Save letter statuses
	lea  	4(A1), A1	; Move on to the next 4 letters
	dbf		D7, .regenerate_sprites
	
	move.l	#15000, D7
.wait:
	dbf		D7, .wait
	
	bra.s	main_loop

	
change_color:
	add.w	D0, D2
	add.l	#$20000000, D2
	bcc.s	.done

	sub.w	D0, D2
	neg.w	D0
	asr.w	#4, D0
	bne.s	.minus

	move.w	#$200, D0
	bra.s	change_color

.minus:
	btst	#0, D0
	beq.s	change_color

	move.w	#-$200, D0
	bra.s	change_color
	
.done:
	VDP_ADDRESS_TO_REG	$02, TYPE_CRAM, WRITE, A2
	move.w	D2, VDP_DATA - VDP_CONTROL(A2)
	VDP_ADDRESS_TO_REG	SPRITE_TABLE, TYPE_VRAM, WRITE, A2
handler:
	rte
	
	
vdpValues:
	dc.b 	$14, $5C, $30, $3C, $07, $6C, $00, $00
	dc.b 	$00, $00, $FF, $00, $81, $3F, $00, $02
	dc.b 	$01, $00, $00
	dc.b    (((letterPatternsEnd - letterPatterns) >> 1) & $FF)
	dc.b    (((letterPatternsEnd - letterPatterns) >> 1) & $FF00) >> 8
	dc.b	((letterPatterns >> 1) & $FF)
	dc.b	((letterPatterns >> 1) & $FF00) >> 8
	dc.b	((letterPatterns >> 1) & $7F0000) >> 16
vdpValuesEnd:
	even

letterRecords:
	DEFINE_LETTER	0, 0
	DEFINE_LETTER	0, 2
	DEFINE_LETTER	0, 4
	DEFINE_LETTER	0, 6
	DEFINE_LETTER	0, 8
	DEFINE_LETTER	0, 10
	DEFINE_LETTER	0, 12
	DEFINE_LETTER	0, 14
	DEFINE_LETTER	1, 0
	DEFINE_LETTER	1, 2
	DEFINE_LETTER	1, 4
	DEFINE_LETTER	1, 6
	DEFINE_LETTER	1, 8
	DEFINE_LETTER	1, 10
	DEFINE_LETTER	1, 12
letterRecordsEnd:
	even
	
letterPatternsRLE:

;; TODO: implement compression(RLE or something else)
	
letterPatterns:	
;		B
	dc.l $11111100
	dc.l $11101110
	dc.l $11101110
	dc.l $11111100
	dc.l $11100111
	dc.l $11100111
	dc.l $11100111
	dc.l $11111110

;		e
	dc.l $00000000
	dc.l $00000000
	dc.l $00111110
	dc.l $01110011
	dc.l $01111111
	dc.l $01110000
	dc.l $01110011
	dc.l $00111110
	
;		H
	dc.l $11100111
	dc.l $11100111
	dc.l $11100111
	dc.l $11111111
	dc.l $11100111
	dc.l $11100111
	dc.l $11100111
	dc.l $11100111
	
;		h
	dc.l $00000000
	dc.l $11110000
	dc.l $01110000
	dc.l $01111110
	dc.l $01110111
	dc.l $01110111
	dc.l $01110111
	dc.l $11110110
	
;		l
	dc.l $00000000
	dc.l $01111000
	dc.l $00011100
	dc.l $00011100
	dc.l $00011100
	dc.l $00011100
	dc.l $00011100
	dc.l $01111111

;		o
	dc.l $00000000
	dc.l $00000000
	dc.l $00111110
	dc.l $01110111
	dc.l $01110111
	dc.l $01110111
	dc.l $01110111
	dc.l $00111110
	
;		r
	dc.l $00000000
	dc.l $00000000
	dc.l $01110110
	dc.l $00111011
	dc.l $00111000
	dc.l $00111000
	dc.l $00111000
	dc.l $01111100
	
;		s
	dc.l $00000000
	dc.l $00000000
	dc.l $00111110
	dc.l $01110001
	dc.l $01111100
	dc.l $00011111
	dc.l $01000111
	dc.l $00111110	
	
;		t
	dc.l $00000000
	dc.l $00000000
	dc.l $00111000
	dc.l $01111111
	dc.l $00111000
	dc.l $00111011
	dc.l $00111011
	dc.l $00011110
	
;		,
	dc.l $00000000
	dc.l $00000000
	dc.l $00000000
	dc.l $00000000
	dc.l $00000000
	dc.l $01110000
	dc.l $00110000
	dc.l $01100000
	
;		!
	dc.l $00011100
	dc.l $00011110
	dc.l $00011100
	dc.l $00111000
	dc.l $00110000
	dc.l $00000000
	dc.l $01100000
	dc.l $01100000
letterPatternsEnd:			

FRONT   = 0
NO_FLIP = 0
	
POS_0  = 0
POS_1  = 6
POS_2  = 12
POS_3  = 14
POS_4  = 16
POS_5  = 17
POS_6  = 18
POS_7  = 19
POS_8  = 20
POS_9  = 19
POS_10 = 18
POS_11 = 17
POS_12 = 16
POS_13 = 14
POS_14 = 12
POS_15 = 6
	
letterSprites:	
	DEFINE_SPRITE	$003, 224, 0, 0, 0, NO_FLIP, 0, FRONT, 1
	DEFINE_SPRITE	$002, 232, 0, 0, 0, NO_FLIP, 0, FRONT, 2
	DEFINE_SPRITE	$005, 240, 0, 0, 0, NO_FLIP, 0, FRONT, 3
	DEFINE_SPRITE	$005, 248, 0, 0, 0, NO_FLIP, 0, FRONT, 4
	
	DEFINE_SPRITE	$006, 256, 0, 0, 0, NO_FLIP, 0, FRONT, 5
	DEFINE_SPRITE	$00A, 264, 0, 0, 0, NO_FLIP, 0, FRONT, 6
	DEFINE_SPRITE	$001, 272, 0, 0, 0, NO_FLIP, 0, FRONT, 7
	DEFINE_SPRITE	$007, 280, 0, 0, 0, NO_FLIP, 0, FRONT, 8
	
	DEFINE_SPRITE	$006, 288, 0, 0, 0, NO_FLIP, 0, FRONT, 9
	DEFINE_SPRITE	$009, 296, 0, 0, 0, NO_FLIP, 0, FRONT, 10
	DEFINE_SPRITE	$004, 304, 0, 0, 0, NO_FLIP, 0, FRONT, 11
	DEFINE_SPRITE	$002, 312, 0, 0, 0, NO_FLIP, 0, FRONT, 12
	
	DEFINE_SPRITE	$007, 320, 0, 0, 0, NO_FLIP, 0, FRONT, 13
	DEFINE_SPRITE	$008, 328, 0, 0, 0, NO_FLIP, 0, FRONT, 14
	DEFINE_SPRITE	$00B, 336, 0, 0, 0, NO_FLIP, 0, FRONT, 0
letterSpritesEnd:

deltaY:	
	dc.b	POS_0, POS_1, POS_2,  POS_3,  POS_4,  POS_5,  POS_6,  POS_7
	dc.b	POS_8, POS_9, POS_10, POS_11, POS_12, POS_13, POS_14, POS_15
	
	rsset $FF0000
letterRecordsRam:		rs.b	16
	
;; For decompressing
letterPattern:	rs.l	8
