"""Generate the bitmap fonts into game/assets/fonts."""
import os

from font_data import export_font, draw_text, text_width
from px import ASSETS, OUT, Canvas


def main():
    d = os.path.join(ASSETS, "fonts")
    n = export_font(d, "counter", bold=False, scale=1)
    export_font(d, "counter_bold", bold=True, scale=1)
    export_font(d, "counter_big", bold=True, scale=2)
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


if __name__ == "__main__":
    main()
