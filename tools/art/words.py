"""The words painted into the game's pictures, in every language the game speaks.

The game translates the words it draws (scripts/core/lang.gd), but words inside a picture are
pixels: a picture with words in it is painted once per language, <name>.png in English and
beside it <name>_<code>.png (clinic/shutter_zh.png), which the game shows in that language
(gfx.gd tex()). The generators take those words from here, so a word is changed in every
language at once, and tools/check_lang.py fails when a twin is missing.

A painted word names the thing the player sees, the way the counter guide names it: the
reference sheet's header reads NORMAL in English and 参照表 (reference sheet) in Chinese.
Chinese is drawn by font_zh.draw_label, which sets a hanzi's nine rows on the middle of a
capital's seven.
"""

LANGS = ("en", "zh")

WORDS = {
    # clinic/hall.png: the light over the hall door
    "exit": {"en": "EXIT", "zh": "出口"},
    # clinic/shutter.png: the stencil on the shutter
    "closed": {"en": "CLOSED", "zh": "停诊"},
    # clinic/booth.png: under the hall monitor on the left wall
    "hall_cam": {"en": "HALL CAM", "zh": "走廊监控"},
    # ui/obj_*.png: the things on the two pinboards
    "sheet": {"en": "NORMAL", "zh": "参照表"},
    "card": {"en": "INTAKE", "zh": "接诊卡"},
    "guide": {"en": ("COUNTER", "GUIDE"), "zh": ("柜台", "指南")},
    "list": {"en": "CONTACTS", "zh": "接头人"},
    # ui/ink_*.png: the imprints that land on the intake card
    "treat": {"en": "TREAT", "zh": "治疗"},
    "void": {"en": "VOID", "zh": "作废"},
    "team": {"en": ("TRAUMA", "TEAM"), "zh": ("创伤", "小组")},
}

# Every picture the game shows with words in it. Each has a twin for every language after the
# first; ui/logo.png's words are set in gen_ui.py logo() and logo_zh().
PICTURES = (
    "clinic/booth.png", "clinic/hall.png", "clinic/shutter.png",
    "ui/obj_sheet.png", "ui/obj_card.png", "ui/obj_guide.png", "ui/obj_list.png",
    "ui/ink_treat.png", "ui/ink_void.png", "ui/ink_refer.png", "ui/logo.png",
)


def say(key, lang):
    """The words for key in lang."""
    return WORDS[key][lang]


def twin(rel, lang):
    """Where the picture rel is written in lang: rel itself in English."""
    return rel if lang == LANGS[0] else rel[:-len(".png")] + "_" + lang + ".png"
