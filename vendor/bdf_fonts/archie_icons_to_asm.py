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


def to_asm(fpath):
    data = transpose(parse_json(fpath))

    build_dir = os.path.join(root, 'build')
    if not os.path.isdir(build_dir):
        os.makedirs(build_dir)

    out_file_header = [
        "; This file contains " + data['name'] + " font lookup table (font_lut)\n\n",
        f".equ\tICON_WIDTH,   \t\t{data['width']}\t\t\t; number of bytes per character",
        f".equ\tICON_LUT_SIZE,\t\t{len(data['lut'])}\t\t\t; max supported value\n\n\n",
    ]

    out_file_vars = [
    ]

    out_file_lut = [
        f"icon_lut:"
    ]

    for idx, (name, ch) in enumerate(data['lut'].items()):
        if not ch:
            ch = [0]*data['height']
        out_file_lut.append('\t.byte ' + ', '.join(ch) + f'\t\t; {str(idx)}')
        out_file_vars.append(f'.equ\tICON_IDX_{name:15}, {idx}\t\t\t; index of {name} in icon_lut')

    out_file_vars.append("\n\n")
    out_file_lut.append("\n.balign 2")

    with open(os.path.join(build_dir, data['name'] + ".asm"), 'w') as f:
        f.write('\n'.join(out_file_header + out_file_vars+ out_file_lut) + "\n")



def test(bdf_filepath):
    data = parse_json(bdf_filepath)

    for a in data['lut'].values():
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
    input_fname = "archie_icons.json"

    to_asm(os.path.join(root, input_fname))

    test(os.path.join(root, input_fname))
