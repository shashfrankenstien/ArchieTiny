import json
import os
# import shutil
root = os.path.dirname(__file__)



def parse_json(fpath):
    with open(fpath, 'r') as j:
        data = json.load(j)
    return data

def transpose(data):
    out = {}
    for key, lut in data['lut'].items():
        out[key] = []
        for c in range(data['width']):
            byte = 0
            for r in range(data['height']):
                byte |= (lut[(data['width'] * r) + c]) << r
            out[key].append(f"{int(byte):#04x}")

    data['lut'] = out
    return data


def to_asm(fpath, ascii_range=[0,256]):
    data = transpose(parse_json(fpath))

    build_dir = os.path.join(root, 'build')
    if not os.path.isdir(build_dir):
        os.makedirs(build_dir)

    out_file = [
        "; This file contains " + data['name'] + " font lookup table (font_lut)\n\n",
        f".equ\tICON_WIDTH,   \t\t{data['width']}\t\t\t; number of bytes per character",
        f".equ\tICON_LUT_SIZE,\t\t{ascii_range[1]-ascii_range[0]}\t\t\t; max supported ascii value\n\n\n",
        f"icon_lut:"
    ]

    for i in range(ascii_range[0], ascii_range[1]):
        ch = data['lut'].get(str(i))
        if not ch:
            ch = [0]*data['height']
        out_file.append('\t.byte ' + ', '.join(ch) + f'\t\t; {str(i)}')

    out_file.append("\n.balign 2")

    with open(os.path.join(build_dir, data['name'] + ".asm"), 'w') as f:
        f.write('\n'.join(out_file) + "\n")



def test(bdf_filepath, test_list):
    data = parse_json(bdf_filepath)

    for c in test_list:
        a = data['lut'].get(str(c))
        # print(a)
        if a:
            # a = _transpose_bits(a)
            for i in range(0, len(a), data['width']):
                b = a[i:i+data['width']]
                for bit in b:
                    bit = f'{chr(9608)}{chr(9608)}{chr(9608)}' if bit == 1 else '   '
                    print(bit, end = '', flush=True)
                print()
        print()

# =-=--=-=-=-=-=-=--=-=-=-=-=---==-=--=-=-=-=-=-=--=-=-=-=-=---=

if __name__ == '__main__':
    rng = [0, 9]
    input_fname = "archie_icons.json"

    to_asm(os.path.join(root, input_fname), rng)

    test(os.path.join(root, input_fname), range(rng[-1]))
