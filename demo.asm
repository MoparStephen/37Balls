 ; .loadsym "C:\Users\Stephen\source\repos\My Atari 8-bit code\37Balls\out\demo.lab"
;-----------------------------------------------------------------------------
; Memory Map
;-----------------------------------------------------------------------------
; VBXE RAM Usage ($80 banks, 4kB each)
; MEMAC_A is set to $2000, with a 4kB window, CPU only

; VRAM is wasting a tremendous amount of space in order for faster & simpler code
; Currently, with 256 pixel wide screen:
;	$00400        = XDL_Attribute (Colour Map on)
;	$00415        = XDL_Normal (Colour Map off)
;	$00500        = BCBs
;	$20000        = Screen 1
;	$40000        = Screen 2
;	$60000-$72BFF = Colour Map Data

;-----------------------------------------------------------------------------
;  HARDWARE EQUATES
;-----------------------------------------------------------------------------
    icl 'equates.asm'

;-----------------------------------------------------------------------------
; Ball Data Layout (struct-of-arrays)
;-----------------------------------------------------------------------------
; Each field is its own flat array indexed by the ball number in X, so every
; access is a single lda/sta abs,x - no (Ptr_Lo),y indirection, no per-ball
; pointer arithmetic, and Y is left free.  Addresses are set up below at Bobs.
;
;	X_Pos_Frac							; Horizontal position (Fractional)
;	X_Pos_Lo							; Horizontal position
;	X_Pos_Hi							; Horizontal position (Valid Values 0-319)
;	Y_Pos_Frac							; Vertical position (Fractional)
;	Y_Pos								; Vertical position (valid values 0-239)
;	Delta_X_Sign						; X-Delta Sign (toggles betwen $00:Right, $FF:Left)
;	Delta_X_Frac						; Fractional X-Delta
;	Delta_X								; X-Delta (Valid Values) (+ = move right, - = move left)
;	Delta_Y_Sign						; Y-Delta Sign (toggles betwen $00:Down, $FF:Up)
;	Delta_Y_Frac						; Fractional Y-Delta
;	Delta_Y								; Y-Delta (Valid Values) (+ = move down, - = move up)

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
.var Colour_Map_On		.byte = $488	; Non-zero when XDL_Attribute (Colour Map) is the active XDL

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

; Ball arrays (struct-of-arrays), indexed by the ball number in X.
; MAX_SPRITES_PAL balls, but Bob_Stride is $40 (64), NOT $30 (48).  That looks
; like 176 wasted bytes and is deliberate: 64 divides 256, so no array can ever
; straddle a page boundary and lda abs,x stays at 4 cycles on every field.  A
; stride of $30 would put two of the eleven arrays across a page.  The base is
; divides 256, so no array can ever straddle a page boundary - lda abs,x on
; any field costs 4 cycles for every ball.  Occupies $5500-$57BF.
.def	Bob_Stride						= $40	; Bytes per field array
Bobs	equ	$5500						; Base of the ball field arrays

Bob_X_Pos_Frac		equ	Bobs+[$00*Bob_Stride]	; $5500  X sub-pixel fraction
Bob_X_Pos_Lo		equ	Bobs+[$01*Bob_Stride]	; $5540  X low byte
Bob_X_Pos_Hi		equ	Bobs+[$02*Bob_Stride]	; $5580  X high byte (X valid 0-319)
Bob_Y_Pos_Frac		equ	Bobs+[$03*Bob_Stride]	; $55C0  Y sub-pixel fraction
Bob_Y_Pos			equ	Bobs+[$04*Bob_Stride]	; $5600  Y (valid 0-239, no hi byte)
Bob_Delta_X_Sign	equ	Bobs+[$05*Bob_Stride]	; $5640  $00 = right, $FF = left
Bob_Delta_X_Frac	equ	Bobs+[$06*Bob_Stride]	; $5680  X velocity fraction
Bob_Delta_X			equ	Bobs+[$07*Bob_Stride]	; $56C0  X velocity integer
Bob_Delta_Y_Sign	equ	Bobs+[$08*Bob_Stride]	; $5700  $00 = down, $FF = up
Bob_Delta_Y_Frac	equ	Bobs+[$09*Bob_Stride]	; $5740  Y velocity fraction
Bob_Delta_Y			equ	Bobs+[$0A*Bob_Stride]	; $5780  Y velocity integer

