; With Attribute Map (Colour Map enabled)
XDL_Attribute							; Graphics mode,SD resolution, 240 lines, start at $20000, $200 bytes/line
;		 76543210  76543210
	dta %01101010,%00001110				; XDLC (2 Bytes)
	dta $EE								; XDLC_RPTL (1 byte)
	dta $00,$00,$02,$00,$02				; XDLC_OVADR (5 bytes)
	dta $00,$00,$06,$28,$00				; XDLC_MAPADR (5 bytes)
	dta $00,$00,$1F,$00					; XDLC_MAPPAR (4 bytes)
	dta %00010001,$FF					; XDLC_OVATT (2 bytes)
;		 76543210  76543210
	dta %00000000,%10000000				; XDLC (2 Bytes) - End of XDL, wait for VSYNC

; Without Attribute Map (Colour Map disabled) - starts at offset $15 from XDL_Attribute
XDL_Normal								; Graphics mode,SD resolution, 240 lines, start at $20000, $200 bytes/line
;		 76543210
	dta %01110010						; XDLC Byte 1 $72 (XDLC_GMON | XDLC_MAPOFF | XDLC_RPTL | XDLC_OVADR)
	dta %00001000						; XDLC Byte 2 $08 (XDLC_ATT)
	dta $EE								; XDLC_RPTL (1 byte)
	dta $00,$00,$02,$00,$02				; XDLC_OVADR (5 bytes) - same Screen 1/2 addresses as XDL_Attribute
	dta %00010001,$FF					; XDLC_OVATT (2 bytes)
;		 76543210  76543210
	dta %00000000,%10000000				; XDLC (2 Bytes) - End of XDL, wait for VSYNC