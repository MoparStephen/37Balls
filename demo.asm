 ; .loadsym "C:\Users\Stephen\source\repos\My Atari 8-bit code\37Balls\out\demo.lab"
;-----------------------------------------------------------------------------
; Memory Map
;-----------------------------------------------------------------------------
; VBXE RAM Usage ($80 banks, 4kB each)
; MEMAC_A is set to $2000, with a 4kB window, CPU only

; VRAM is wasting a tremendous amount of space in order for faster & simpler code
; Currently, with 256 pixel wide screen:
;	$00400        = XDL
;	$00500        = BCBs
;	$20000        = Screen 1
;	$40000        = Screen 2
;	$60000-$72BFF = Colour Map Data

;-----------------------------------------------------------------------------
;  HARDWARE EQUATES
;-----------------------------------------------------------------------------
    icl 'equates.asm'

;-----------------------------------------------------------------------------
; Structure Declarations
;-----------------------------------------------------------------------------
.struct Sprite
	X_Pos_Frac .byte					; Horizontal position (Fractional) sprite1
	X_Pos_Lo .byte						; Horizontal position sprite1
	X_Pos_Hi .byte						; Horizontal position sprite1 (Valid Values 0-319)
	Y_Pos_Frac .byte					; Vertical position (Fractional) sprite1
	Y_Pos .byte							; Vertical position sprite1 (valid values 0-239)
	Delta_X_Sign .byte					; X-Delta Sign (toggles betwen $00:Right, $FF:Left)
	Delta_X_Frac .byte					; Fractional X-Delta
	Delta_X .byte						; X-Delta (Valid Values) (+ = move right, - = move left)
	Delta_Y_Sign .byte					; Y-Delta Sign (toggles betwen $00:Down, $FF:Up)
	Delta_Y_Frac .byte					; Fractional Y-Delta
	Delta_Y .byte						; Y-Delta (Valid Values) (+ = move down, - = move up)
.ends

;-----------------------------------------------------------------------------
; Variables go here
;-----------------------------------------------------------------------------
; Page 0 user data ($80 to $FF with some reserved for OS)
.zpvar Reg1				.byte			; Multi-Use Variables
.zpvar Reg2				.byte			; Multi-Use Variables
.zpvar Reg3				.byte			; Multi-Use Variables
.zpvar Reg4				.byte			; Multi-Use Variables
.zpvar Reg5				.byte			; Multi-Use Variables
.zpvar Reg6				.byte			; Multi-Use Variables
.zpvar Reg7				.byte			; Multi-Use Variables
.zpvar Reg8				.byte			; Multi-Use Variables
.zpvar Ptr_Lo			.byte			; Lo byte of pointer
.zpvar Ptr_Hi			.byte			; Hi byte of pointer
.zpvar Do_Motion		.byte			; Allows pausing motion for the initial start
.zpvar Num_Sprites		.byte			; Keeps track of the number of sprites we are displaying

; Non Page-0 Variables
;	$480 to $4FF free
;	$600 to $6FF free
; When using PMG the 1st $300 bytes are always free
.var SDMCTL_OLD			.byte = $480	; Save DMA
.var CRSINH_OLD			.byte = $481	; Save CRSINH (Mouse Pointer)
.var LMARGIN_OLD		.byte = $482	; Save LMARGIN
.var COLOR1_OLD			.byte = $483	; Save COLOR1
.var COLOR2_OLD			.byte = $484	; Save COLOR2
.var SDLSTL_OLD			.byte = $485	; Save the Display List Pointer
.var SDLSTH_OLD			.byte = $486	; Save the Display List Pointer
.var Video_Flag			.byte = $487	; PAL = 0, NTSC = 1

;-----------------------------------------------------------------------------
; Rasta Music Tracker Stuff
;-----------------------------------------------------------------------------
	org $4400
	.proc music
STEREOMODE				equ $00
init_song				equ RASTERMUSICTRACKER+0
play					equ RASTERMUSICTRACKER+3
silence					equ RASTERMUSICTRACKER+9

	icl 'Assets\Atari_Led.feat'
player
	icl 'rmt_player.asm'				; Include RMT player routine
	icl 'rmt_relocator.asm'

module									; Include music RMT module
	rmt_relocator 'Assets\Atari_Led.rmt' module
	.endp

; Sprite struct array in free RAM $5500-$57BF (37 sprites * 11 bytes = 407 bytes)
Bobs	equ	$5500

