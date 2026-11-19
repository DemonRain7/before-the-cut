"""Generate the bitmap fonts into game/assets/fonts."""
import os

from font_data import export_font, draw_text, text_width
import font_zh
from px import ASSETS, OUT, Canvas


def main():
    d = os.path.join(ASSETS, "fonts")
    n = export_font(d, "counter", bold=False, scale=1)
    export_font(d, "counter_bold", bold=True, scale=1)
    export_font(d, "counter_big", bold=True, scale=2)
    nz = font_zh.export_zh_font(d, "zh")
    # Each atlas is read by its .fnt, never shown as a picture of its own: Godot is told to skip
    # importing it as a texture, as it does for every font atlas here
    for name in ("counter", "counter_bold", "counter_big", "zh"):
        skip = os.path.join(d, name + ".png.import")
        if not os.path.exists(skip):
            with open(skip, "w", encoding="utf-8", newline="
") as f:
                f.write('[remap]

importer="skip"
')
    # review sheet
    c = Canvas(330, 120, "paper3")
    lines = [
        ("NORMAL REFERENCE SHEET", True),
        ("Pupils tighten in light. Both follow it.", False),
        ("Ordinary: implant eyes don't tighten.", False),
        ("Lets go on 'release', within a second.", False),
        ("ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789", False),
        ("abcdefghijklmnopqrstuvwxyz .,;:!?'\"-+=/()[]", False),
        ("The quick brown fox jumps over the lazy dog.", True),
        ("#$%&@*<>^~_|{} ✓ ✗ • ► ◄ … – ●●○ → 250 cr", False),
    ]
    y = 4
    for s, b in lines:
        draw_text(c, 4, y, s, "inkt", bold=b)
        y += 11
    draw_text(c, 4, y + 2, "BEFORE THE CUT", "red1", bold=True, scale=2)
    os.makedirs(OUT, exist_ok=True)
    c.scaled(3).image().convert("RGB").save(os.path.join(OUT, "font_preview.png"))
    print("font glyphs:", n, "width sample:", text_width("Pupils tighten in light. Both follow it."))
    # review sheet for the Chinese fallback, drawn on the game's 10-pixel line pitch
    z = Canvas(330, 96, "paper3")
    zl = [
        ("正常参照表：KIP MARLOW", True),
        ("光照下瞳孔收缩。双眼都跟着光走。", False),
        ("正常损耗：发抖、抽动、握力弱。", False),
        ("“它不怎么需要睡觉。我睡剩下的。”", False),
        ("两行异常＝失控：呼叫创伤小组。0.6s，LIMIT 1s。", False),
        ("凯斯勒、哈罗信贷、灯笼帮……（全角标点）！？", False),
    ]
    y = 4
    for s, b in zl:
        font_zh.draw_text(z, 4, y, s, "inkt", bold=b)
        y += 10
    font_zh.draw_text(z, 4, y + 4, "先别下刀 BEFORE THE CUT", "red1", bold=True, scale=2)
    z.scaled(3).image().convert("RGB").save(os.path.join(OUT, "font_zh_preview.png"))
    print("chinese glyphs:", nz)


if __name__ == "__main__":
    main()
