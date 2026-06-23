;-----------------------------------------------------------------------------
; Initialization
;-----------------------------------------------------------------------------
; Step $01 - Clear screen and print initial loading screen
	org LOAD_ADDRESS + $300
.proc Step_1
; Save any values that will be changed so they can be restored on exit
	lda SDMCTL
	sta SDMCTL_OLD						; Save SDMCTL so we can restore it later

	lda CRSINH
	sta CRSINH_OLD						; Save CRSINH so we can restore it later

	lda LMARGIN
	sta LMARGIN_OLD						; Save LMARGIN so we can restore it later

	lda COLOR1
	sta COLOR1_OLD						; Save COLOR1 so we can restore it later

	lda COLOR2
	sta COLOR2_OLD						; Save COLOR2 so we can restore it later

	lda SDLSTL
	sta SDLSTL_OLD						; Save SDLSTL so we can restore it later

	lda SDLSTL+1
	sta SDLSTH_OLD						; Save SDLSTH so we can restore it later

; Check for SDX
Check_SDX
	lda $0700
	cmp #$53							; ASCII S
	bne SDX_No
	lda $0701
	cmp #$44							; ASCII D
	bne SDX_No

; Use IOCB channel 2 to force a CON 40 call
SDX_Yes
	ldx #$20							; Channel 2
	lda #$50
	sta ICCMD,x
	lda #<Device
	sta ICBAL,x
	lda #>Device
	sta ICBAH,x
	lda #$0C							; Read + Write
	sta ICAX1,x							; Aux1
	lda #$40
	sta ICAX2,x							; Aux2
	jsr CIOV

; TODO: Close Channel #2 (and do this in the APOD viewer as well)
SDX_No
	lda #$00
	sta LMARGIN

	lda #$01
	sta CRSINH

	mwa #Clear_Screen TextPtr
	jsr PutLine							; Cheap way to get a channel open to the screen

; Determine and update Video Format
	lda #$00
	sta Ptr_Lo
Wait1
	lda vcount
	beq Wait1
Wait2
	tay									; Save largest value in Y
	lda vcount
	bne Wait2
; VCount = zero, but we've saved the largest possible in Y
	cpy #$85 							; NTSC will never get this high
	bcc NTSC_Detected

PAL_Detected
	lda #$00
	sta Video_Flag						; Save for later
	lda #$A8							; Light Green
	sta Reg1
	lda #$A0							; Dark Green
	sta Reg2
	jmp Set_Colours

NTSC_Detected
	lda #$01
	sta Video_Flag						; Save for later
	lda #$BA							; Light Green
	sta Reg1
	lda #$B0							; Dark Green
	sta Reg2

Set_Colours
	lda Reg1							; Dark Green
	sta COLOR1							; Set playfield
	lda Reg2							; Light Green
	sta COLOR2							; Set text

; Grab the pointer to the top of screen ram
	lda SAVMSC
	sta Ptr_Lo
	lda SAVMSC+1
	sta Ptr_Hi

; Print the initial loading message
; Each subsequent init stage will update it
	ldy #$00
Print_Loading_L1						; Copy the 1st $100 bytes
	lda Step1_Message,y
	sta (Ptr_Lo),y
	dey
	bne Print_Loading_L1

	ldy #$00
	inc Ptr_Hi
Print_Loading_L2						; Copy the 2nd $100 bytes
	lda Step1_Message+$100,y
	sta (Ptr_Lo),y
	dey
	bne Print_Loading_L2

	ldy #$00
	inc Ptr_Hi
Print_Loading_L3						; Copy the 3rd $100 bytes
	lda Step1_Message+$200,y
	sta (Ptr_Lo),y
	dey
	bne Print_Loading_L3

	ldy #<(Device-Step1_Message-1)
	inc Ptr_Hi
Print_Loading_L4						; Copy the final partial page
	lda Step1_Message+$300,y
	sta (Ptr_Lo),y
	dey
	bne Print_Loading_L4

	dec Ptr_Hi
	dec Ptr_Hi
	dec Ptr_Hi							; Restore to beginning of screen RAM
	lda #$CA
	sta Reg1							; Pointer to screen RAM for progress dots

	lda Video_Flag
	beq Print_Loading_Done