;-----------------------------------------------------------------------------
; Defines go here
;-----------------------------------------------------------------------------
.def	__VBXE_AUTO__
.def	VBXE_WINDOW						= $2000
.def	VBXE_WINDOW_SIZE_4k				= $1000
.def	VBXE_WINDOW_SIZE_8k				= $2000
.def	LOAD_ADDRESS					= VBXE_WINDOW + VBXE_WINDOW_SIZE_4k
.def	SCREEN_RAM						= $8000	; Make sure this is > Mus_Song_End

; Temp debug stuff
.def	DBG_SINGLE_STEP					= $00	; 00 = False else true
.def	MAX_SPRITES_PAL					= $25
.def	MAX_SPRITES_NTSC				= $18

; Sprite struct field byte offsets for (Ptr_Lo),y indirect access
.def	Spr_X_Pos_Frac					= $00
.def	Spr_X_Pos_Lo					= $01
.def	Spr_X_Pos_Hi					= $02
.def	Spr_Y_Pos_Frac					= $03
.def	Spr_Y_Pos						= $04
.def	Spr_Delta_X_Sign				= $05
.def	Spr_Delta_X_Frac				= $06
.def	Spr_Delta_X						= $07
.def	Spr_Delta_Y_Sign				= $08
.def	Spr_Delta_Y_Frac				= $09
.def	Spr_Delta_Y						= $0A
.def	Sprite_Size						= $0B

; BCB field byte offsets
.def	Src_Adr0						= $00
.def	Src_Adr1						= $01
.def	Src_Adr2						= $02
.def	Dest_Adr0						= $06
.def	Dest_Adr1						= $07
.def	Dest_Adr2						= $08
.def	Blt_Ctrl						= $14

; Title Screen
.def	V_0								= $11	; 1 (Screen code used for Version in loading screen)
.def	V_1								= $10	; 0 (Screen code used for Version in loading screen)
.def	V_2								= $12	; 2 (Screen code used for Version in loading screen)
.def	V_3								= $61	; A (Screen code used for Version in loading screen)

;-----------------------------------------------------------------------------
; VBXE Helpers
;-----------------------------------------------------------------------------
	org LOAD_ADDRESS
.pages 3								; DO NOT go past $3300
	icl 'fileio.lib'
	icl 'vbxe_min.asm'					; Use my VBXE_SetPalette2 to load linear palete

;-----------------------------------------------------------------------------
; Clean up and exit based on LoadStatus
;-----------------------------------------------------------------------------
Cleanup_Exit
	jsr music.silence					; Stop music

	lda #$00							; Don't display anything during exit
	sta SDMCTL
	sta COLOR1
	bit VCOUNT							; Wait for VSYNC so screen turns off
	bmi *-3
	bit VCOUNT
	bpl *-3

	lda #MEMAC_GLOBAL_DISABLE			; USE CPU address space
	sta VBXE_MA_BSEL
	sta VBXE_VIDEO_CONTROL				; Disable XDL

	lda CRSINH_OLD
	sta CRSINH							; Restore CRSINH

	lda LMARGIN_OLD
	sta LMARGIN							; Restore LMARGIN

	lda COLOR1_OLD
	sta COLOR1							; Restore COLOR1

	lda COLOR2_OLD
	sta COLOR2							; Restore COLOR2

	lda SDLSTL_OLD
	sta SDLSTL							; Restore SDLSTL

	lda SDLSTH_OLD
	sta SDLSTL+1						; Restore SDLSTH

	lda #$FF
	sta CH								; Clear last key pressed

	jmp (DOSVEC)						; Return to DOS

Wait_For_Key_Exit
	lda #$FF
	sta CH								; Clear last key pressed
Wait_For_Key_Exit_L1
	lda CH
	cmp #$FF
	beq Wait_For_Key_Exit_L1			; Wait for Key Press
	rts									; Exit on  Key Press
.endpg

; Multi-stage loader & program initialization code begins here
	icl 'init_vbxe.asm'

	org LOAD_ADDRESS + $300				; Libraries live above
;-----------------------------------------------------------------------------
; Main loop
;-----------------------------------------------------------------------------
main
; Setup RMT
	ldx #<music.module
	ldy #>music.module
	lda #$00
	jsr music.init_song

	lda #$00
	sta Do_Motion

	lda #MAX_SPRITES_PAL
	sta Num_Sprites

	lda #$00							; Setup VBXE for displaying picture data
	sta VBXE_XDL_ADR0					; But don't show the overlay just yet!
	sta VBXE_XDL_ADR2
	lda #$04
	sta VBXE_XDL_ADR1

	lda #$00
	sta COLOR2							; Set Playfield Black
	jsr Setup_DisplayList
	jsr Wait_For_Sync

	lda #%00000011						; XDL,XCOLOR Enabled and transparent color index 0
	sta VBXE_VIDEO_CONTROL

