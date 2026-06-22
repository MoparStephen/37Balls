XDL										; Graphics mode,SD resolution, 240 lines, start at $20000, $200 bytes/line
;		 76543210  76543210
	dta %01101010,%00001110				; XDLC (2 Bytes)
	dta $EE								; XDLC_RPTL (1 byte)
	dta $00,$00,$02,$00,$02				; XDLC_OVADR (5 bytes)
	dta $00,$00,$06,$40,$01				; XDLC_MAPADR (5 bytes)
	dta $00,$00,$1F,$00					; XDLC_MAPPAR (4 bytes)
	dta	%00010001,$FF					; XDLC_OVATT (2 bytes)
;		 76543210  76543210
	dta %00000000,%10000000				; XDLC (2 Bytes) - End of XDL, wait for VSYNC