; Print NTSC_Warning_Message - line 2 (y = $51)
	ldy #$51
	ldx #$00
NTSC_Warning_Message_L1
	lda NTSC_Warning_Message,x
	sta (Ptr_Lo),y
	inx
	iny
	cpx #$26							; Copy $26 characters
	bne NTSC_Warning_Message_L1

Print_Loading_Done
	rts									; Return controll to loader

Clear_Screen
	.byte $7D,$9B
Step1_Message							; Internal screen codes
	.byte $51,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$45
	.byte $7C,$00,$00,$00,$00,$2C,$6F,$61,$64,$69,$6E,$67,$00,$36,$22,$38,$25,$00,$22,$6C,$69,$74,$74,$65,$72,$00,$24,$65,$6D,$6F,$00,V_0,$0E,V_1,V_2,V_3,$00,$00,$00,$7C
	.byte $7C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7C
	.byte $7C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7C
	.byte $41,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$44
	.byte $7C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$7C
	.byte $41,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$44
Intro_Text_Message
	.sb $7C,'This demo was inspired by an STE Demo ',$7C
	.sb $7C,' www.youtube.com/watch?v=x1ekLXdo-2c  ',$7C
	.sb $7C,' 24 32x32 objects 320x256x 16 @ 50 Hz ',$7C
	.sb $7C,'I managed to get quite a bit more!    ',$7C
	.sb $7C,' 37 32x32 objects 320x240x256 @ 50 Hz ',$7C
	.sb $7C,'                                      ',$7C
	.sb $7C,'Video is 3 hardware layers overlaid:  ',$7C
	.sb $7C,' ANTIC Displays 320*240 monochrome BG ',$7C
	.sb $7C,' VBXE Colour Map : 208 colours for BG ',$7C
	.sb $7C,' VBXE Blits  37 32*32 Sprites @ 50Hz  ',$7C
	.sb $7C,' RMT  Music Player 4 channels @ 50Hz  ',$7C
	.sb $7C,'                                      ',$7C
	.sb $7C,'Code  : Stephen (MADS + VS Code)      ',$7C
	.sb $7C,'Grafix: Stephen (GIMP + Custom Toolz) ',$7C
	.sb $7C,'Musix : Atari LED (c)Michal Szpilowski',$7C
	.sb $7C,'        Radek Sterba (RIP) RMT Player ',$7C
	.byte $5A,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$52,$43
NTSC_Warning_Message
	.sb 'NTSC Detected - limiting to 24 sprites'
Device
	dta c'E:',$9B
.endp
	ini Step_1

; Step $02 - Ensure RAMTOP is = $C0 and no BASIC cart/ROM is present
	org LOAD_ADDRESS + $300
.proc Check_RAMTOP
; Disable BASIC
	lda #$C0							; Check if RAMTOP is already OK
	cmp RAMTOP							; Prevent flickering if BASIC is already off
	beq Ram_Ok

	lda #$01							; Set BASICF for OS
	sta BASICF							; so BASIC remains OFF after RESET

	lda PORTB							; Disable BASIC bit in PORTB for MMU
	ora #$02							; by Setting bit 2
	sta PORTB

	lda $A000							; Check if BASIC ROM area is now RAM
	inc $A000							; This will also catch SDX not launching
	cmp $A000							; the app via X
	beq Ram_Not_Ok						; If not, perform print error and exit

	lda #$0C							; 12 = CLOSE
	jsr Do_CIOV							; Close editor

	lda #$C0
	sta RAMTOP							; Set RAMTOP to end of BASIC
	sta RAMSIZ							; Set RAMSIZ also

	ldx #$00							; Channel #0
	lda #$04							; 4 = OPEN_READ
Do_CIOV
	sta ICCOM							; Store the Command
	lda #<Device_Name
	sta ICBAL							; Use channel #0
	lda #>Device_Name
	sta ICBAH
	jsr CIOV

Ram_Ok
	rts

Ram_Not_Ok; Add your error handling here, there still is a ROM....
	ldy #$42							; Dark Red
	sty COLOR2							; Set playfield