; Pre-fill both screen buffers with the background before animation starts
	jsr Flip_Screen
	jsr Clear_Screen					; Draw background
	jsr Flip_Screen
	jsr Clear_Screen					; Draw background

	jsr Generate_Colour_Map				; So we don't have a boring monochrome background

	jsr Init_Objects					; Initialise all sprite structs

; Point the buffer to the currently being displayed screen
	lda #$80							; Bank $00 with global enable (XDL lives in bank $00)
	sta VBXE_MA_BSEL

	lda VBXE_WINDOW + $405				; XDL Adr2 (byte 5 of XDL at VBXE_WINDOW+$400)
	eor #$06							; Flip between $02 ($020000) and $04 ($040000)
	sta VBXE_WINDOW + $405				; XDL Adr2 (byte 5 of XDL at VBXE_WINDOW+$400)

; Draw the initial bobs to the screen being displayed
	jsr Set_Positions					; Update positions, bounce, write BCBs, blit all sprites

; Set it back
	lda #$80							; Bank $00 with global enable (XDL lives in bank $00)
	sta VBXE_MA_BSEL

	lda VBXE_WINDOW + $405				; XDL Adr2 (byte 5 of XDL at VBXE_WINDOW+$400)
	eor #$06							; Flip between $02 ($020000) and $04 ($040000)
	sta VBXE_WINDOW + $405				; XDL Adr2 (byte 5 of XDL at VBXE_WINDOW+$400)

	lda #$64							; Delay animation starting by $64 frames (2 PAL seconds)
	sta Reg1

Delay_Start
	jsr music.play						; Play a frame of music
	jsr Wait_For_Sync
	dec Reg1
	bne Delay_Start

	lda Video_Flag
	beq Set_Do_Motion					; If PAL skip next 2 lines

	lda #MAX_SPRITES_NTSC				; Else limit # of sprites being shown
	sta Num_Sprites

Set_Do_Motion
	lda #$01
	sta Do_Motion						; Allow positions to update when blitting

Main_Loop
	lda #$00
	sta ATRACT							; Disable Screensaver

; Do all the work
	jsr music.play						; Play a frame of music
	jsr Set_Positions					; Update positions, bounce, write BCBs, blit all sprites
	jsr Flip_Screen						; Swap buffers
	jsr Clear_Screen					; Redraw background

; Work done -wait for vertical synch before looping again
W_Synch_0
	jsr Wait_For_Sync					; Wait for VSYNC, Q quits
	lda #$FF
	sta CH
	lda #DBG_SINGLE_STEP
	beq Dont_Wait_Space_0
Wait_Space_0
	lda #$00
	sta ATRACT							; Disable screensaver
	lda CH
	cmp #$2F							; Press Q to quit
	beq Exit
	cmp #$21							; Press Space to start
	bne Wait_Space_0
Dont_Wait_Space_0
	jmp Main_Loop						; Animate forever

; This is where we exit
Exit
	lda #$FF
	sta CH								; Clear last key pressed

	lda #$00
	sta VBXE_VIDEO_CONTROL				; Disable XDL
	lda #$00
	sta VBXE_MA_BSEL					; Restore main memory (and disable VBXE memory window at VBXE_WINDOW)

	jmp (DOSVEC)						; Good bye ;)

;-----------------------------------------------------------------------------
; Subroutines BEGIN
;-----------------------------------------------------------------------------
;-----------------------------------------------------------------------------
; Reverse_X - 2's complement negate of Delta_X_Sign:Delta_X:Delta_X_Frac
; Ptr_Lo/Ptr_Hi must point to the current Sprite struct
;-----------------------------------------------------------------------------
Reverse_X
	sec
	ldy #Spr_Delta_X_Frac
	lda #$00
	sbc (Ptr_Lo),y
	sta (Ptr_Lo),y
	ldy #Spr_Delta_X
	lda #$00
	sbc (Ptr_Lo),y
	sta (Ptr_Lo),y
	ldy #Spr_Delta_X_Sign
	lda (Ptr_Lo),y
	eor #$FF
	sta (Ptr_Lo),y
	rts

