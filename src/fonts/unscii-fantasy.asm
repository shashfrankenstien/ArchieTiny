; This file contains unscii-fantasy font lookup table (font_lut)


.equ	FONT_WIDTH,   		7			; number of bytes per character
.equ	FONT_OFFSET,  		32			; subtract this number from ascii value
.equ	FONT_LUT_SIZE,		127			; max supported ascii value



font_lut:
	.byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00		; 32 ( )
	.byte 0x00, 0x00, 0x00, 0x5f, 0x5f, 0x00, 0x00		; 33 (!)
	.byte 0x00, 0x07, 0x07, 0x00, 0x00, 0x07, 0x07		; 34 (")
	.byte 0x14, 0x7f, 0x7f, 0x14, 0x7f, 0x7f, 0x14		; 35 (#)
	.byte 0x00, 0x24, 0x2e, 0x6b, 0x6b, 0x3a, 0x12		; 36 ($)
	.byte 0x46, 0x66, 0x30, 0x18, 0x0c, 0x66, 0x62		; 37 (%)
	.byte 0x30, 0x7a, 0x4f, 0x5d, 0x37, 0x7a, 0x48		; 38 (&)
	.byte 0x00, 0x00, 0x04, 0x07, 0x03, 0x00, 0x00		; 39 (')
	.byte 0x00, 0x00, 0x1c, 0x3e, 0x63, 0x41, 0x00		; 40 (()
	.byte 0x00, 0x00, 0x41, 0x63, 0x3e, 0x1c, 0x00		; 41 ())
	.byte 0x08, 0x2a, 0x3e, 0x1c, 0x1c, 0x3e, 0x2a		; 42 (*)
	.byte 0x00, 0x08, 0x08, 0x3e, 0x3e, 0x08, 0x08		; 43 (+)
	.byte 0x00, 0x00, 0x80, 0xe0, 0x60, 0x00, 0x00		; 44 (,)
	.byte 0x00, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08		; 45 (-)
	.byte 0x00, 0x00, 0x00, 0x60, 0x60, 0x00, 0x00		; 46 (.)
	.byte 0x40, 0x60, 0x30, 0x18, 0x0c, 0x06, 0x03		; 47 (/)
	.byte 0x3c, 0x7e, 0x63, 0x41, 0x63, 0x3f, 0x1e		; 48 (0)
	.byte 0x00, 0x00, 0x04, 0x3e, 0x7f, 0x00, 0x00		; 49 (1)
	.byte 0x66, 0x73, 0x51, 0x59, 0x4f, 0x6f, 0x26		; 50 (2)
	.byte 0x00, 0x22, 0x43, 0x49, 0x6d, 0x3f, 0x12		; 51 (3)
	.byte 0x0e, 0x1f, 0x08, 0x08, 0x7e, 0x3f, 0x08		; 52 (4)
	.byte 0x27, 0x77, 0x65, 0x45, 0x4d, 0x3d, 0x38		; 53 (5)
	.byte 0x00, 0x3c, 0x7e, 0x67, 0x45, 0x4d, 0x38		; 54 (6)
	.byte 0x02, 0x03, 0x6b, 0x79, 0x7d, 0x0f, 0x0b		; 55 (7)
	.byte 0x30, 0x7a, 0x4f, 0x4f, 0x79, 0x7f, 0x36		; 56 (8)
	.byte 0x00, 0x0e, 0x59, 0x51, 0x73, 0x3f, 0x1e		; 57 (9)
	.byte 0x00, 0x00, 0x00, 0x66, 0x66, 0x00, 0x00		; 58 (:)
	.byte 0x00, 0x00, 0x80, 0xe6, 0x66, 0x00, 0x00		; 59 (;)
	.byte 0x00, 0x08, 0x1c, 0x36, 0x63, 0x41, 0x00		; 60 (<)
	.byte 0x00, 0x14, 0x14, 0x14, 0x14, 0x14, 0x14		; 61 (=)
	.byte 0x00, 0x41, 0x63, 0x36, 0x1c, 0x08, 0x00		; 62 (>)
	.byte 0x00, 0x02, 0x03, 0x51, 0x59, 0x0f, 0x06		; 63 (?)
	.byte 0x3e, 0x7f, 0x41, 0x5d, 0x5d, 0x5f, 0x1e		; 64 (@)
	.byte 0x5c, 0x7e, 0x6a, 0x09, 0x7f, 0x7f, 0x41		; 65 (A)
	.byte 0x45, 0x7f, 0x7f, 0x45, 0x4f, 0x7a, 0x30		; 66 (B)
	.byte 0x3c, 0x7e, 0x63, 0x41, 0x43, 0x62, 0x20		; 67 (C)
	.byte 0x41, 0x7f, 0x7f, 0x43, 0x46, 0x7c, 0x38		; 68 (D)
	.byte 0x3c, 0x7e, 0x6b, 0x49, 0x43, 0x62, 0x20		; 69 (E)
	.byte 0x45, 0x7f, 0x3f, 0x09, 0x09, 0x03, 0x02		; 70 (F)
	.byte 0x1c, 0x3e, 0x63, 0x49, 0x7b, 0x7a, 0x08		; 71 (G)
	.byte 0x49, 0x7f, 0x7f, 0x08, 0x59, 0x7f, 0x7f		; 72 (H)
	.byte 0x00, 0x42, 0x42, 0x7f, 0x7f, 0x21, 0x21		; 73 (I)
	.byte 0x30, 0x72, 0x43, 0x41, 0x7f, 0x3f, 0x01		; 74 (J)
	.byte 0x45, 0x7f, 0x7f, 0x04, 0x3e, 0x7b, 0x41		; 75 (K)
	.byte 0x40, 0x71, 0x3f, 0x6e, 0x40, 0x40, 0x40		; 76 (L)
	.byte 0x7e, 0x7f, 0x05, 0x0c, 0x46, 0x7f, 0x3f		; 77 (M)
	.byte 0x41, 0x7f, 0x3f, 0x06, 0x4c, 0x7f, 0x3f		; 78 (N)
	.byte 0x3c, 0x7e, 0x63, 0x41, 0x63, 0x3e, 0x1c		; 79 (O)
	.byte 0x41, 0x7f, 0x3e, 0x09, 0x0d, 0x07, 0x02		; 80 (P)
	.byte 0x3c, 0x7e, 0x63, 0x41, 0x33, 0x6e, 0x5c		; 81 (Q)
	.byte 0x41, 0x7f, 0x3e, 0x09, 0x3d, 0x77, 0x42		; 82 (R)
	.byte 0x20, 0x64, 0x4e, 0x4b, 0x49, 0x7b, 0x32		; 83 (S)
	.byte 0x02, 0x07, 0x71, 0x7f, 0x0f, 0x01, 0x01		; 84 (T)
	.byte 0x39, 0x7f, 0x67, 0x40, 0x41, 0x7f, 0x3f		; 85 (U)
	.byte 0x19, 0x3f, 0x67, 0x60, 0x31, 0x1f, 0x0f		; 86 (V)
	.byte 0x7e, 0x7f, 0x31, 0x18, 0x30, 0x7e, 0x3f		; 87 (W)
	.byte 0x41, 0x73, 0x3e, 0x1c, 0x3e, 0x67, 0x41		; 88 (X)
	.byte 0x26, 0x6f, 0x49, 0x68, 0x3e, 0x1f, 0x01		; 89 (Y)
	.byte 0x75, 0x7d, 0x59, 0x4d, 0x5f, 0x16, 0x00		; 90 (Z)
	.byte 0x00, 0x00, 0x7f, 0x7f, 0x41, 0x41, 0x00		; 91 ([)
	.byte 0x01, 0x03, 0x06, 0x0c, 0x18, 0x30, 0x60		; 92 (\)
	.byte 0x00, 0x00, 0x41, 0x41, 0x7f, 0x7f, 0x00		; 93 (])
	.byte 0x08, 0x0c, 0x06, 0x03, 0x06, 0x0c, 0x08		; 94 (^)
	.byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80		; 95 (_)
	.byte 0x00, 0x00, 0x00, 0x01, 0x03, 0x06, 0x04		; 96 (`)
	.byte 0x00, 0x38, 0x7c, 0x44, 0x3c, 0x7c, 0x40		; 97 (a)
	.byte 0x00, 0x40, 0x7f, 0x3f, 0x44, 0x7c, 0x38		; 98 (b)
	.byte 0x00, 0x78, 0x7c, 0x44, 0x44, 0x6c, 0x68		; 99 (c)
	.byte 0x00, 0x38, 0x7c, 0x45, 0x7f, 0x7e, 0x40		; 100 (d)
	.byte 0x00, 0x78, 0x7c, 0x54, 0x54, 0x5c, 0x1c		; 101 (e)
	.byte 0x00, 0x48, 0x7e, 0x3f, 0x09, 0x0b, 0x0a		; 102 (f)
	.byte 0x00, 0xb8, 0xbc, 0xa4, 0xa4, 0xfc, 0x7c		; 103 (g)
	.byte 0x00, 0x7f, 0x7f, 0x08, 0x38, 0x70, 0x40		; 104 (h)
	.byte 0x00, 0x00, 0x00, 0x3a, 0x7a, 0x40, 0x00		; 105 (i)
	.byte 0x00, 0x80, 0x80, 0x80, 0xfa, 0x7a, 0x08		; 106 (j)
	.byte 0x00, 0x7f, 0x7f, 0x14, 0x3c, 0x6c, 0x40		; 107 (k)
	.byte 0x00, 0x00, 0x00, 0x3f, 0x7f, 0x40, 0x00		; 108 (l)
	.byte 0x78, 0x7c, 0x0c, 0x18, 0x08, 0x7c, 0x7c		; 109 (m)
	.byte 0x00, 0x7c, 0x7c, 0x04, 0x3c, 0x78, 0x40		; 110 (n)
	.byte 0x00, 0x78, 0x7c, 0x44, 0x44, 0x7c, 0x3c		; 111 (o)
	.byte 0x20, 0xf8, 0xfc, 0x24, 0x24, 0x3c, 0x1c		; 112 (p)
	.byte 0x00, 0x38, 0x3c, 0x24, 0x24, 0xfc, 0xfc		; 113 (q)
	.byte 0x00, 0x7c, 0x7c, 0x08, 0x04, 0x0c, 0x08		; 114 (r)
	.byte 0x00, 0x58, 0x5c, 0x54, 0x54, 0x74, 0x34		; 115 (s)
	.byte 0x00, 0x04, 0x04, 0x3f, 0x7e, 0x44, 0x04		; 116 (t)
	.byte 0x3c, 0x7c, 0x40, 0x40, 0x3c, 0x7c, 0x40		; 117 (u)
	.byte 0x7c, 0x7c, 0x40, 0x60, 0x3c, 0x1c, 0x04		; 118 (v)
	.byte 0x7c, 0x7c, 0x20, 0x30, 0x60, 0x7c, 0x3c		; 119 (w)
	.byte 0x00, 0x44, 0x6c, 0x38, 0x38, 0x6c, 0x44		; 120 (x)
	.byte 0x1c, 0x3c, 0xa0, 0xa0, 0xfc, 0x7c, 0x04		; 121 (y)
	.byte 0x00, 0x40, 0x64, 0x74, 0x5c, 0x4c, 0x04		; 122 (z)
	.byte 0x00, 0x08, 0x08, 0x3e, 0x77, 0x41, 0x41		; 123 ({)
	.byte 0x00, 0x00, 0x00, 0x7f, 0x7f, 0x00, 0x00		; 124 (|)
	.byte 0x00, 0x41, 0x41, 0x77, 0x3e, 0x08, 0x08		; 125 (})
	.byte 0x02, 0x03, 0x01, 0x03, 0x02, 0x03, 0x01		; 126 (~)