;-----------------------------------------------------------------------------
; Defines go here
;-----------------------------------------------------------------------------
; __VBXE_AUTO__ must NOT be defined: this code reaches the VBXE with plain
; absolute lda/sta, so VBXE_BASE has to be fixed at assembly time.  Defining it
; sets VBXE_BASE = $0000 and every register access lands in zero page.
.def	VBXE_WINDOW						= $2000
.def	VBXE_WINDOW_SIZE_4k				= $1000
.def	VBXE_WINDOW_SIZE_8k				= $2000
.def	LOAD_ADDRESS					= VBXE_WINDOW + VBXE_WINDOW_SIZE_4k
.def	SCREEN_RAM						= $8000	; Make sure this is > Mus_Song_End

; Temp debug stuff
.def	DBG_SINGLE_STEP					= $00	; 00 = False else true
.def	MAX_SPRITES_PAL					= $30	; (Previously was $25!)
.def	MAX_SPRITES_NTSC				= $18

; Background clear height, and the ball Y clamp derived from it.
; The clear is the single biggest consumer of blitter bandwidth - 320x240 is
; 76,800 of the ~166,000 cycles the blitter gets in a PAL frame once overlay
; and attribute-map DMA are paid.  Trimming rows off the bottom is the only
; lever left that does not touch the 32x32 ball blit.
;
; BLT_BAKGRND has zoom 8x8, so its height byte moves in 8-pixel steps:
;   $1D = 240 rows (full screen)   $1C = 232   $1B = 224   $1A = 216
; Y_POS_MAX is derived so the clamp always matches the cleared area.  If these
; two ever disagree the balls leave permanent trails in the uncleared strip.
.def	CLEAR_H							= $1C	; Clear height byte -> 232 rows
.def	CLEAR_ROWS						= [CLEAR_H+1]*8
.def	Y_POS_MAX						= CLEAR_ROWS-32	; Lowest legal ball Y

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
.def	V_2								= $16	; 6 (Screen code used for Version in loading screen)
.def	V_3								= $61	; a  (Screen code used for Version in loading screen)

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

	lda #$01
	sta Colour_Map_On					; XDL_Attribute (Colour Map on) is the active XDL

	lda #$00
	sta COLOR2							; Set Playfield Black
	jsr Setup_DisplayList
	jsr Wait_For_Sync

	lda #%00000011						; XDL,XCOLOR Enabled and transparent color index 0
	sta VBXE_VIDEO_CONTROL

	lda #$FF							; Must set priority when using Attribute Map
	sta VBXE_P0							; because VBXE defaults PO-P$ to #$00 on power-up

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
; X = ball index
;-----------------------------------------------------------------------------
Reverse_X
	sec
	lda #$00
	sbc Bob_Delta_X_Frac,x
	sta Bob_Delta_X_Frac,x
	lda #$00
	sbc Bob_Delta_X,x
	sta Bob_Delta_X,x
	lda Bob_Delta_X_Sign,x
	eor #$FF
	sta Bob_Delta_X_Sign,x
	rts

;-----------------------------------------------------------------------------
; Reverse_Y - 2's complement negate of Delta_Y_Sign:Delta_Y:Delta_Y_Frac
; X = ball index
;-----------------------------------------------------------------------------
Reverse_Y
	sec
	lda #$00
	sbc Bob_Delta_Y_Frac,x
	sta Bob_Delta_Y_Frac,x
	lda #$00
	sbc Bob_Delta_Y,x
	sta Bob_Delta_Y,x
	lda Bob_Delta_Y_Sign,x
	eor #$FF
	sta Bob_Delta_Y_Sign,x
	rts

;-----------------------------------------------------------------------------
; Set_Positions
; For each sprite: update position with sub-pixel accuracy, bounce off walls,
; compute VBXE address via Calculate_200, write to BLT_BALL BCB, fire blitter.
; X = ball index, used to index every Bob_* field array directly
;-----------------------------------------------------------------------------
Set_Positions
	lda #$80
	sta VBXE_MA_BSEL					; Enable VBXE window for BCB writes

	lda VBXE_WINDOW+$405				; XDL Adr2 (byte 5 of XDL at VBXE_WINDOW+$400)
	eor #$06							; Flip between $02 ($020000) and $04 ($040000)
	sta Reg7							; Backbuffer Adr2 - constant for the whole frame

	ldx #$00

Spr_Loop
	lda Do_Motion
	bne Set_X
	jmp Skip_Motion						; Long branch fix