;-----------------------------------------------------------------------------
; Reverse_Y - 2's complement negate of Delta_Y_Sign:Delta_Y:Delta_Y_Frac
;-----------------------------------------------------------------------------
Reverse_Y
	sec
	ldy #Spr_Delta_Y_Frac
	lda #$00
	sbc (Ptr_Lo),y
	sta (Ptr_Lo),y
	ldy #Spr_Delta_Y
	lda #$00
	sbc (Ptr_Lo),y
	sta (Ptr_Lo),y
	ldy #Spr_Delta_Y_Sign
	lda (Ptr_Lo),y
	eor #$FF
	sta (Ptr_Lo),y
	rts

;-----------------------------------------------------------------------------
; Set_Positions
; For each sprite: update position with sub-pixel accuracy, bounce off walls,
; compute VBXE address via Calculate_200, write to BLT_BALL BCB, fire blitter.
; X = object counter,  Ptr_Lo/Ptr_Hi = pointer to current Sprite struct
;-----------------------------------------------------------------------------
Set_Positions
	lda #$80
	sta VBXE_MA_BSEL					; Enable VBXE window for BCB writes

	lda #<Bobs
	sta Ptr_Lo
	lda #>Bobs
	sta Ptr_Hi
	ldx #$00

Spr_Loop
	lda Do_Motion
	bne Set_X
	jmp Skip_Motion						; Long branch fix

;--- X motion ----------------------------------------------------------------
Set_X
	clc
	ldy #Spr_X_Pos_Frac
	lda (Ptr_Lo),y
	ldy #Spr_Delta_X_Frac
	adc (Ptr_Lo),y
	ldy #Spr_X_Pos_Frac
	sta (Ptr_Lo),y

	ldy #Spr_X_Pos_Lo
	lda (Ptr_Lo),y
	ldy #Spr_Delta_X
	adc (Ptr_Lo),y
	ldy #Spr_X_Pos_Lo
	sta (Ptr_Lo),y

	ldy #Spr_X_Pos_Hi
	lda (Ptr_Lo),y
	ldy #Spr_Delta_X_Sign
	adc (Ptr_Lo),y						; $00 = right, $FF = left
	ldy #Spr_X_Pos_Hi
	sta (Ptr_Lo),y
	lda (Ptr_Lo),y						; Reload to restore N flag (sta does not set N)

; Left wall: X_Pos_Hi >= $80 means position underflowed past 0
	bpl X_Check_Right
	lda #$00
	ldy #Spr_X_Pos_Hi
	sta (Ptr_Lo),y
	ldy #Spr_X_Pos_Lo
	sta (Ptr_Lo),y
	ldy #Spr_X_Pos_Frac
	sta (Ptr_Lo),y
	ldy #Spr_Delta_X_Sign
	lda (Ptr_Lo),y
	bpl X_Done							; Already heading right
	jsr Reverse_X
	jmp X_Done

; Right wall: clamp if X_Pos > $0120 (320 - 32 = 288)
X_Check_Right
	ldy #Spr_X_Pos_Hi
	lda (Ptr_Lo),y
	cmp #$01
	bcc X_Done							; Hi < $01, in range
	bne X_Hit_Right						; Hi > $01, past right edge
	ldy #Spr_X_Pos_Lo
	lda (Ptr_Lo),y
	cmp #$21							; Lo > $20?
	bcc X_Done
X_Hit_Right
	lda #$01
	ldy #Spr_X_Pos_Hi
	sta (Ptr_Lo),y
	lda #$20
	ldy #Spr_X_Pos_Lo
	sta (Ptr_Lo),y
	lda #$00
	ldy #Spr_X_Pos_Frac
	sta (Ptr_Lo),y
	ldy #Spr_Delta_X_Sign
	lda (Ptr_Lo),y
	bmi X_Done							; Already heading left
	jsr Reverse_X
X_Done

;--- Y motion ----------------------------------------------------------------
	clc
	ldy #Spr_Y_Pos_Frac
	lda (Ptr_Lo),y
	ldy #Spr_Delta_Y_Frac
	adc (Ptr_Lo),y
	ldy #Spr_Y_Pos_Frac
	sta (Ptr_Lo),y

	ldy #Spr_Y_Pos
	lda (Ptr_Lo),y
	ldy #Spr_Delta_Y
	adc (Ptr_Lo),y
	ldy #Spr_Y_Pos
	sta (Ptr_Lo),y

	ldy #Spr_Delta_Y_Sign
	lda (Ptr_Lo),y
	bmi Y_Check_Top

