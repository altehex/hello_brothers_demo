;#############################################
;# 				  SYMBOLS					 #
;#############################################

	org			$00000000
	dc.l		$00FF8000
	dc.l		Start
	org			$00000068
	rept		38
	dc.l		Handler
	endr
	
; Metadata
;------------  

; 000100

Metadata:
	dc.b		"SEGA MEGA DRIVE "
	dc.b		"ALTEHEX 2022.JUN"
	dc.b		"HELLO                                           "
	dc.b		"HELLO                                           "
	dc.b		"GM 00000000-00"
	dc.w		0
	dc.b		"J               "
	dc.l		$000000,$1FFFFF
	dc.l		$FF0000,$FFFFFF
	dc.b		"            "
	dc.b		"            "
	dc.b		"                                        "
	dc.b		"JUE             "
	
;==============================================
	
Handler:
	rte

;			VDP
VDP_DATA	equ $FFC00000
VDP_CTRL	equ $FFC00004

;			VRAM
VRAM_WRITE	equ %0001
VRAM_READ	equ %0000
CRAM_WRITE  equ %0011
CRAM_READ	equ %1000
VSRAM_WRITE	equ %0101
VSRAM_READ	equ %0100

VBLANKON	equ 3

;			MISC
VERSION_REG equ $00A10001
TMSS_REG	equ	$00A14000

RAM			equ $00FF0000

; RAM_68K_A	equ $00FF0000
; RAM_68K_B	equ $00FF0000+1

;		NAME TABLES
PLANE_A		equ $C000
PLANE_B		equ $E000
WINDOW		equ $F000
SPRITES		equ $D800

;		SPRITE DEFINITION EQUATES
NO_FLIP		equ 0
H_FLIP		equ %01
V_FLIP		equ %10
HV_FLIP		equ %11

FRONT		equ 0
BACK		equ 1

;#############################################
;#				  VARIABLES					 #
;#############################################

	RSSET RAM
; SPRITES			rs.w 1
DMASOURCE:		rs.w 3
DMAlength:		rs.w 2

	rsset	$FF0020

;	letters y coordinates
H1:				rs.b	1
E1:				rs.b	1
L1:				rs.b	1
L2:				rs.b	1
O1:				rs.b	1
COMMA1:			rs.b	1
B1:				rs.b	1
R1:				rs.b	1
O2:				rs.b	1
T1:				rs.b	1
H2:				rs.b	1
E2:				rs.b	1
R2:				rs.b	1
S1:				rs.b	1
X_MARK1:		rs.b	1


;#############################################
;#				  MACROS					 #
;#############################################
							
DMA:	macro				      ; \1 - mode
	movem.l D5/A5,-(SP)		; \2 - source address
	lea DMASOURCE,A5		  ; \3 - length
	move.w \2,D5			    ; \4 - destination address
	lsr.l #1,D5
	movep.l D5,-1(A5)			
	move.w \3,D5
	lsr.l #1,D5
	movep.w D5,7(A5)
	
	lea DMASOURCE,A5
	move.l #4,D7
@LOADING\@:
	move.w (A5)+,(VDP_CTRL)
	dbra D7,@LOADING\@
	
	VDP \1,\4,1
	
	movem.l (SP)+,D5/A5
	endm
	
SCREEN:		 macro						            ; \1 - name table
	VDP VRAM_WRITE,\1+(\2*2)+(\3*128),0	  ; \2 - X pos (1-40)
	endm								                  ; \3 - Y pos (1-28)
		
; \1 - tile number
; \2 - X pos (to 1023)
; \3 - Y pos (to 511)
; \4 - height(in cells)
; \5 - width(in cells)
; \6 - flip data
; \7 - palette line
; \8 - priority
; \9 - link(draw order)
	
SPRITE_DEF:		macro
	move.l #(\3<<16)+(\5<<10)+(\4<<8)+\9,(VDP_DATA)
	move.l #(\8<<31)+(\7<<29)+(\6<<27)+(\1<<16)+\2,(VDP_DATA)
	endm
	
SPRITE_TABLE:	macro
	VDP VRAM_WRITE,SPRITES+(\1*8),0
	endm

VBLANK:			macro
	move.l D5,-(sp)
@WAIT\@:
	move.l (VDP_CTRL),D5
	btst #VBLANKON,D5
	beq @WAIT\@
	
	move.l (SP)+,D5
	endm

VDP:			macro																			                                          ; \1 - mode
	move.l #(((\1)&3)<<$1E+((\1)&$C)<<$2+((\2)&$C000)>>$E+((\2)&$3FFF)<<$10)+\3*$80,(VDP_CTRL)	; \2 - address
	endm							
	
