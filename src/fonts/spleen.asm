; This file contains spleen font lookup table (font_lut)


.equ	FONT_WIDTH,   		5			; number of bytes per character
.equ	FONT_OFFSET,  		32			; subtract this number from ascii value
.equ	FONT_LUT_SIZE,		127			; max supported ascii value



font_lut:
	.byte 0x00, 0x00, 0x00, 0x00, 0x00		; 32 ( )
	.byte 0x00, 0x00, 0x5f, 0x00, 0x00		; 33 (!)
	.byte 0x00, 0x07, 0x00, 0x07, 0x00		; 34 (")
	.byte 0x24, 0x7e, 0x24, 0x7e, 0x24		; 35 (#)
	.byte 0x44, 0x4a, 0xff, 0x32, 0x00		; 36 ($)
	.byte 0xc6, 0x30, 0x0c, 0x63, 0x00		; 37 (%)
	.byte 0x30, 0x4e, 0x59, 0x26, 0x40		; 38 (&)
	.byte 0x00, 0x00, 0x07, 0x00, 0x00		; 39 (')
	.byte 0x00, 0x3c, 0x42, 0x81, 0x00		; 40 (()
	.byte 0x00, 0x81, 0x42, 0x3c, 0x00		; 41 ())
	.byte 0x54, 0x38, 0x38, 0x54, 0x00		; 42 (*)
	.byte 0x10, 0x10, 0x7c, 0x10, 0x10		; 43 (+)
	.byte 0x00, 0x80, 0x60, 0x00, 0x00		; 44 (,)
	.byte 0x10, 0x10, 0x10, 0x10, 0x00		; 45 (-)
	.byte 0x00, 0x00, 0x40, 0x00, 0x00		; 46 (.)
	.byte 0xc0, 0x30, 0x0c, 0x03, 0x00		; 47 (/)
	.byte 0x3c, 0x52, 0x4a, 0x3c, 0x00		; 48 (0)
	.byte 0x00, 0x44, 0x7e, 0x40, 0x00		; 49 (1)
	.byte 0x64, 0x52, 0x52, 0x4c, 0x00		; 50 (2)
	.byte 0x24, 0x42, 0x4a, 0x34, 0x00		; 51 (3)
	.byte 0x1e, 0x10, 0x7c, 0x10, 0x00		; 52 (4)
	.byte 0x4e, 0x4a, 0x4a, 0x3a, 0x00		; 53 (5)
	.byte 0x3c, 0x4a, 0x4a, 0x30, 0x00		; 54 (6)
	.byte 0x06, 0x62, 0x1a, 0x06, 0x00		; 55 (7)
	.byte 0x34, 0x4a, 0x4a, 0x34, 0x00		; 56 (8)
	.byte 0x0c, 0x52, 0x52, 0x3c, 0x00		; 57 (9)
	.byte 0x00, 0x00, 0x48, 0x00, 0x00		; 58 (:)
	.byte 0x00, 0x80, 0x68, 0x00, 0x00		; 59 (;)
	.byte 0x00, 0x18, 0x24, 0x42, 0x00		; 60 (<)
	.byte 0x28, 0x28, 0x28, 0x28, 0x00		; 61 (=)
	.byte 0x00, 0x42, 0x24, 0x18, 0x00		; 62 (>)
	.byte 0x02, 0x51, 0x09, 0x06, 0x00		; 63 (?)
	.byte 0x3c, 0x42, 0x5a, 0x5c, 0x00		; 64 (@)
	.byte 0x7c, 0x12, 0x12, 0x7c, 0x00		; 65 (A)
	.byte 0x7e, 0x4a, 0x4a, 0x34, 0x00		; 66 (B)
	.byte 0x3c, 0x42, 0x42, 0x42, 0x00		; 67 (C)
	.byte 0x7e, 0x42, 0x42, 0x3c, 0x00		; 68 (D)
	.byte 0x3c, 0x4a, 0x4a, 0x42, 0x00		; 69 (E)
	.byte 0x7c, 0x12, 0x12, 0x02, 0x00		; 70 (F)
	.byte 0x3c, 0x42, 0x4a, 0x7a, 0x00		; 71 (G)
	.byte 0x7e, 0x08, 0x08, 0x7e, 0x00		; 72 (H)
	.byte 0x00, 0x42, 0x7e, 0x42, 0x00		; 73 (I)
	.byte 0x40, 0x42, 0x3e, 0x02, 0x00		; 74 (J)
	.byte 0x7e, 0x08, 0x08, 0x76, 0x00		; 75 (K)
	.byte 0x3e, 0x40, 0x40, 0x40, 0x00		; 76 (L)
	.byte 0x7e, 0x0c, 0x0c, 0x7e, 0x00		; 77 (M)
	.byte 0x7e, 0x0c, 0x30, 0x7e, 0x00		; 78 (N)
	.byte 0x3c, 0x42, 0x42, 0x3c, 0x00		; 79 (O)
	.byte 0x7e, 0x12, 0x12, 0x0c, 0x00		; 80 (P)
	.byte 0x3c, 0x42, 0xc2, 0xbc, 0x00		; 81 (Q)
	.byte 0x7e, 0x12, 0x12, 0x6c, 0x00		; 82 (R)
	.byte 0x44, 0x4a, 0x4a, 0x32, 0x00		; 83 (S)
	.byte 0x02, 0x02, 0x7e, 0x02, 0x02		; 84 (T)
	.byte 0x3e, 0x40, 0x40, 0x7e, 0x00		; 85 (U)
	.byte 0x1e, 0x60, 0x60, 0x1e, 0x00		; 86 (V)
	.byte 0x7e, 0x30, 0x30, 0x7e, 0x00		; 87 (W)
	.byte 0x66, 0x18, 0x18, 0x66, 0x00		; 88 (X)
	.byte 0x4e, 0x50, 0x50, 0x3e, 0x00		; 89 (Y)
	.byte 0x62, 0x52, 0x4a, 0x46, 0x00		; 90 (Z)
	.byte 0x00, 0xff, 0x81, 0x81, 0x00		; 91 ([)
	.byte 0x03, 0x0c, 0x30, 0xc0, 0x00		; 92 (\)
	.byte 0x00, 0x81, 0x81, 0xff, 0x00		; 93 (])
	.byte 0x08, 0x04, 0x02, 0x04, 0x08		; 94 (^)
	.byte 0x80, 0x80, 0x80, 0x80, 0x00		; 95 (_)
	.byte 0x00, 0x01, 0x02, 0x00, 0x00		; 96 (`)
	.byte 0x20, 0x54, 0x54, 0x78, 0x00		; 97 (a)
	.byte 0x7f, 0x44, 0x44, 0x38, 0x00		; 98 (b)
	.byte 0x38, 0x44, 0x44, 0x44, 0x00		; 99 (c)
	.byte 0x38, 0x44, 0x44, 0x7f, 0x00		; 100 (d)
	.byte 0x38, 0x54, 0x54, 0x5c, 0x00		; 101 (e)
	.byte 0x08, 0x7e, 0x09, 0x01, 0x00		; 102 (f)
	.byte 0x98, 0xa4, 0xa4, 0x5c, 0x00		; 103 (g)
	.byte 0x7f, 0x04, 0x04, 0x78, 0x00		; 104 (h)
	.byte 0x00, 0x00, 0x7a, 0x00, 0x00		; 105 (i)
	.byte 0x80, 0x80, 0x7a, 0x00, 0x00		; 106 (j)
	.byte 0x7f, 0x10, 0x28, 0x44, 0x00		; 107 (k)
	.byte 0x00, 0x3f, 0x40, 0x40, 0x00		; 108 (l)
	.byte 0x7c, 0x18, 0x18, 0x7c, 0x00		; 109 (m)
	.byte 0x7c, 0x04, 0x04, 0x78, 0x00		; 110 (n)
	.byte 0x38, 0x44, 0x44, 0x38, 0x00		; 111 (o)
	.byte 0xfc, 0x24, 0x24, 0x18, 0x00		; 112 (p)
	.byte 0x18, 0x24, 0x24, 0xfc, 0x00		; 113 (q)
	.byte 0x78, 0x04, 0x04, 0x0c, 0x00		; 114 (r)
	.byte 0x48, 0x54, 0x54, 0x24, 0x00		; 115 (s)
	.byte 0x04, 0x3f, 0x44, 0x40, 0x00		; 116 (t)
	.byte 0x3c, 0x40, 0x40, 0x7c, 0x00		; 117 (u)
	.byte 0x1c, 0x60, 0x60, 0x1c, 0x00		; 118 (v)
	.byte 0x7c, 0x30, 0x30, 0x7c, 0x00		; 119 (w)
	.byte 0x64, 0x18, 0x18, 0x64, 0x00		; 120 (x)
	.byte 0x9c, 0xa0, 0xa0, 0x7c, 0x00		; 121 (y)
	.byte 0x44, 0x64, 0x54, 0x4c, 0x00		; 122 (z)
	.byte 0x18, 0x7e, 0x81, 0x81, 0x00		; 123 ({)
	.byte 0x00, 0x00, 0x7e, 0x00, 0x00		; 124 (|)
	.byte 0x81, 0x81, 0x7e, 0x18, 0x00		; 125 (})
	.byte 0x04, 0x02, 0x04, 0x04, 0x02		; 126 (~)