; Moving down: clamp if Y_Pos > $D0 (240 - 32 = 208)
Y_Check_Bottom
	ldy #Spr_Y_Pos
	lda (Ptr_Lo),y
	cmp #$D1
	bcc Y_Done
	lda #$D0
	sta (Ptr_Lo),y
	lda #$00
	ldy #Spr_Y_Pos_Frac
	sta (Ptr_Lo),y
	ldy #Spr_Delta_Y_Sign
	lda (Ptr_Lo),y
	bmi Y_Done							; Already heading up
	jsr Reverse_Y
	jmp Y_Done

; Moving up: underflow wraps Y_Pos above $D0
Y_Check_Top
	ldy #Spr_Y_Pos
	lda (Ptr_Lo),y
	cmp #$D1
	bcc Y_Done
	lda #$00
	ldy #Spr_Y_Pos
	sta (Ptr_Lo),y
	ldy #Spr_Y_Pos_Frac
	sta (Ptr_Lo),y
	ldy #Spr_Delta_Y_Sign
	lda (Ptr_Lo),y
	bpl Y_Done							; Already heading down
	jsr Reverse_Y
Y_Done

;--- Compute VBXE address and blit -------------------------------------------
Skip_Motion								; Jump here to bypass ball motion
	ldy #Spr_X_Pos_Lo
	lda (Ptr_Lo),y
	sta Reg1							; X_Pos_Lo → Calculate_200 input
	ldy #Spr_X_Pos_Hi
	lda (Ptr_Lo),y
	sta Reg2							; X_Pos_Hi → Calculate_200 input
	ldy #Spr_Y_Pos
	lda (Ptr_Lo),y
	sta Reg3							; Y_Pos    → Calculate_200 input

	jsr Calculate_200					; → Reg4=Adr0, Reg5=Adr1, Reg6=Adr2

	lda Reg4
	sta VBXE_WINDOW+$500+BLT_BALL-BLT_BALL+Dest_Adr0
	lda Reg5
	sta VBXE_WINDOW+$500+BLT_BALL-BLT_BALL+Dest_Adr1
	lda Reg6
	sta VBXE_WINDOW+$500+BLT_BALL-BLT_BALL+Dest_Adr2

	jsr Draw_Sprite						; Wait for blitter idle then fire BLT_BALL

;--- Advance Ptr to next sprite ----------------------------------------------
	clc
	lda Ptr_Lo
	adc #Sprite_Size
	sta Ptr_Lo
	bcc No_Hi_Bump
	inc Ptr_Hi
No_Hi_Bump
	inx
	cpx Num_Sprites
	beq Spr_Loop_Done					; All sprites done
	jmp Spr_Loop						; Long branch workaround (loop body > 127 bytes)
Spr_Loop_Done
	lda #$00
	sta VBXE_MA_BSEL					; Disable VBXE window
	rts

;-----------------------------------------------------------------------------
; Init_Objects - called once at startup
; Starting positions read from Init_Pos_X_Hi/Lo and Init_Pos_Y tables.
; Velocities read from Init_Delta_X/Y tables (unchanged).
;-----------------------------------------------------------------------------
Init_Objects
	lda #<Bobs
	sta Ptr_Lo
	lda #>Bobs
	sta Ptr_Hi
	ldx #$00

Init_Spr_L
	; X position from tables - Frac always 0, Pos_Hi always 0
	txa
	tay
	lda Init_Pos_X_Lo,y
	ldy #Spr_X_Pos_Lo
	sta (Ptr_Lo),y
	lda #$00
	ldy #Spr_X_Pos_Frac
	sta (Ptr_Lo),y
	ldy #Spr_X_Pos_Hi
	sta (Ptr_Lo),y

	; Y position from table - Frac always 0
	txa
	tay
	lda Init_Pos_Y,y
	ldy #Spr_Y_Pos
	sta (Ptr_Lo),y
	lda #$00
	ldy #Spr_Y_Pos_Frac
	sta (Ptr_Lo),y

	; Velocity from tables, indexed directly by object number
	txa
	tay
	lda Init_Delta_X,y
	ldy #Spr_Delta_X
	sta (Ptr_Lo),y

	txa
	tay
	lda Init_Delta_X_Frac,y
	ldy #Spr_Delta_X_Frac
	sta (Ptr_Lo),y

	lda #$00							; Initially moving right
	ldy #Spr_Delta_X_Sign
	sta (Ptr_Lo),y

	txa
	tay
	lda Init_Delta_Y,y
	ldy #Spr_Delta_Y
	sta (Ptr_Lo),y

	txa
	tay
	lda Init_Delta_Y_Frac,y
	ldy #Spr_Delta_Y_Frac
	sta (Ptr_Lo),y

	lda #$00							; Initially moving down
	ldy #Spr_Delta_Y_Sign
	sta (Ptr_Lo),y

	; Advance struct pointer by Sprite_Size
	clc
	lda Ptr_Lo
	adc #Sprite_Size
	sta Ptr_Lo
	bcc No_PH_Bump
	inc Ptr_Hi
