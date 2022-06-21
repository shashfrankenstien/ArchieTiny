; This file contains archie_icons font lookup table (font_lut)


.equ	ICON_WIDTH,   		5			; number of bytes per character
.equ	ICON_LUT_SIZE,		7			; max supported value



.equ	ICON_IDX_TREE           , 0			; index of TREE in icon_lut
.equ	ICON_IDX_TERMINAL       , 1			; index of TERMINAL in icon_lut
.equ	ICON_IDX_FOLDER         , 2			; index of FOLDER in icon_lut
.equ	ICON_IDX_HOME           , 3			; index of HOME in icon_lut
.equ	ICON_IDX_LOCK           , 4			; index of LOCK in icon_lut
.equ	ICON_IDX_UNLOCK         , 5			; index of UNLOCK in icon_lut
.equ	ICON_IDX_FILE           , 6			; index of FILE in icon_lut



icon_lut:
	.byte 0xff, 0xff, 0x10, 0x10, 0x00		; 0
	.byte 0x7e, 0x6a, 0x76, 0x7e, 0x7e		; 1
	.byte 0x7e, 0x7e, 0x7c, 0x7c, 0x7c		; 2
	.byte 0x78, 0x6c, 0x3e, 0x3c, 0x78		; 3
	.byte 0x30, 0x7e, 0x72, 0x7e, 0x30		; 4
	.byte 0x30, 0x73, 0x71, 0x7f, 0x30		; 5
	.byte 0x7e, 0x42, 0x4e, 0x4c, 0x78		; 6

.balign 2
