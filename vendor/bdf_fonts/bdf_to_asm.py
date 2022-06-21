from collections import OrderedDict, namedtuple
from pathlib import Path
# import argparse
import os
import shutil
root = os.path.dirname(__file__)


SUPPORTED_PIXEL_SIZE = 8

ParsedBDFFont = namedtuple('BDFFont', ['name','bbx','data','lut'])

def _conv_hex(hex_str):
    d = ("0x"+str(hex_str))
    return int(d, 16)


def _parse_bbx(bbx_str):
    key, val = bbx_str.split(' ', 1)
    val = [v.strip() for v in val.split()]
    return {
        'WIDTH': int(val[0]),
        'HEIGHT': int(val[1]),
        'X-OFFSET': int(val[2]),
        'Y-OFFSET': int(val[3]),
    }


def _parse_bdf_props(data):
    data_delim = data.index('BITMAP')
    out = {}
    for elem in data[:data_delim]:
        key, val = elem.split(' ', 1)
        if key == 'STARTCHAR':
            val = val.strip()
        elif key == 'ENCODING':
            val = int(val.strip())
        else:
            val = [v.strip() for v in val.split()]

        if key=='BBX':
           val = _parse_bbx(elem)

        elif key.endswith("WIDTH"):
            val = {
                'X': int(val[0]),
                'Y': int(val[1]),
            }

        out[key.strip()] = val
    try:
        out['DECODED'] = chr(out['ENCODING'])
    except:
        out['DECODED'] = ''
    out['BYTES'] = [_conv_hex(c) for c in data[data_delim+1:data.index('ENDCHAR')]]
    return out


def _transform_bdf_props(data, font_bbx):
    '''apply BBX to BYTES'''
    # print(font_bbx)
    # print(data)
    bbx = data['BBX']

    x_prefix_count = bbx['X-OFFSET'] - font_bbx['X-OFFSET']
    if x_prefix_count > 0:
        data_bytes = []
        for b in data['BYTES']:
            data_bytes.append(b>>x_prefix_count)
        data['BYTES'] = data_bytes

    y_suffix_count = bbx['Y-OFFSET'] - font_bbx['Y-OFFSET']
    y_prefix_count =  font_bbx['HEIGHT'] - (bbx['HEIGHT'] + y_suffix_count)
    if y_prefix_count > 0:
        data['BYTES'] = ([0] * y_prefix_count) + data['BYTES'] + ([0] * y_suffix_count)
    # print(data)
    # print()
    return data


def parse_bdf(fpath):
    font_name = Path(fpath).stem
    rows = []
    font_bbx = None
    font_lut = OrderedDict({})

    with open(fpath, 'r') as f:
        missing_rows = 0
        while missing_rows < 10:
            l = f.readline().strip()
            if not l:
                missing_rows += 1
            else:
                missing_rows = 0

            if l.startswith("FAMILY_NAME"):
                font_name = l.split(' ', maxsplit=1)[-1].strip().strip('"').lower()

            elif l.startswith('ADD_STYLE_NAME'):
                style = l.split(' ', maxsplit=1)[-1].strip().strip('"').lower()
                if style:
                    font_name += "-" + style

            elif l.startswith("FONTBOUNDINGBOX"):
                font_bbx = _parse_bbx(l)
                if font_bbx['HEIGHT'] > SUPPORTED_PIXEL_SIZE:
                    raise Exception(f"font size not supported - {font_bbx}")

            elif l.startswith("STARTCHAR") and font_bbx is None:
                raise Exception("could not find font bounding box")

            elif l.startswith("STARTCHAR"):
                line = [l]
                while not l.startswith("ENDCHAR"):
                    l = f.readline().strip()
                    line.append(l)
                if line:
                    parsed = _parse_bdf_props(line)
                    parsed = _transform_bdf_props(parsed, font_bbx)
                    rows.append(parsed)
                    font_lut[parsed['ENCODING']] = parsed['BYTES']
    return ParsedBDFFont(
        name = font_name,
        bbx = font_bbx,
        data = rows,
        lut = font_lut
    )



