from collections import OrderedDict

def _yield_font_lines(fpath):
    with open(fpath, 'r') as f:
        missing_rows = 0
        while missing_rows < 10:
            l = f.readline().strip()
            if not l:
                missing_rows += 1
            else:
                missing_rows = 0
            if l.startswith("STARTCHAR"):
                line = [l]
                while not l.startswith("ENDCHAR"):
                    l = f.readline().strip()
                    line.append(l)
                if line:
                    yield line

def _conv_hex(hex_str):
    d = ("0x"+str(hex_str))
    return int(d, 16)

def _transpose_bits(byte_list):
    byte_strs = [f'{b:b}'.zfill(8) for b in byte_list]
    transposed = []
    for i in range(8):
        new_byte = ''
        for b in byte_strs:
            new_byte = b[i] + new_byte
        transposed.append(int("0b" + new_byte, 2))
    return transposed



def convert_to_bytes(fpath):
    out_dict = OrderedDict({})
    for char in _yield_font_lines(bdf_filepath):
        key = char[1].replace("ENCODING", "").strip()
        data = char[char.index('BITMAP')+1:char.index('ENDCHAR')]
        out_dict[key] = [_conv_hex(d) for d in data]
    return out_dict


def to_asm(fpath, font_name, height, out_width, ascii_range=[0,256]):
    out = [
        "; This file contains " + font_name + " font lookup table (font_lut)\n\n",
        f".equ\tFONT_WIDTH,\t\t\t{out_width}\t\t\t; number of bytes per character\n"
        f".equ\tFONT_OFFSET,\t\t{ascii_range[0]}\t\t\t; subtract this number from ascii value\n\n\n"
        f"font_lut:"
    ]

    font = convert_to_bytes(fpath)
    for i in range(ascii_range[0], ascii_range[1]):
        ch = font.get(str(i))
        if not ch:
            ch = [0]*height
        ch = [f"{c:#04x}" for c in _transpose_bits(ch)[:out_width]]
        out.append('\t.byte ' + ', '.join(ch) + f'\t\t; {str(i)} ({chr(i)})')

    with open("src/font_" + font_name + ".asm", 'w') as f:
        f.write('\n'.join(out))



def test(font, test_string):
    for c in test_string:
        a = font.get(str(ord(c)))
        if a:
            a = _transpose_bits(a)
            for i in range(len(a)-1):
                b = a[i]
                for bit in f'{b:b}'.zfill(8):
                    bit = 'X' if bit == '1' else ' '
                    print(bit, end = ' ', flush=True)
                print()
        print()


bdf_filepath = "vendor/bitmap_fonts/bitmap/spleen/spleen-5x8.bdf"
# bdf_filepath = "vendor/bitmap_fonts/bitmap/tamzen-font/bdf/Tamzen5x9r.bdf"
# bdf_filepath = "vendor/bitmap_fonts/bitmap/dina/Dina_r400-6.bdf"
# bdf_filepath = "vendor/bitmap_fonts/bitmap/cherry/cherry-10-b.bdf"
# bdf_filepath = "vendor/bitmap_fonts/bitmap/artwiz/bdf/edges.bdf"
# bdf_filepath = "vendor/bitmap_fonts/bitmap/leggie/leggie.bdf"
# bdf_filepath = "vendor/bitmap_fonts/bitmap/jmk-x11-fonts-3.0/modd-ascii-06x11.bdf"
# bdf_filepath = "vendor/bitmap_fonts/bitmap/phallus/lemon.bdf"


# bdf_filepath = 'vendor/bitmap_fonts/bitmap/bitocra/bitocra7.bdf'




to_asm(bdf_filepath, 'spleen', 8, 5, [32, 127])


font = convert_to_bytes(bdf_filepath)

# # for k, v in font.items():
# #     print(k, v, len(v))

test(font, "Hello World asjydh [")

