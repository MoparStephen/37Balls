BLT_BALL
	dta $00,$00,$01						; Source address
	dta $20,$00							; Source step y
	dta $01								; Source step x
	dta $00,$00,$02						; Destination address
	dta $00,$02							; Destination step y
	dta $01								; Destination step x
	dta $1F,$00							; Width
	dta $1F								; Height
	dta $FF								; And mask
	dta $00								; Xor mask
	dta $00								; Collision and mask
	dta $00								; Zoom
	dta $00								; Pattern feature
	dta $01								; Control

BLT_BAKGRND
	dta $00,$00,$00						; Source address
	dta $00,$00							; Source step y
	dta $00								; Source step x
	dta $00,$00,$02						; Destination address
	dta $00,$02							; Destination step y
	dta $01								; Destination step x
	dta $27,$00							; Width
	dta $1d								; Height
	dta $00								; And mask (and mask equal to 0, memory will be filled with xor mask)
	dta $00								; Xor mask
	dta $00								; Collision and mask
	dta $77								; Zoom
	dta $00								; Patter feature
	dta $00								; Control

; Clear 496kB (leave bottom 16kB for the SVBXE.SYS driver)
; 496x16 zoom 8x8 clear blit (this takes 2 frames)
BLT_CLEAR
	dta $00,$00,$00						; Source address
	dta $00,$00							; Source step y
	dta $00								; Source step x
	dta $FF,$BF,$07						; Destination address
	dta a(-$0F80)						; Destination step y (backwards 3968 bytes) - NOTE: this equals 496 * zoom factor of 8
	dta -$01							; Destination step x (backwards	1 byte)
	dta $EF,$01							; Width-1  (495)	496 * 8 bytes wide
	dta $0F								; Height-1 (15)		 16 * 8 bytes high
	dta $00								; And mask (And mask equal to 0 so clear)
	dta $00								; Xor mask (will be filled with xor mask)
	dta $00								; Collision and mask
	dta $77								; Zoom (BLT_ZOOMY = 7, BLT_ZOOMX = 7 so 8Y*8X)
	dta $00								; Pattern feature
	dta $00								; Control (Mode 0 with NEXT bit Cleared)

; Fill the ColourMap area ($60000-$62580, 9600 bytes) with $50 every 4 bytes
; XDLC_MAPPAR Byte 4
; This sets up the Palette & Priority bytes for the entire Colour Map
; 10 cells/line (32-pixel cells) x 4 bytes/cell = $28 bytes/line, 240 lines
BLT_SETUP_CMAP_1
	dta $00,$00,$00						; Source address
	dta $00,$00							; Source step y
	dta $00								; Source step x
	dta $03,$00,$06						; Destination address ($60003)
	dta $28,$00							; Destination step y ($28 bytes/line)
	dta $04								; Destination step x
	dta $09,$00							; Width (9 = 10 cells/line, count-1)
	dta $EF								; Height ($F0)
	dta $00								; And mask
	dta $50								; Xor mask ($50 = PF & OVL Palette 1)
	dta $00								; Collision and mask
	dta $00								; Zoom
	dta $00								; Pattern feature
	dta $00								; Control

; Fill the ColourMap area with a single line ($28 bytes) of
; Local substitute of the COLPF1 register (GTIA)
; This BCB gets modified before each call
; Starting address increments by $28 each time
; Xor mask pulls values from the temp table at $0600
BLT_SETUP_CMAP_2
	dta $00,$00,$00						; Source address
	dta $00,$00							; Source step y
	dta $00								; Source step x
	dta $01,$00,$06						; Destination address ($60001)
	dta $28,$00							; Destination step y ($28 bytes/line)
	dta $04								; Destination step x
	dta $09,$00							; Width (9 = 10 cells/line, count-1)
	dta $00								; Height ($01)
	dta $00								; And mask
	dta $69								; Xor mask
	dta $00								; Collision and mask
	dta $00								; Zoom
	dta $00								; Pattern feature
	dta $00								; Control