; +++++++++++++++++++++++++++++++++++++++++++++
;+#############################################+
;+# 			START OF THE PROGRAM		  #+
;+#############################################+
; +++++++++++++++++++++++++++++++++++++++++++++

;#############################################
;# 		  TMSS & VDP INITIALIZATION		     #
;#############################################

START:

;	TMSS INITIALIZATION
	
	move.b (VERSION_REG),D0
	and.b #$F,D0
	beq CONTINUE
	move.l #'SEGA',($A14000)

CONTINUE:

;			VDP_Initialization
	move.b #VDP_Default_Settings_END-VDP_Default_Settings,D6
	lea VDP_Default_Settings,A0
	move.w #$8000,D5
	
VDP_Init:
	move.b (A0)+,D5
	move.w D5,(VDP_CTRL)
	add.w #$0100,D5
	dbra D6,VDP_Init
	
;	DMA source and length
	lea DMASOURCE,A0
	move.l #4,D7
	move.w #$9700,D0
DMA_Regs:
	move.w D0,(A0)+
	sub.w #$100,D0
	dbra D7,DMA_Regs
	
;#############################################
;# 				 MAIN CODE 					 #
;#############################################
;
	lea Palette1,A0
	DMA	CRAM_WRITE,A0,#6,0	

	lea Letters,A0
	DMA	VRAM_WRITE,A0,#360,$20
	
	SPRITE_TABLE     0
	SPRITE_DEF		$003,224,232,0,0,NO_FLIP,0,FRONT,1
	SPRITE_TABLE	 1
	SPRITE_DEF		$002,232,232,0,0,NO_FLIP,0,FRONT,2
	SPRITE_TABLE	 2
	SPRITE_DEF		$005,240,232,0,0,NO_FLIP,0,FRONT,3
	SPRITE_TABLE	 3
	SPRITE_DEF		$005,248,232,0,0,NO_FLIP,0,FRONT,4
	SPRITE_TABLE	 4
	SPRITE_DEF		$006,256,232,0,0,NO_FLIP,0,FRONT,5
	SPRITE_TABLE	 5
	SPRITE_DEF		$00A,264,232,0,0,NO_FLIP,0,FRONT,6
	SPRITE_TABLE	 6
	SPRITE_DEF		$001,272,232,0,0,NO_FLIP,0,FRONT,7
	SPRITE_TABLE	 7
	SPRITE_DEF		$007,280,232,0,0,NO_FLIP,0,FRONT,8
	SPRITE_TABLE	 8
	SPRITE_DEF		$006,288,232,0,0,NO_FLIP,0,FRONT,9
	SPRITE_TABLE	 9
	SPRITE_DEF		$009,296,232,0,0,NO_FLIP,0,FRONT,10
	SPRITE_TABLE	 10
	SPRITE_DEF		$004,304,232,0,0,NO_FLIP,0,FRONT,11
	SPRITE_TABLE	 11
	SPRITE_DEF		$002,312,232,0,0,NO_FLIP,0,FRONT,12
	SPRITE_TABLE	 12
	SPRITE_DEF		$007,320,232,0,0,NO_FLIP,0,FRONT,13
	SPRITE_TABLE	 13
	SPRITE_DEF		$008,328,232,0,0,NO_FLIP,0,FRONT,14
	SPRITE_TABLE	 14
	SPRITE_DEF		$00B,336,232,0,0,NO_FLIP,0,FRONT,15
	
	move.b		#%00000000,H1
	move.b		#%00000001,E1
	move.b		#%00000010,L1
	move.b		#%00000011,L2
	move.b		#%00000100,O1
	move.b		#%00000101,COMMA1
	move.b		#%00010000,B1
	move.b		#%00010001,R1
	move.b		#%00010010,O2
	move.b		#%00010011,T1
	move.b		#%00010100,H2
	move.b		#%00010101,E2
	move.b		#%00100000,R2
	move.b		#%00100001,S1
	move.b		#%00100010,X_MARK1
Main:
	VBLANK
	move.l		#$E,D2
Move_cycle:
	lea			H1,A6
	adda.l		D2,A6
	move.b		(A6),D6 
	bsr			Coord_calc
	move.b		D6,(A6)
	
	move.l		D2,D0
	lsl.l		#3,D0
	add.l		#SPRITES,D0
	
	rol.l		#2,D0
	ror.w		#2,D0
	swap		D0
	and.l		#$3FFF0003,D0
	or.l		#$40000000,D0
	move.l		D0,(VDP_CTRL)
	move.w		D4,(VDP_DATA)
	
	
	dbra 		D2,Move_cycle
	
	move.l #15360,D7
SLOWDOWN:
	dbra D7,SLOWDOWN
	bra			Main
	
;---------------------------------------	
	
	;	D6 - character phase value	
	;   D4 - final coordinate