No_PH_Bump

	inx
	cpx Num_Sprites
	bne Init_Spr_L
	rts

;-----------------------------------------------------------------------------
; Flip_Screen buffers
;-----------------------------------------------------------------------------
Flip_Screen
	lda #$80
	sta VBXE_MA_BSEL
	lda VBXE_WINDOW+$405
	sta VBXE_WINDOW+$500+BLT_BALL-BLT_BALL+8
	sta VBXE_WINDOW+$500+BLT_BAKGRND-BLT_BALL+8
	eor #6								; Flip screen between $20000 and $40000
	sta VBXE_WINDOW+$405
	rts
;--------------------------------------------------------

;-----------------------------------------------------------------------------
; Draw_Sprite - fire BLT_BALL; destination already written to BCB by Set_Positions
;-----------------------------------------------------------------------------
Draw_Sprite
	lda #BLT_BALL-BLT_BALL
	sta VBXE_BL_ADR0
	lda #$00
	sta VBXE_BL_ADR2
	lda #$05
	sta VBXE_BL_ADR1
Draw_Sprite_L1
	lda VBXE_BLITTER_BUSY
	bne Draw_Sprite_L1					; Wait for blitter idle
	lda #$01
	sta VBXE_BLITTER_START				; Fire
	rts

;-----------------------------------------------------------------------------
; Wait For VSync (locks to the refresh rate, PAL=50Hz, NTSC=60Hz)  Thanks tebe
;-----------------------------------------------------------------------------
Wait_For_Sync							; Hold until VCOUNT == 0
	bit VCOUNT
	bmi *-3
	bit VCOUNT
	bpl *-3
; If present, the next 3 lines will allow a 'jump to exit' on a specific key press
	lda CH
	cmp #$2F							; Press Q to quit
	beq Exit_Long
	rts									; Else return to caller

Exit_Long
	jmp Cleanup_Exit					; Fix for branch out of range

;-----------------------------------------------------------------------------
; Clear_Screen via blitter
;-----------------------------------------------------------------------------
Clear_Screen
	lda #BLT_BAKGRND-BLT_BALL
	sta VBXE_BL_ADR0					; Setup the blitter for memory fill operation
	lda #$00
	sta VBXE_BL_ADR2					; See the description of BCB at the end of this
	lda #$05							; Source
	sta VBXE_BL_ADR1
	lda #$00
Clear_Screen_L1
	lda VBXE_BLITTER_BUSY
	cmp #$00
	bne Clear_Screen_L1					; Wait for blitter to finish
	lda #$01
	sta VBXE_BLITTER_START				; Start the blit
	rts

;-----------------------------------------------------------------------------
; Setup_Cmap1 - Sets byte 4 for all cmap entries via blitter
;-----------------------------------------------------------------------------
Setup_Cmap1
	lda #BLT_SETUP_CMAP_1-BLT_BALL
	sta VBXE_BL_ADR0					; Setup the blitter for memory fill operation
	lda #$00
	sta VBXE_BL_ADR2					; See the description of BCB at the end of this
	lda #$05							; Source
	sta VBXE_BL_ADR1
	lda #$00
Setup_Cmap1_L1
	lda VBXE_BLITTER_BUSY
	cmp #$00
	bne Setup_Cmap1_L1					; Wait for blitter to finish
	lda #$01
	sta VBXE_BLITTER_START				; Start the blit
	rts

;-----------------------------------------------------------------------------
; Setup_Cmap2 - Sets byte 2 for all cmap entries via blitter
;-----------------------------------------------------------------------------
Setup_Cmap2
	lda #BLT_SETUP_CMAP_2-BLT_BALL
	sta VBXE_BL_ADR0					; Setup the blitter for memory fill operation
	lda #$00
	sta VBXE_BL_ADR2					; See the description of BCB at the end of this
	lda #$05							; Source
	sta VBXE_BL_ADR1
	lda #$00