;--- X motion ----------------------------------------------------------------
Set_X
	clc
	lda Bob_X_Pos_Frac,x
	adc Bob_Delta_X_Frac,x
	sta Bob_X_Pos_Frac,x

	lda Bob_X_Pos_Lo,x
	adc Bob_Delta_X,x
	sta Bob_X_Pos_Lo,x

	lda Bob_X_Pos_Hi,x
	adc Bob_Delta_X_Sign,x				; $00 = right, $FF = left
	sta Bob_X_Pos_Hi,x					; sta does not touch flags, so the adc's N survives

; Left wall: X_Pos_Hi >= $80 means position underflowed past 0
	bpl X_Check_Right
	lda #$00
	sta Bob_X_Pos_Hi,x
	sta Bob_X_Pos_Lo,x
	sta Bob_X_Pos_Frac,x
	lda Bob_Delta_X_Sign,x
	bpl X_Done							; Already heading right
	jsr Reverse_X
	jmp X_Done

; Right wall: clamp if X_Pos > $0120 (320 - 32 = 288)
X_Check_Right							; A still holds X_Pos_Hi from the add above
	cmp #$01
	bcc X_Done							; Hi < $01, in range
	bne X_Hit_Right						; Hi > $01, past right edge
	lda Bob_X_Pos_Lo,x
	cmp #$21							; Lo > $20?
	bcc X_Done
X_Hit_Right
	lda #$01
	sta Bob_X_Pos_Hi,x
	lda #$20
	sta Bob_X_Pos_Lo,x
	lda #$00
	sta Bob_X_Pos_Frac,x
	lda Bob_Delta_X_Sign,x
	bmi X_Done							; Already heading left
	jsr Reverse_X
X_Done

;--- Y motion ----------------------------------------------------------------
	clc
	lda Bob_Y_Pos_Frac,x
	adc Bob_Delta_Y_Frac,x
	sta Bob_Y_Pos_Frac,x

	lda Bob_Y_Pos,x
	adc Bob_Delta_Y,x
	sta Bob_Y_Pos,x

	lda Bob_Delta_Y_Sign,x
	bmi Y_Check_Top

; Moving down: clamp at Y_POS_MAX (CLEAR_ROWS - 32) so the ball's bottom row is
; still inside the area BLT_BAKGRND clears, or it would leave a permanent trail
Y_Check_Bottom
	lda Bob_Y_Pos,x
	cmp #Y_POS_MAX+1
	bcc Y_Done
	lda #Y_POS_MAX
	sta Bob_Y_Pos,x
	lda #$00
	sta Bob_Y_Pos_Frac,x
	lda Bob_Delta_Y_Sign,x
	bmi Y_Done							; Already heading up
	jsr Reverse_Y
	jmp Y_Done

; Moving up: underflow wraps Y_Pos above Y_POS_MAX
Y_Check_Top
	lda Bob_Y_Pos,x
	cmp #Y_POS_MAX+1
	bcc Y_Done
	lda #$00
	sta Bob_Y_Pos,x
	sta Bob_Y_Pos_Frac,x
	lda Bob_Delta_Y_Sign,x
	bpl Y_Done							; Already heading down
	jsr Reverse_Y
Y_Done

;--- Compute VBXE address and blit -------------------------------------------
Skip_Motion								; Jump here to bypass ball motion
	jsr Calculate_200					; Reads Bob_* via X -> Reg4=Adr0, Reg5=Adr1, Reg6=Adr2

	lda Reg4
	sta VBXE_WINDOW+$500+BLT_BALL-BLT_BALL+Dest_Adr0
	lda Reg5
	sta VBXE_WINDOW+$500+BLT_BALL-BLT_BALL+Dest_Adr1
	lda Reg6
	sta VBXE_WINDOW+$500+BLT_BALL-BLT_BALL+Dest_Adr2

	jsr Draw_Sprite						; Wait for blitter idle then fire BLT_BALL

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
; Starting positions read from Init_Pos_X_Lo and Init_Pos_Y tables (there is no
; X_Hi table - the startup image fits in a byte, so Bob_X_Pos_Hi starts at 0).
; Velocities read from Init_Delta_X/Y tables (unchanged).
;-----------------------------------------------------------------------------
Init_Objects
	ldx #$00