Coord_calc:
	move.l		D6,D0
	and.l		#%0111,D0
	btst		#4,D6
	bne			B
	bsr			PowerA
	bra			Continue0
B:	
	bsr			PowerB

Continue0:
	move.l		#17,D3
	sub.l		#1,D1		; D3 - function
	mulu.w		D1,D3		
Div2:
	lsr.l		#1,D3
	dbra		D4,Div2
	move.l		#232,D4
	
	btst		#5,D6
	bne			Lower_half
Upper_half:
	add.l		D3,D4
	add.l		#5,D4
	bra			Continue1
Lower_half:
	sub.l		D3,d4
	sub.l		#5,D4
	
Continue1:
	
	move.b		D6,D3
	and.b		#%0111,D3
	cmpi.b		#5,D3
	beq			NextPhase
	addi.b		#1,D6
	bra			Continue2
NextPhase:
	andi.b		#%110000,D6
	cmpi.b		#%110000,D6
	beq			PhaseZero
	addi.b		#%010000,D6
	bra			Continue2
PhaseZero:
	subi.b		#%110000,D6
	
Continue2:
	rts
	
PowerB:
	neg			D0
	add.w		#5,D0
PowerA:
	move.w		#2,D1
	bra 		Power2
Power1:
	lsl.w		#1,D1
	dbra 		D0,Power1
	
	rts
	
Power2:
	subi.b		#1,D0
	move.l		D0,D4
	lsr.w		#1,D1
	bra 		Power1
	
	
; +++++++++++++++++++++++++++++++++++++++++++++
;+#############################################+
;+# 				DATA					  #+
;+#############################################+
; +++++++++++++++++++++++++++++++++++++++++++++

;#############################################
;# 				  PALETTES 					 #
;#############################################

Palette1:
	dc.w $000
	dc.w $00F
	dc.w $006

;#############################################
;# 				   TILES 					 #
;#############################################

Letters:
;		B
	dc.l $11111120
	dc.l $11121110
	dc.l $11101110
	dc.l $11111120
	dc.l $11102111
	dc.l $11100111
	dc.l $11102111
	dc.l $11111112

;		e
	dc.l $00000000
	dc.l $00000000
	dc.l $02111112
	dc.l $01112011
	dc.l $01111111
	dc.l $01110000
	dc.l $01110211
	dc.l $02111112
	
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
	dc.l $21110000
	dc.l $01111112
	dc.l $01112111
	dc.l $01110111
	dc.l $01110111
	dc.l $11110112
	
;		l
	dc.l $00000000
	dc.l $01111200
	dc.l $00211100
	dc.l $00011100
	dc.l $00011100
	dc.l $00011100
	dc.l $00211120
	dc.l $01111111

;		o
	dc.l $00000000
	dc.l $00000000
	dc.l $02111112
	dc.l $01112111
	dc.l $01110111
	dc.l $01110111
	dc.l $01112111
	dc.l $02111112
	
;		r
	dc.l $00000000
	dc.l $00000000
	dc.l $01112112
	dc.l $02111211
	dc.l $00111000
	dc.l $00111000
	dc.l $02111200
	dc.l $01111100
	
;		s
	dc.l $00000000
	dc.l $00000000
	dc.l $02111112
	dc.l $01112001
	dc.l $01111120
	dc.l $00211111
	dc.l $01002111
	dc.l $02111112	
	
;		t
	dc.l $00000000
	dc.l $00000000
	dc.l $00111000
	dc.l $01111111
	dc.l $00111000
	dc.l $00111011
	dc.l $00111211
	dc.l $00211112
	
;		,
	dc.l $00000000
	dc.l $00000000
	dc.l $00000000
	dc.l $00000000
	dc.l $00000000
	dc.l $01110000
	dc.l $02110000
	dc.l $01120000
	
;		.
	dc.l $00011120
	dc.l $00011110
	dc.l $00211100
	dc.l $00111000
	dc.l $00110000
	dc.l $00000000
	dc.l $01100000
	dc.l $01100000
	
Letters_END:
	even

;#############################################
;# 				VDP SETTINGS				 #
;#############################################

VDP_Default_Settings
	dc.b $14 
	dc.b $74	
	dc.b $30	
	dc.b $3C
	dc.b $07
	dc.b $6C
	dc.b $00
	dc.b $00
	dc.b $00	
	dc.b $00
	dc.b $FF
	dc.b $00
	dc.b $81
	dc.b $3F	
	dc.b $00
	dc.b $02
	dc.b $01
	dc.b $00
	dc.b $00	
	dc.b $FF
	dc.b $FF	
	dc.b $00
	dc.b $00	
	dc.b $80	
VDP_Default_Settings_END:
	even
	
fin:
