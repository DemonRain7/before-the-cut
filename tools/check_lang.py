"""Keeps every translation in step with the English game.

Run from the repository root:  python tools/check_lang.py
                               python tools/check_lang.py --todo zh   (what still needs words, file by file)

Every word the game shows is written in English: in game/data (the shown parts of each file,
listed in SHOWN below) and in the scripts. A translation is a set of catalogs under
game/data/lang/<code>/, keyed by that exact English (scripts/core/lang.gd). A catalog has the
path of the data file it translates (lang/zh/cases/kip.json translates cases/kip.json);
lang/<code>/ui.json translates the words in the scripts and lang/<code>/topics.json holds the
words the offline patient listens for in every case.

It fails when, in any language:
- a line the player can see has no translation (missing). A line whose only words are ones a
  translation keeps as they are (names, code names, model tags, key names: each catalog's
  "keep" list) needs none, and so does a line whose only words are its {slots} or %-codes;
- a catalog line's English is no longer in the file it translates (stale): the English was
  changed, so the old translation is out of date and must be written again;
- one English line has two different translations (conflict);
- a line and its translation do not carry the same {name} slots, or the same %-codes in the
  same order (Lang.tf puts the values in by position);
- a translation is empty, or no different from the English;
- a "topics" entry names a topic no case has;
- a picture with words painted into it (tools/art/words.py PICTURES) has no twin in the
  language, <name>_<code>.png, or words.py has no words for the language.

A change to the English is a change to every language: when this fails after an English edit,
write the new line's translation in the same change.

What it cannot see: words the scripts put together while the game runs, a single lowercase word
in a script (it reads like an id; mark its line's comment [shown] when it is words for the
player), and a line whose only words are single letters ("L: {l}. R: {r}."). The smoke test run
in a language (--lang=<code>) lists whatever English still reached the screen.
"""
import glob
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, "game")
DATA = os.path.join(GAME, "data")
LANG = os.path.join(DATA, "lang")
SCRIPTS = os.path.join(GAME, "scripts")
ART = os.path.join(ROOT, "tools", "art")

# What the player reads in each data file, as JSON paths: "*" is any one key or list index.
# Everything else (ids, numbers, the patient model's brief, the offline patient's key words,
# the notes to authors) is never shown and stays English.
_PART_TEXT = ("tag", "both", "fine", "one", "fine_one", "normal")
SHOWN = {
    # a character (version 3): what every night shares, then each sign a night can draw
    # (signs.<row>.<normal|broken>[i]) and the endings for either truth
    "cases/*.json": [
        ("name",), ("role",), ("request",), ("teaser",), ("opening", "*"),
        ("looks", "*"), ("claims", "*", "line"), ("claims", "*", "note"),
        ("topics", "*", "q"), ("topics", "*", "deflect"),
        ("lines", "*"), ("lines", "*", "*"), ("press_end", "*"),
        ("attack", "telegraph"), ("attack", "line"), ("exit", "*"),
    ] + [("signs", "*", "*", "*", key) for key in ("text", "note", "look", "after")]
      + [("signs", "*", "*", "*", "answers", "*", key) for key in ("a", "note")]
      + [("signs", "*", "*", "*", part, key) for part in ("press", "flare") for key in ("line", "note")]
      + [("outcomes", "*", "*", key) for key in ("title", "text")],
    # a contact's alias is a code name: the same in every language (drawn with Gfx.text_raw).
    # Since contacts.json version 2 the codes are a list of their own, drawn onto tonight's entries
    "contacts.json": [
        ("title",), ("clues", "*", "text"),
        ("codes", "*", "say"), ("codes", "*", "answer"), ("pool", "*", "package"),
    ],
    "intro.json": [
        ("cards", "*", "title"), ("cards", "*", "text"),
        ("cards", "*", "labels", "*"), ("cards", "*", "labels", "*", "*"),
        ("cards", "*", "labels", "entries", "*", "clues", "*"),
        ("cards", "*", "labels", "entries", "*", "code"),
        ("guide", "*", "title"), ("guide", "*", "items", "*", "text"), ("guide", "*", "closing"),
        ("training", "*", "text"),
    ],
    "parts.json": [(group, "*", key) for group in ("eyes", "hands", "ports", "voices") for key in _PART_TEXT]
                  + [("eyes_mixed", "*")],
    "rules.json": [("titles", "*", "title"), ("titles", "*", "text"), ("line_text", "*"),
                   ("counter", "*", "title"), ("counter", "*", "text")],
    "sheet.json": [
        ("title",), ("title_none",), ("rows", "*", "label"), ("rows", "*", "normal"), ("rows", "*", "ordinary"),
        ("footer", "*"),
    ],
}