; Print RAM_Failure_Message - line 3 (y = $79)
	ldy #$79
	ldx #$00
RAM_Failure_Message_L1
	lda RAM_Failure_Message_Line1,x
	sta (Ptr_Lo),y
	inx
	iny
	cpx #$23							; Copy $23 characters
	bne RAM_Failure_Message_L1

; Print RAM_Failure_Message - line 5
	ldy #$D1
	ldx #$00
RAM_Failure_Message_L2
	lda RAM_Failure_Message_Line2,x
	sta (Ptr_Lo),y
	inx
	iny
	cpx #$15							; Copy $15 characters
	bne RAM_Failure_Message_L2

	jsr Wait_For_Key_Exit

	jmp WARMSV							; Warm Start

Device_Name
	dta c'E:', $00
RAM_Failure_Message_Line1
	.sb 'This program requires at least 48kB'
RAM_Failure_Message_Line2
	.sb 'Press any key to exit'
.endp
	ini Check_RAMTOP

; Step $03 - Detect the VBXE and print address or Quit if not found
	org LOAD_ADDRESS + $300
.proc Detecting_VBXE
	jsr VBXE_Detect						; VBXE core 1.07 and above detection
	bcc VBXE_Found						; If found skip the code below

VBXE_Not_Found
	ldy #$42							; Dark Red
	sty COLOR2							; Set playfield

; Print VBXE_NPresent - line 3 (y = $79)
	ldy #$79
	ldx #$00
Print_VBXE_NPresent_L1
	lda VBXE_NPresent,x
	sta (Ptr_Lo),y
	inx
	iny
	cpx #$24							; Copy $24 characters
	bne Print_VBXE_NPresent_L1

	jsr Wait_For_Key_Exit
	jmp Cleanup_Exit					; Cleanup then return controll to DOS

VBXE_Found
	ldy #$36							; ASCII 6
	cpx #$D6
	beq VBXE_Found_Done					; VBXE at D6
	inc VBXE_Address+1					; VBXE at D7 so change text!
	iny									; Now ASCII 7

VBXE_Found_Done
	sty Reg2							; Save for later so we can update the About Panel
; Print VBXE_Detected - line 3 (y = $79)
	ldy #$79
	ldx #$00
Print_VBXE_Detected_L1
	lda VBXE_Detected,x
	sta (Ptr_Lo),y
	inx
	iny
	cpx #$21							; Copy $21 characters
	bne Print_VBXE_Detected_L1