Setup_Cmap2_L1
	lda VBXE_BLITTER_BUSY
	cmp #$00
	bne Setup_Cmap2_L1					; Wait for blitter to finish
	lda #$01
	sta VBXE_BLITTER_START				; Start the blit
	rts

;-----------------------------------------------------------------------------
; Calculate_200
;   Reg1 = X_Pos_L	Object Horizontal Position (Col)
;   Reg2 = X_Pos_H	Object Horizontal Position (Col)
;   Reg3 = Y_Pos	Object Vertical Position   (Row)
;   Reg4 = Adr0	   VBXE Blitter Address
;   Reg5 = Adr1	   VBXE Blitter Address
;   Reg6 = Adr2	   VBXE Blitter Address
;   Reg7 = XDL destination high byte (either 0 or 2)
;-----------------------------------------------------------------------------
Calculate_200
; Because we are double buffering, we need to write to the backbuffer
; So load the buffer address from the XDL but use the other one
	lda VBXE_MA_BSEL
	pha									; Store it

	lda #$80							; Bank $00 with global enable (XDL lives in bank $00)
	sta VBXE_MA_BSEL

	lda VBXE_WINDOW + $405				; XDL Adr2 (byte 5 of XDL at VBXE_WINDOW+$400)
	eor #$06							; Flip between $02 ($020000) and $04 ($040000)
	sta Reg7							; Reg7 = backbuffer Adr2

; Calculate the start of VRAM (Reg4, Reg5, Reg6) for the given Y-Pos
	lda #$00
	sta Reg4							; Reset to initial value
	sta Reg6							; Reset to initial value
	lda Reg3							; Y_Pos
	bpl Skip_Reg6						; If A <= $7F Reg6 will be 0
	ldy #$01							; Else
	sty Reg6							; Reg6 = 1
Skip_Reg6
	asl									; Multiply by 2
	sta Reg5

; Now move into that line in VRAM based on the X-Position
	clc									; Prepare to add
	lda Reg1							; X_Pos_L
	adc Reg4							; Add Adr0
	sta Reg4							; Store it
	lda Reg2							; X_Pos_H
	adc Reg5							; Add Adr1
	sta Reg5							; Store it
	lda #$00
	adc Reg6							; Account for overflow
	sta Reg6							; Store Adr2

; Set Adr 2 depending on which buffer we are writing to
	clc									; Prepare to add
	lda Reg7
	adc Reg6							; Carry flag weill NEVER be set, as value will only ever be 0-1 or 2-3
	sta Reg6
Calculate_200_End						; This takes on average $37(55) cycles, code is $22(34) bytes TODO: Calculate new cycle time based on code to handle double buffering
	pla
	sta VBXE_MA_BSEL					; Restore to initial value

	rts

;-----------------------------------------------------------------------------
; Setup_DisplayList - Points ANTIC to a Display List that will be in VBXE RAM
;-----------------------------------------------------------------------------
Setup_DisplayList
	lda SDMCTL
	pha									; Save it

	lda #$00							; Turn off ANTIC DMA
	sta SDMCTL							; To safely set SDLSTL

	lda <Display_List
	sta SDLSTL
	lda >Display_List
	sta SDLSTH

	pla									; Restore it
	sta SDMCTL

	rts									; Go Home

;-----------------------------------------------------------------------------
; Generate_Colour_Map
; This will generate the 9600 byte colour map used by the VBXE
;-----------------------------------------------------------------------------
Generate_Colour_Map
	lda #$00
	sta Ptr_Lo
	lda #$06
	sta Ptr_Hi							; Initialize destination pointer to $0600

	lda #$01
	sta Reg1							; Running colour accumulator

	ldx #$00							; Object counter (0-15)
obj_loop
	ldy #$00							; Row counter (0-14)
row_loop
	lda #$00							; Default: blank row
	cpy #$00
	beq store_colour
	cpy #$0E
	beq store_colour
	lda Reg1							; Non-blank row: use accumulator
	inc Reg1
store_colour
	sta (Ptr_Lo),Y

	iny
	cpy #$0F							; 15 rows per object
	bne row_loop

; Advance pointer by 15 to next object's base
	lda Ptr_Lo
	clc
	adc #$0F
	sta Ptr_Lo
	bcc no_carry
	inc Ptr_Hi
no_carry
	inx
	cpx #$10							; 16 objects
	bne obj_loop

	jsr Setup_Cmap1						; Setup the Palette & Priority bits
	jsr Setup_Colours

	rts