# Scripts whose words never reach the player: data checks for authors (case_db), the catalog
# loader, the wire to the proxy, the sound file writer, the event log, the move check and the
# drawing helpers.
NOT_SHOWN_SCRIPTS = {"core/case_db.gd", "core/lang.gd", "core/model_client.gd", "core/voice_clip.gd",
                     "core/event_log.gd", "core/move_validator.gd", "ui/gfx.gd"}

WORD = re.compile(r"[A-Za-z][A-Za-z'-]+")          # the same as Lang._note_miss
SHOWN_MARK = "[shown]"      # in a script line's comment: its lowercase literals are words for the player
SLOT = re.compile(r"\{(\w+)\}")
PCT = re.compile(r"%(?:%|[-+ 0#]*\d*(?:\.\d+)?[sdifxXc])")


# ------------------------------------------------------------------ the English
def _walk(value, path=()):
    if isinstance(value, str):
        yield path, value
    elif isinstance(value, dict):
        for k, v in value.items():
            yield from _walk(v, path + (k,))
    elif isinstance(value, list):
        for i, v in enumerate(value):
            yield from _walk(v, path + (i,))


def _matches(path, pattern):
    return len(path) == len(pattern) and all(p == "*" or p == str(k) for k, p in zip(path, pattern))


def data_files():
    """data/<rel> for every data file a catalog can translate, as (rel, path)."""
    out = []
    for path in sorted(glob.glob(os.path.join(DATA, "**", "*.json"), recursive=True)):
        rel = os.path.relpath(path, DATA).replace("\\", "/")
        if not rel.startswith("lang/"):
            out.append((rel, path))
    return out


def shown_in(rel, data):
    """The shown strings of one data file, in file order, as (json path, text)."""
    patterns = []
    for key, pats in SHOWN.items():
        if key == rel or (key.endswith("*.json") and rel.startswith(key[:-6]) and "/" not in rel[len(key) - 6:]):
            patterns = pats
    out = []
    for path, text in _walk(data):
        if text.strip() and any(_matches(path, p) for p in patterns):
            out.append((".".join(str(k) for k in path), text))
    return out


def _decode(raw):
    """A GDScript string literal's text."""
    out, i = [], 0
    simple = {"n": "\n", "t": "\t", "r": "\r", '"': '"', "'": "'", "\\": "\\", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}
    while i < len(raw):
        c = raw[i]
        if c == "\\" and i + 1 < len(raw):
            e = raw[i + 1]
            if e in simple:
                out.append(simple[e])
                i += 2
                continue
            if e == "u":
                out.append(chr(int(raw[i + 2:i + 6], 16)))
                i += 6
                continue
            if e == "U":
                out.append(chr(int(raw[i + 2:i + 8], 16)))
                i += 8
                continue
        out.append(c)
        i += 1
    return "".join(out)