def _transpose_bits(byte_list, font_bbx):
    uniform_fill = lambda b: f'{b:b}'.zfill(8)[:font_bbx['WIDTH']]

    byte_strs = [uniform_fill(b) for b in byte_list]
    transposed = []
    for i in range(font_bbx['WIDTH']):
        new_byte = ''
        for b in byte_strs:
            new_byte = b[i] + new_byte
        transposed.append(int("0b" + new_byte, 2))
    return transposed



def to_asm(fpath, ascii_range=[0,256]):
    font = parse_bdf(fpath)
    print(font.name, font.bbx)

    build_dir = os.path.join(root, 'build')
    if not os.path.isdir(build_dir):
        os.makedirs(build_dir)

    out = [
        "; This file contains " + font.name + " font lookup table (font_lut)\n\n",
        f".equ\tFONT_WIDTH,   \t\t{font.bbx['WIDTH']}\t\t\t; number of bytes per character",
        f".equ\tFONT_OFFSET,  \t\t{ascii_range[0]}\t\t\t; subtract this number from ascii value",
        f".equ\tFONT_LUT_SIZE,\t\t{ascii_range[1]-ascii_range[0]}\t\t\t; max supported ascii value\n\n\n",
        f"font_lut:"
    ]

    for i in range(ascii_range[0], ascii_range[1]):
        ch = font.lut.get(i)
        if not ch:
            ch = [0]*font.bbx['HEIGHT']
        ch = [f"{c:#04x}" for c in _transpose_bits(ch, font.bbx)]
        out.append('\t.byte ' + ', '.join(ch) + f'\t\t; {str(i)} ({chr(i)})')

    with open(os.path.join(build_dir, font.name + ".asm"), 'w') as f:
        f.write('\n'.join(out) + "\n")



def test(bdf_filepath, test_string):
    font = parse_bdf(bdf_filepath)
    for c in test_string:
        a = font.lut.get(ord(c))
        print(a)
        import pdb; pdb.set_trace()
        if a:
            # a = _transpose_bits(a)
            for i in range(len(a)):
                b = a[i]
                bin_str = f'{b:b}'.zfill(8)[:font.bbx['WIDTH']]
                for bit in bin_str:
                    bit = 'X' if bit == '1' else ' '
                    print(bit, end = ' ', flush=True)
                print()
        print()


# =-=--=-=-=-=-=-=--=-=-=-=-=---==-=--=-=-=-=-=-=--=-=-=-=-=---=
def generate_all_asm_fonts():
    build_dir = os.path.join(root, 'build')
    if os.path.isdir(build_dir):
        shutil.rmtree(build_dir)

    bdf_filepaths = [
        'bitocra7.bdf',
        "spleen.bdf",
        "miniwi.bdf",
        "unscii-8-fantasy.bdf",
        "omelette.bdf",
        # "omelette-icons.bdf",
    ]
    for f in bdf_filepaths:
        to_asm(os.path.join(root, f), ascii_range=[32, 127])

    # to_asm(os.path.join(root, "omelette-windows.bdf"), ascii_range=[65, 88])


# =-=--=-=-=-=-=-=--=-=-=-=-=---==-=--=-=-=-=-=-=--=-=-=-=-=---=



# =-=--=-=-=-=-=-=--=-=-=-=-=---==-=--=-=-=-=-=-=--=-=-=-=-=---=

if __name__ == '__main__':
    generate_all_asm_fonts()

    # b = [1,1]
    # b = [
    #     0x60,
    #     0x90,
    #     0xF0,
    #     0x80,
    #     0x70,
    # ]
    # for byt in b:
    #     print(f'{byt:b}'.zfill(8))
    # print(_transpose_bits(b))

    # ch = [f"{c:#04x}" for c in _transpose_bits(b)]
    # for c in ch:
    #     print(f'{int(c, 16):b}'.zfill(8))
    # print(ch)

    # test(os.path.join(root, "creep.bdf"), "Hello World asjydh []")
    # test(os.path.join(root, "scientifica.bdf"), "Hello World asjydh []")
    # test(os.path.join(root, "unscii-8-alt.bdf"), "Hello World asjydh []")
    # test(os.path.join(root, "unscii-8-thin.bdf"), "Hello World asjydh []")
    # test(os.path.join(root, "unscii-8-fantasy.bdf"), "Hello World asjydh []")

    t = ''.join([chr(i) for i in range(33, 127)])
    print(t)
    test(os.path.join(root, "omelette-icons.bdf"), t)