;-----------------------------------------------------------------------------
; Setup_Colours
; Uses the temp table at $600 to setup the Attribute COlour Map
;-----------------------------------------------------------------------------
Setup_Colours
; Turn on VBXE window so we can modify the BCB
	lda #$80							; Copy some data into VBXE address space (XDL, Blitter control blocks (BCB))
	sta VBXE_MA_BSEL

	ldx #$00							; Prepare to loop
Setup_Colours_L1
	lda $600,x							; Get the colour
	sta VBXE_WINDOW+$554+$10			; BLT_SETUP_CMAP_2 starts at $0554 in VBXE bank 0, XOR Mask is offset $10

	jsr Setup_Cmap2						; Setup a row of colours

; Now we must do a 24-bit addition to get the next Destination Address (offset 6,7,8)
	clc
	lda VBXE_WINDOW+$554+$06			; Dest Addr 2
	adc #$40
	sta VBXE_WINDOW+$554+$06			; Dest Addr 2

	lda VBXE_WINDOW+$554+$07			; Dest Addr 1
	adc #$01
	sta VBXE_WINDOW+$554+$07			; Dest Addr 1

	lda VBXE_WINDOW+$554+$08			; Dest Addr 0
	adc #$00
	sta VBXE_WINDOW+$554+$08			; Dest Addr 1

	inx
	cpx #$EF
	bne Setup_Colours_L1

	rts
;-----------------------------------------------------------------------------
; Subroutines END
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Data Tables go here
;-----------------------------------------------------------------------------
; 37 velocity patterns - one per sprite, every (int,frac) pair unique
; X: integer $00-$03 cycles with period 4; frac rotates +$40 each int group
; Y: integer offset by 1 ($01-$03,$00); frac rotates +$20 relative to X → no correlation
Init_Delta_X
	dta $01,$01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03
	dta $00,$01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03
	dta $00,$01,$02,$03,$00
Init_Delta_X_Frac
	dta $00,$40,$80,$C0,$10,$50,$90,$D0,$20,$60,$A0,$E0,$30,$70,$B0,$F0
	dta $40,$80,$C0,$00,$50,$90,$D0,$10,$60,$A0,$E0,$20,$70,$B0,$F0,$30
	dta $80,$C0,$00,$40,$90
Init_Delta_Y
	dta $06,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03,$01,$01,$02,$03,$00
	dta $01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03,$00
	dta $01,$02,$03,$00,$01
Init_Delta_Y_Frac
	dta $00,$60,$A0,$E0,$30,$70,$B0,$F0,$40,$80,$C0,$00,$50,$90,$D0,$10
	dta $60,$A0,$E0,$20,$70,$B0,$F0,$30,$80,$C0,$00,$40,$90,$D0,$10,$50
	dta $A0,$E0,$20,$60,$B0

; Standard Atari ROM font for 3 and 7, laid out by hand, then auto-generated tables based on my grid
Init_Pos_X_Lo
	dta $12,$24,$36,$48,$5A,$6C,$A2,$B4,$C6,$D8,$EA,$FC,$48,$5A,$A2,$EA	; Objs $00-$0F
	dta $FC,$36,$48,$D8,$EA,$48,$5A,$C6,$D8,$12,$24,$5A,$6C,$B4,$C6,$24	; Objs $10-$1F
	dta $36,$48,$5A,$B4,$C6				; Objs $20-$24
Init_Pos_Y
	dta $0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$1A,$1A,$1A,$1A	; Objs $00-$0F
	dta $1A,$27,$27,$27,$27,$34,$34,$34,$34,$41,$41,$41,$41,$41,$41,$4E	; Objs $10-$1F
	dta $4E,$4E,$4E,$4E,$4E				; Objs $20-$24

	org $5900							; Ensure the Display_List is page aligned
Display_List							; 16 * 15 = 240 lines
	.byte $00							; 1 blank
	.byte $4F							; Mode F, LMS @ SCREEN_RAM
	.byte <SCREEN_RAM
	.byte >SCREEN_RAM
.rept $0F
	.rept 12
		.byte $0F						; Mode F
	.endr
	.byte $10							; 2 blank
	.byte $4F							; Mode F, LMS @ SCREEN_RAM
	.byte <SCREEN_RAM
	.byte >SCREEN_RAM
.endr
	.rept 12
		.byte $0F						; Mode F
	.endr
	.byte $41							; Jump & Wait VBL
	.byte <Display_List
	.byte >Display_List
Display_List_Length	equ *-Display_List

; ---
	run main