def literals(src):
    """Every string literal of a GDScript source: (line, text, the code on its line, is_key, kind).
    kind is "" for a plain string, "&" or "^" for a StringName or NodePath, "long" for a triple-quoted one."""
    out = []
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c == "#":
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if c in "\"'":
            prefix = src[i - 1] if i > 0 and src[i - 1] in "&^r" else ""
            triple = src.startswith(c * 3, i)
            q = c * 3 if triple else c
            j = i + len(q)
            start = line
            while j < n and not src.startswith(q, j):
                if src[j] == "\\" and prefix != "r":
                    j += 2
                    continue
                if src[j] == "\n":
                    line += 1
                j += 1
            raw = src[i + len(q):j]
            end = j + len(q)
            is_key = re.match(r"\s*:(?!=)", src[end:end + 3]) is not None
            text = raw if prefix == "r" else _decode(raw)
            row = src.rfind("\n", 0, i) + 1
            row_end = src.find("\n", end)
            out.append((start, text, src[row:row_end if row_end >= 0 else n], is_key, "long" if triple else prefix.strip("r")))
            i = end
            continue
        i += 1
    return out


def _looks_shown(text, code, is_key, kind):
    """A literal that reads like words for the player rather than a key, a path or a message for
    the log. Errs on the side of words: check_lang lists anything it is unsure of as missing."""
    if kind or is_key or not WORD.search(text):
        return False
    if re.fullmatch(r"[a-z0-9_:./%@=+-]+", text) and SHOWN_MARK not in code:
        return False       # a key, an id or an event name ("check:penlight"), unless its line says [shown]
    if re.fullmatch(r"[A-Z0-9_]*_[A-Z0-9_]*", text):
        return False       # an environment variable or a constant's name
    if re.search(r"res://|user://|https?://|\.(png|json|wav|cfg|fnt|ogg|gd|tscn|mjs)\b", text):
        return False
    if re.search(r"\b(push_error|push_warning|printerr|prints?|printt|print_debug|assert)\(", code):
        return False
    return True


def script_words():
    """(every literal of every script, the ones that read as shown words: [(rel, line, text)])."""
    every, shown = set(), []
    for path in sorted(glob.glob(os.path.join(SCRIPTS, "**", "*.gd"), recursive=True)):
        rel = os.path.relpath(path, SCRIPTS).replace("\\", "/")
        for line, text, code, is_key, kind in literals(io.open(path, encoding="utf-8").read()):
            every.add(text)
            if rel not in NOT_SHOWN_SCRIPTS and _looks_shown(text, code, is_key, kind):
                shown.append((rel, line, text))
    return every, shown


# ------------------------------------------------------------------ the catalogs
def catalogs(code):
    """rel -> (path, data) for every catalog of one language."""
    root = os.path.join(LANG, code)
    out = {}
    for path in sorted(glob.glob(os.path.join(root, "**", "*.json"), recursive=True)):
        rel = os.path.relpath(path, root).replace("\\", "/")
        out[rel] = (path, json.load(io.open(path, encoding="utf-8")))
    return out


def needs_words(text, keep):
    """Whether a line has a word a translation does not keep as it is. The game fills in {slots}
    and %-codes, so they are not words; a word's trailing hyphen is not part of it ("VX-9")."""
    bare = PCT.sub(" ", SLOT.sub(" ", text))
    return any(w.lower().rstrip("-'") not in keep for w in WORD.findall(bare))


