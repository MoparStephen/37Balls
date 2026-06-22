 ; .loadsym "\out\.lab" PUT PATH OF .LAB FILE HERE, USE THIS WITH ALTIRRA EMULATOR
 
;-----------------------------------------------------------------------------
; Memory Map
;-----------------------------------------------------------------------------
; Load Address = 
; Run Address = 

;-----------------------------------------------------------------------------
;  HARDWARE EQUATES
;-----------------------------------------------------------------------------
    icl 'equates.asm'

;-----------------------------------------------------------------------------
; Structure Declarations
;-----------------------------------------------------------------------------

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

; Non Page-0 Variables
;	$480 to $4FF free
;	$600 to $6FF free
; When using PMG the 1st $300 bytes are always free
.var SDMCTL_OLD			.byte = $480	; Save DMA
.var CRSINH_OLD			.byte = $481	; Save CRSINH (Mouse Pointer)
.var LMARGIN_OLD		.byte = $482	; Save LMARGIN
.var COLOR2_OLD			.byte = $483	; Save COLOR2
.var SP_REG_OLD			.byte = $484	; Save the Stack Pointer
.var SDLSTL_OLD			.byte = $485	; Save the Display List Pointer
.var SDLSTH_OLD			.byte = $486	; Save the Display List Pointer
.var DOSINIL_OLD		.byte = $487	; Save the DOSINI Pointer
.var DOSINIH_OLD		.byte = $488	; Save the DOSINI Pointer

;-----------------------------------------------------------------------------
; Defines go here
;-----------------------------------------------------------------------------
.def	__VBXE_AUTO__
.def	VBXE_WINDOW						= $2000
.def	VBXE_WINDOW_SIZE_4k				= $1000
.def	VBXE_WINDOW_SIZE_8k				= $2000
.def	LOAD_ADDRESS					= VBXE_WINDOW + VBXE_WINDOW_SIZE_8k
.def	SCREEN_RAM						= $8000	; Make sure this is > Mus_Song_End

; BCB field byte offsets
.def	Src_Adr0						= $00
.def	Src_Adr1						= $01
.def	Src_Adr2						= $02
.def	Dest_Adr0						= $06
.def	Dest_Adr1						= $07
.def	Dest_Adr2						= $08
.def	Blt_Ctrl						= $14

; Temp debug stuff
.def	V_0								= $10	; 0 (Screen code used for Version in loading screen)
.def	V_1								= $16	; 6 (Screen code used for Version in loading screen)
.def	V_2								= $11	; 1 (Screen code used for Version in loading screen)
.def	V_3								= $00	; 61=a (Screen code used for Version in loading screen)

;-----------------------------------------------------------------------------
; VBXE Helpers
;-----------------------------------------------------------------------------
	org LOAD_ADDRESS
.pages 2								; DO NOT go past $3200
	icl	'fileio.lib'
	icl	'vbxe_min.asm'					; Use my VBXE_SetPalette2 to load linear palete

;-----------------------------------------------------------------------------
; Clean up and exit based on LoadStatus
;-----------------------------------------------------------------------------
Cleanup_Exit
	lda	#MEMAC_GLOBAL_DISABLE			; USE CPU address space
	sta VBXE_MA_BSEL
	sta VBXE_VIDEO_CONTROL				; Disable XDL

	lda SDMCTL_OLD
	sta SDMCTL							; Restore SDMCTL

	lda LMARGIN_OLD
	sta LMARGIN							; Restore LMARGIN

	lda DOSINIL_OLD
	sta DOSINI
	lda DOSINIH_OLD
	sta DOSINI + 1						; Restore DOSINI

	lda #$FF
	sta CH								; Clear last key pressed

	jmp	(DOSVEC)						; Return to DOS

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

	org LOAD_ADDRESS + $200				; Libraries live above

;-----------------------------------------------------------------------------
; Main loop
;-----------------------------------------------------------------------------
main

; All done - now loop forever
	jsr Wait_For_Sync					; Wait for VSYNC, Q quits
	jmp main

; Set RUN Vector
	run main

;-----------------------------------------------------------------------------
; Clean up and exit
;-----------------------------------------------------------------------------
Exit
	lda #$FF
	sta CH								; Clear last key pressed
	jmp	(DOSVEC)

;-----------------------------------------------------------------------------
; END OF CODE
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Subroutines BEGIN
;-----------------------------------------------------------------------------
;-----------------------------------------------------------------------------
; Wait For VSync (locks to the refresh rate, PAL=50Hz, NTSC=60Hz)  Thanks tebe
;-----------------------------------------------------------------------------
Wait_For_Sync							; Hold until VCOUNT == 0
	bit	VCOUNT
	bmi *-3
	bit	VCOUNT
	bpl *-3
; If present, the next 3 lines will allow a "jump to exit" on a specific key press
	lda CH
	cmp #$2F							; Press Q to quit
	beq	Exit
	rts									; Else return to caller
;-----------------------------------------------------------------------------
; Subroutines END
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Data Tables go here
;-----------------------------------------------------------------------------