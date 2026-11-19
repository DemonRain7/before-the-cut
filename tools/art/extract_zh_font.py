"""Cut the Chinese glyphs out of Fusion Pixel Font for the game's Chinese text.

Fusion Pixel Font (https://github.com/TakWolf/fusion-pixel-font) is by TakWolf and draws on Ark
Pixel Font, BoutiqueBitmap9x9 and Galmuri. It is licensed under the SIL Open Font License 1.1;
the licence texts are in fonts/OFL.txt and fonts/LICENSES/. The file in fonts/ was cut from
release 2026.11.10, archive fusion-pixel-font-10px-proportional-bdf-v2026.11.10.zip, file
fusion-pixel-10px-proportional-zh_hans.bdf.

To cut it again (another release, or more characters), unpack that archive anywhere and run,
from tools/art:

    python -I extract_zh_font.py <path to fusion-pixel-10px-proportional-zh_hans.bdf>

It writes fonts/fusion-pixel-10px-zh_hans.bdf: the font's own header and every glyph it has of
the CJK Unified Ideographs (and Extension A), of GB 2312 (its punctuation, symbols and
full-width forms), of General Punctuation, of CJK Symbols and Punctuation and of the full-width
forms. The patient model's replies and the player's own typing can use any common character, so
the cut keeps every ideograph the font draws (10,687 in release 2026.11.10; it does not draw 818
of GB 2312's rarer ones). gen_font.py builds the game's Chinese font (game/assets/fonts/zh.fnt)
from that file. Nothing in the glyphs is changed.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "fonts", "fusion-pixel-10px-zh_hans.bdf")
NOTDEF = 0xFFFE


def gb2312():
    """Every character GB 2312 encodes."""
    out = set()
    for hi in range(0xA1, 0xF8):
        for lo in range(0xA1, 0xFF):
            try:
                out.add(ord(bytes([hi, lo]).decode("gb2312")))
            except UnicodeDecodeError:
                pass
    return out


def wanted():
    codes = gb2312()
    codes |= set(range(0x4E00, 0xA000))     # CJK Unified Ideographs
    codes |= set(range(0x3400, 0x4DC0))     # CJK Unified Ideographs Extension A
    codes |= set(range(0x2000, 0x2070))     # General Punctuation: quotes, dashes, the ellipsis
    codes |= set(range(0x3000, 0x3040))     # CJK Symbols and Punctuation
    codes |= set(range(0xFF00, 0xFFF0))     # Halfwidth and Fullwidth Forms
    codes |= {0x00B7, 0x00D7, 0x00F7, NOTDEF}
    return codes


def main(src):
    keep = wanted()
    header, glyphs, block, code = [], [], [], None
    with open(src, encoding="utf-8") as f:
        for line in f:
            if not glyphs and not block and not line.startswith("STARTCHAR"):
                if line.startswith("CHARS "):
                    continue
                header.append(line)
                continue
            if line.startswith("STARTCHAR"):
                block, code = [line], None
                continue
            if line.startswith("ENDFONT"):
                break
            block.append(line)
            if line.startswith("ENCODING"):
                code = int(line.split()[1])
            if line.startswith("ENDCHAR"):
                if code in keep:
                    glyphs.append((code, block))
                block = []
    glyphs.sort(key=lambda g: g[0])
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    note = ("COMMENT Cut for Before the Cut by tools/art/extract_zh_font.py: CJK Unified Ideographs and\n"
            "COMMENT Extension A, GB 2312, General Punctuation, CJK Symbols and Punctuation, Halfwidth\n"
            "COMMENT and Fullwidth Forms. Glyphs unchanged.\n")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(header[0])
        f.write(note)
        f.writelines(header[1:])
        f.write("CHARS %d\n" % len(glyphs))
        for _, b in glyphs:
            f.writelines(b)
        f.write("ENDFONT\n")
    print("kept %d of the %d glyphs asked for; wrote %s" % (len(glyphs), len(keep), OUT))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