def check(code, todo=False):
    problems = []
    cats = catalogs(code)
    if not cats:
        return ["data/lang/%s has no catalogs" % code]
    keep, strings, where = set(), {}, {}
    for rel, (path, cat) in cats.items():
        for k in ("note", "strings"):
            if k not in cat:
                problems.append("lang/%s/%s: no \"%s\"" % (code, rel, k))
        for w in cat.get("keep", []):
            keep.add(str(w).lower())
        for en, tr in cat.get("strings", {}).items():
            if en in strings and strings[en] != tr:
                problems.append("CONFLICT %r: %r in %s, %r in %s" % (en, strings[en], where[en], tr, rel))
            strings[en] = tr
            where[en] = rel
    # what the game shows, file by file
    shown = []          # (catalog rel, where, text)
    sources = {}        # catalog rel -> the English it may translate
    for rel, path in data_files():
        data = json.load(io.open(path, encoding="utf-8"))
        rows = shown_in(rel, data)
        sources[rel] = {t for _p, t in rows}
        shown += [(rel, "data/%s %s" % (rel, p), t) for p, t in rows]
    every, words = script_words()
    sources["ui.json"] = every
    shown += [("ui.json", "scripts/%s:%d" % (rel, line), t) for rel, line, t in words]
    # missing
    todo_by = {}
    seen = set()
    for rel, at, text in shown:
        if text in strings or not needs_words(text, keep) or text in seen:
            continue
        seen.add(text)
        problems.append("MISSING (%s) %s: %r" % (code, at, text))
        todo_by.setdefault(rel, []).append(text)
    # every catalog line
    case_topics = set()
    for rel, path in data_files():
        if rel.startswith("cases/"):
            c = json.load(io.open(path, encoding="utf-8"))
            for t in c.get("topics", []):
                case_topics.add(str(t.get("id", "")))
                case_topics.add("%s:%s" % (c.get("id", ""), t.get("id", "")))
    for rel, (path, cat) in cats.items():
        own = sources.get(rel)
        for en, tr in cat.get("strings", {}).items():
            tag = "lang/%s/%s %r" % (code, rel, en)
            if own is None:
                problems.append("STALE %s: lang/%s/%s translates no file of the game" % (tag, code, rel))
            elif en not in own:
                problems.append("STALE %s: this English is no longer in %s" % (tag, "the scripts" if rel == "ui.json" else "data/" + rel))
            if not isinstance(tr, str) or not tr.strip():
                problems.append("EMPTY %s" % tag)
                continue
            if tr == en and needs_words(en, keep):
                problems.append("UNTRANSLATED %s: the same as the English" % tag)
            if sorted(set(SLOT.findall(en))) != sorted(set(SLOT.findall(tr))):
                problems.append("SLOTS %s: %s in English, %s in the translation" % (tag, sorted(set(SLOT.findall(en))), sorted(set(SLOT.findall(tr)))))
            if PCT.findall(en) != PCT.findall(tr):
                problems.append("CODES %s: %s in English, %s in the translation" % (tag, PCT.findall(en), PCT.findall(tr)))
        for topic, words in cat.get("topics", {}).items():
            if topic not in case_topics:
                problems.append("TOPIC lang/%s/%s %r: no case has this topic" % (code, rel, topic))
            if not isinstance(words, list) or not all(isinstance(w, str) and w.strip() for w in words):
                problems.append("TOPIC lang/%s/%s %r: needs a list of words" % (code, rel, topic))
    if todo:
        for rel, texts in todo_by.items():
            print("== lang/%s/%s (%d)" % (code, rel, len(texts)))
            for t in texts:
                print("\t\t%s: \"\"," % json.dumps(t, ensure_ascii=False))
    return problems


def pictures(code):
    """The pictures with words in them, painted in this language too (tools/art/words.py)."""
    sys.path.insert(0, ART)
    import words
    problems = []
    for key, by_lang in words.WORDS.items():
        if code not in by_lang:
            problems.append("PICTURE tools/art/words.py %r: no words in %s" % (key, code))
    for rel in words.PICTURES:
        tw = words.twin(rel, code)
        if not os.path.isfile(os.path.join(GAME, "assets", *tw.split("/"))):
            problems.append("PICTURE %s: no %s (run its generator in tools/art)" % (rel, tw))
    return problems


def main():
    args = sys.argv[1:]
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if args[:1] == ["--todo"]:
        check(args[1] if len(args) > 1 else "zh", todo=True)
        return 0
    codes = sorted(d for d in os.listdir(LANG) if os.path.isdir(os.path.join(LANG, d)))
    bad = []
    for code in codes:
        bad += check(code)
        bad += pictures(code)
    for p in bad:
        print(p)
    print("%s: %d problems" % (", ".join(codes) or "no languages", len(bad)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