; Update Progress bar - line 5 (y = $CB + (4 * increment #))
	ldy Reg1
	lda #$54							; Screen RAM code for Ctrl+T
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sty Reg1							; Save pointer for progress bar updates

	rts									; Return controll to loader

VBXE_Detected
	.sb 'VBXE Detected at '
VBXE_Address
	.sb '$D640            '
VBXE_NPresent
	.sb '  ! VBXE not found - any key Quit ! '

.endp
	ini Detecting_VBXE

; Step $04 - Clear VBXE RAM
	org LOAD_ADDRESS + $300
.proc clear_vbxe
; Print Clearing_Message - line 3 (y = $79)
	ldy #$79
	ldx #$00
Print_Clearing_Message_L1
	lda Clearing_Message,x
	sta (Ptr_Lo),y
	inx
	iny
	cpx #$21							; Copy $21 characters
	bne Print_Clearing_Message_L1

; Update Progress bar - line 5 (y = $CB + (5 * increment #))
	ldy Reg1
	lda #$54							; Screen RAM code for Ctrl+T
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sty Reg1							; Save pointer for progress bar updates

; Set the base address of MEMA window to VBXE_WINDOW
; Size to 4k and accesible only by CPU
	lda	#>VBXE_WINDOW + 8
	vbsta VBXE_MA_CTL

	lda	#$00 | MEMAC_GLOBAL_ENABLE		; Bank $00 VBXE Window Enabled
	vbsta VBXE_MA_BSEL

	; Copy blit to VBXE memory
	ldx #$14
	mva:rpl blit_clear,x VBXE_WINDOW,x-

	; Kick blit
	lda #$00
	sta VBXE_BL_ADR0
	sta VBXE_BL_ADR1
	sta VBXE_BL_ADR2
	mva #$01 VBXE_BLITTER_START

	; Wait for blit complete
	lda:rne VBXE_BLITTER_BUSY

	lda	#MEMAC_GLOBAL_DISABLE			; USE CPU address space
	vbsta VBXE_MA_BSEL

	rts									; Return controll to loader

blit_clear
	; clear 496kB (leave bottom 16kB for the SVBXE.SYS driver)
	; 496x16 zoom 8x8 clear blit (this takes 2 frames)

	;	dta e($00000)	; Source address
	;	dta a($0000)	; Source step y
	;	dta 0			; Source step x
	;	dta e($7BFFF)	; Destination address
	;	dta a(-$0F80)	; Destination step y (backwards 3968 bytes) - NOTE: this equals 496 * zoom factor of 8
	;	dta -1			; Destination step x (backwards	1 byte)
	;	dta a($01EF)	; Width-1  (495)	496 * 8 bytes wide
	;	dta $0F			; Height-1 (15)		 16 * 8 bytes high
	;	dta $00			; And mask (And mask equal to 0 so clear)
	;	dta $00			; Xor mask (will be filled with xor mask)
	;	dta $00			; Collision and mask
	;	dta $77			; Zoom (BLT_ZOOMY = 7, BLT_ZOOMX = 7 so 8Y*8X)
	;	dta $00			; Pattern feature
	;	dta $00			; Control (Mode 0 with NEXT bit Cleared)

	dta e($00000), a($0000), 0, e($7BFFF), a(-$0F80), -1, a($01EF), $0F, $00, $00, $00, $77, $00, $00
Clearing_Message
	.sb 'Clearing VBXE RAM                '

.endp
	ini clear_vbxe

; Step $05 - Load the XDL
	org LOAD_ADDRESS + $300
.proc Load_XDL
	lda	#$00 | MEMAC_GLOBAL_ENABLE		; Bank $00 VBXE Window Enabled
	vbsta VBXE_MA_BSEL

; Print Load_XDL_Message - line 3 (y = $79)
	ldy #$79
	ldx #$00
Print_Load_XDL_Message_L1
	lda Load_XDL_Message,x
	sta (Ptr_Lo),y
	inx
	iny
	cpx #$21							; Copy $21 characters
	bne Print_Load_XDL_Message_L1

; Update Progress bar - line 5 (y = $CB + (4 * increment #))
	ldy Reg1
	lda #$54							; Screen RAM code for Ctrl+T
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sty Reg1							; Save pointer for progress bar updates

	rts									; Return controll to loader

Load_XDL_Message
	.sb 'Loading xdl.asm                  '

.endp
	ini Load_XDL

	org VBXE_WINDOW + $400				; Load data directly into VBXE RAM
XDL_START
	icl 'xdl.asm'
XDL_Length	equ *-XDL_START

; Step $06 - Load the BCBs
	org LOAD_ADDRESS + $300
.proc Load_BCB
	lda	#$00 | MEMAC_GLOBAL_ENABLE		; Bank $00 VBXE Window Enabled
	vbsta VBXE_MA_BSEL

; Print Load_BCB_Message - line 3 (y = $79)
	ldy #$79
	ldx #$00
Print_Load_BCB_Message_L1
	lda Load_BCB_Message,x
	sta (Ptr_Lo),y
	inx
	iny
	cpx #$21							; Copy $21 characters
	bne Print_Load_BCB_Message_L1

; Update Progress bar - line 5 (y = $CB + (5 * increment #))
	ldy Reg1
	lda #$54							; Screen RAM code for Ctrl+T
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sty Reg1							; Save pointer for progress bar updates

	rts									; Return controll to loader

Load_BCB_Message
	.sb 'Loading bcbs.asm                 '

.endp
	ini Load_BCB

	org VBXE_WINDOW + $500				; Load data directly into VBXE RAM
BCB_START
	icl 'bcbs.asm'
BLT_Length	equ *-BCB_START

; Step $07 - Load VBXE Palette #1
	org LOAD_ADDRESS + $300
.proc Load_Palette
	lda	#MEMAC_GLOBAL_DISABLE			; USE CPU address space
	vbsta VBXE_MA_BSEL

; Print Load_Palette_Message - line 3 (y = $79)
	ldy #$79
	ldx #$00
Print_Load_Palette_Message_L1
	lda Load_Palette_Message,x
	sta (Ptr_Lo),y
	inx
	iny
	cpx #$21							; Copy $21 characters
	bne Print_Load_Palette_Message_L1

; Update Progress bar - line 5 (y = $CB + (4 * increment #))
	ldy Reg1
	lda #$54							; Screen RAM code for Ctrl+T
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sty Reg1							; Save pointer for progress bar updates

	mwa #Palette Y_Register
	lda #$01							; Set Palette 1
	jsr VBXE_SetPalette2

	rts									; Return controll to loader

Load_Palette_Message
	.sb 'Loading Palette.pal             '
Palette
	ins 'Assets\Palette.pal'

.endp
	ini Load_Palette

; Step $08 - Load Ball Graphics into VBXE
	org LOAD_ADDRESS + $300
.proc Load_Ball
	lda	#$10 | MEMAC_GLOBAL_ENABLE		; Bank $10 VBXE Window Enabled
	vbsta VBXE_MA_BSEL

; Print Load_Ball_Message - line 3 (y = $79)
	ldy #$79
	ldx #$00
Print_Load_Ball_Message_L1
	lda Load_Ball_Message,x
	sta (Ptr_Lo),y
	inx
	iny
	cpx #$21							; Copy $21 characters
	bne Print_Load_Ball_Message_L1

; Update Progress bar - line 5 (y = $CB + (5 * increment #))
	ldy Reg1
	lda #$54							; Screen RAM code for Ctrl+T
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sty Reg1							; Save pointer for progress bar updates

	rts									; Return controll to loader

Load_Ball_Message
	.sb 'Loading Ball32.raw               '

.endp
	ini Load_Ball

	org VBXE_WINDOW						; Load data directly into VBXE RAM
Ball
	ins 'Assets\Ball32.raw'

; Step $09 - Load the background tiles into CPU RAM @ SCREEN_RAM
	org LOAD_ADDRESS + $300
.proc Load_Background

; Print Load_Background_Message - line 3 (y = $79)
	ldy #$79
	ldx #$00
Load_Background_Message_L1
	lda Load_Background_Message,x
	sta (Ptr_Lo),y
	inx
	iny
	cpx #$21							; Copy $21 characters
	bne Load_Background_Message_L1

; Update Progress bar - line 5 (y = $CB + (4 * increment #))
	ldy Reg1
	lda #$54							; Screen RAM code for Ctrl+T
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sty Reg1							; Save pointer for progress bar updates

	rts									; Return controll to loader

Load_Background_Message
	.sb 'Loading Fuji_Mono.raw           '

.endp
	ini Load_Background

	org SCREEN_RAM						; Load data directly into CPU RAM
FujiGraphics_Mono
	ins 'Assets\Fuji_Mono.raw'			; $520 bytes

; Step $0A - Display final message and wait for key
	org LOAD_ADDRESS + $300
.proc Wait_Key

; Print Load_Palette_Message - line 3 (y = $79)
	ldy #$79
	ldx #$00
Wait_Key_Message_L1
	lda Wait_Key_Message,x
	sta (Ptr_Lo),y
	inx
	iny
	cpx #$21							; Copy $21 characters
	bne Wait_Key_Message_L1

; Update Progress bar - line 5 (y = $CB + (5 * increment #))
	ldy Reg1
	lda #$54							; Screen RAM code for Ctrl+T
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sta (Ptr_Lo),y
	iny
	sty Reg1							; Save pointer for progress bar updates

Wait_For_Key_Exit
	lda #$FF
	sta CH								; Clear last key pressed
Wait_For_Key_Exit_L1
	lda CH
	cmp #$FF
	beq Wait_For_Key_Exit_L1			; Wait for Key Press

	lda #$FF
	sta CH								; Clear last key pressed

	rts									; Return controll to loader

Wait_Key_Message
	.sb 'Press any key to start the demo  '
.endp
	ini Load_Background