Init_Spr_L
	; Positions and velocities come from flat tables already indexed by ball number
	lda Init_Pos_X_Lo,x
	sta Bob_X_Pos_Lo,x
	lda Init_Pos_Y,x
	sta Bob_Y_Pos,x
	lda Init_Delta_X,x
	sta Bob_Delta_X,x
	lda Init_Delta_X_Frac,x
	sta Bob_Delta_X_Frac,x
	lda Init_Delta_Y,x
	sta Bob_Delta_Y,x
	lda Init_Delta_Y_Frac,x
	sta Bob_Delta_Y_Frac,x

	lda #$00							; Fractions and X_Pos_Hi start at zero,
	sta Bob_X_Pos_Frac,x				; and every ball starts moving right and down
	sta Bob_X_Pos_Hi,x
	sta Bob_Y_Pos_Frac,x
	sta Bob_Delta_X_Sign,x
	sta Bob_Delta_Y_Sign,x

	inx
	cpx #MAX_SPRITES_PAL				; Every slot, not just Num_Sprites, so NTSC
	bne Init_Spr_L						; still initialises the ones it does not draw
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
	sta VBXE_WINDOW+$405				; XDL_Attribute Adr2
	sta VBXE_WINDOW+$41A				; XDL_Normal Adr2 - kept in sync so Toggle_Colour_Map can't desync buffers
	rts
;--------------------------------------------------------

;-----------------------------------------------------------------------------
; Toggle_Colour_Map - switches the active XDL between XDL_Attribute and XDL_Normal
;-----------------------------------------------------------------------------
Toggle_Colour_Map
	lda Colour_Map_On
	bne Toggle_Colour_Map_Off
	jsr Enable_Colour_Map
	rts
Toggle_Colour_Map_Off
	jsr Disable_Colour_Map
	rts

;-----------------------------------------------------------------------------
; Disable_Colour_Map (Point XDL to XDL_Normal, offset $15 from XDL_Attribute)
;-----------------------------------------------------------------------------
Disable_Colour_Map
	lda #$00
	sta VBXE_XDL_ADR2
	lda #$04
	sta VBXE_XDL_ADR1
	lda #$15
	sta VBXE_XDL_ADR0

	lda #%00000001						; XDL Enabled and transparent color index 0
	sta VBXE_VIDEO_CONTROL

	lda #$00
	sta Colour_Map_On
	rts

;-----------------------------------------------------------------------------
; Enable_Colour_Map (Point XDL to XDL_Attribute)
;-----------------------------------------------------------------------------
Enable_Colour_Map
	lda #$00
	sta VBXE_XDL_ADR0
	sta VBXE_XDL_ADR2
	lda #$04
	sta VBXE_XDL_ADR1

	lda #%00000011						; XDL,XCOLOR Enabled and transparent color index 0
	sta VBXE_VIDEO_CONTROL

	lda #$01
	sta Colour_Map_On
	rts

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

	jsr Handle_Keys						; Take care of user input

	rts									; Else return to caller

;-----------------------------------------------------------------------------
; Handle_Keys
;-----------------------------------------------------------------------------
Handle_Keys
; If present, the next lines will allow a "jump to exit" on a specific key press
	lda CH
	cmp #$2F							; Press Q to quit
	beq Exit_Long
	cmp #$32							; 0
	beq Handle_0
Handle_Keys_Done						; No more keys to test
	jmp Read_Key_Done

Handle_0
	jsr Toggle_Colour_Map				; Toggle the Colour Map (Attribute XDL) on/off
	jmp Read_Key_Done

Read_Key_Done
	lda #$FF
	sta CH								; Clear last key pressed
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
Setup_Cmap1_L2
	lda VBXE_BLITTER_BUSY
	cmp #$00
	bne Setup_Cmap1_L2					; Wait for blitter to finish before returning
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
Setup_Cmap2_L2
	lda VBXE_BLITTER_BUSY
	cmp #$00
	bne Setup_Cmap2_L2					; Wait for blitter to finish before returning
	rts

;-----------------------------------------------------------------------------
; Calculate_200
;   X    = ball index; X_Pos_Lo/Hi and Y_Pos are read straight from the Bob_*
;          arrays, so this routine is specific to the ball loop (its only caller)
;   Reg7 = backbuffer Adr2, computed once per frame by Set_Positions
;   Reg4 = Adr0	   VBXE Blitter Address
;   Reg5 = Adr1	   VBXE Blitter Address
;   Reg6 = Adr2	   VBXE Blitter Address
;-----------------------------------------------------------------------------
Calculate_200
; The VBXE window is already bank $00 with global enable - Set_Positions sets
; VBXE_MA_BSEL before the loop and only clears it once every ball is drawn.

; Calculate the start of VRAM (Reg4, Reg5, Reg6) for the given Y-Pos
	lda #$00
	sta Reg4							; Reset to initial value
	sta Reg6							; Reset to initial value
	lda Bob_Y_Pos,x						; Y_Pos
	bpl Skip_Reg6						; If A <= $7F Reg6 will be 0
	inc Reg6							; Else Reg6 = 1 (leaves A and Y alone)
Skip_Reg6
	asl									; Multiply by 2
	sta Reg5

; Now move into that line in VRAM based on the X-Position
	clc									; Prepare to add
	lda Bob_X_Pos_Lo,x					; X_Pos_L
	adc Reg4							; Add Adr0
	sta Reg4							; Store it
	lda Bob_X_Pos_Hi,x					; X_Pos_H
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
Calculate_200_End						; TODO: Re-measure - the bank save/restore and the XDL read are now hoisted into Set_Positions
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
; Uses the temp table at $600 to setup the Attribute Colour Map
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
	adc #$28							; Advance by one line ($28 bytes/line)
	sta VBXE_WINDOW+$554+$06			; Dest Addr 2

	lda VBXE_WINDOW+$554+$07			; Dest Addr 1
	adc #$00
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
	dta $01,$01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03	; Objs $00-$0F
	dta $00,$01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03	; Objs $10-$1F
	dta $00,$01,$02,$03,$00,$00,$01,$02,$03,$00,$01,$02,$03,$00,$01,$02	; Objs $20-$2F
Init_Delta_X_Frac
	dta $00,$40,$80,$C0,$10,$50,$90,$D0,$20,$60,$A0,$E0,$30,$70,$B0,$F0	; Objs $00-$0F
	dta $40,$80,$C0,$00,$50,$90,$D0,$10,$60,$A0,$E0,$20,$70,$B0,$F0,$30	; Objs $10-$1F
	dta $80,$C0,$00,$40,$90,$00,$30,$60,$90,$C0,$F0,$20,$50,$80,$B0,$E0	; Objs $20-$2F
Init_Delta_Y
	dta $06,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03,$01,$01,$02,$03,$00	; Objs $00-$0F
	dta $01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03,$00	; Objs $10-$1F
	dta $01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03,$00,$01,$02,$03,$00	; Objs $20-$2F
Init_Delta_Y_Frac
	dta $00,$60,$A0,$E0,$30,$70,$B0,$F0,$40,$80,$C0,$00,$50,$90,$D0,$10	; Objs $00-$0F
	dta $60,$A0,$E0,$20,$70,$B0,$F0,$30,$80,$C0,$00,$40,$90,$D0,$10,$50	; Objs $10-$1F
	dta $A0,$E0,$20,$60,$B0,$18,$48,$78,$A8,$D8,$08,$38,$68,$98,$C8,$F8	; Objs $20-$2F

; The balls spell out the ball count on the startup screen.  Generated by
; tools/gen_layout.py from Assets/layout48.txt - edit the ASCII grid there and
; re-run the tool rather than hand-editing these two tables.
Init_Pos_X_Lo
	dta $36,$48,$36,$48,$24,$36,$48,$90,$A2,$B4,$C6,$12,$36,$48,$7E,$D8	; Objs $00-$0F
	dta $00,$36,$48,$7E,$D8,$00,$12,$24,$36,$48,$7E,$D8,$36,$48,$90,$A2	; Objs $10-$1F
	dta $B4,$C6,$36,$48,$7E,$D8,$36,$48,$7E,$D8,$7E,$D8,$90,$A2,$B4,$C6	; Objs $20-$2F
Init_Pos_Y
	dta $00,$00,$0D,$0D,$1A,$1A,$1A,$1A,$1A,$1A,$1A,$27,$27,$27,$27,$27	; Objs $00-$0F
	dta $34,$34,$34,$34,$34,$41,$41,$41,$41,$41,$41,$41,$4E,$4E,$4E,$4E	; Objs $10-$1F
	dta $4E,$4E,$5B,$5B,$5B,$5B,$68,$68,$68,$68,$75,$75,$82,$82,$82,$82	; Objs $20-$2F

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
