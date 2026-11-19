#!/usr/bin/env python3
"""Rough static checks for the GDScript files of Before the Cut.

This is NOT a GDScript parser and it does not replace running Godot. It only catches the
mechanical mistakes that are easy to make when code is written without the engine at hand:

  - indentation that is not tabs
  - unbalanced brackets
  - block headers without a colon
  - ':=' on an expression whose type Godot cannot infer (dictionary reads, .get(), await ...)
  - calls to project functions with the wrong number of arguments
  - members used on project objects (visit., shift., agent., ...) that the script does not define
  - enum values that do not exist (Mode.X, Phase.X)
  - res:// paths that do not exist, and data files that are not valid JSON

Usage (from the repository root):   python tools/gd_static_check.py
Exit code 0 = nothing found, 1 = at least one finding.
"""

import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", "game"))

CORE = "scripts/core/"
UI = "scripts/ui/"

# Names that hold (or are) a project script. Checked wherever they appear as "name.member".
OBJECTS = {
    "CaseDB": CORE + "case_db.gd",
    "VisitState": CORE + "visit_state.gd",
    "ShiftState": CORE + "shift_state.gd",
    "ScriptedBrain": CORE + "scripted_brain.gd",
    "MoveValidator": CORE + "move_validator.gd",
    "PatientAgent": CORE + "patient_agent.gd",
    "ModelClient": CORE + "model_client.gd",
    "EventLog": CORE + "event_log.gd",
    "VoiceClip": CORE + "voice_clip.gd",
    "VoiceInput": CORE + "voice_input.gd",
    "MainScript": UI + "main.gd",
    "visit": CORE + "visit_state.gd",
    "shift": CORE + "shift_state.gd",
    "agent": CORE + "patient_agent.gd",
    "scripted": CORE + "scripted_brain.gd",
    "event_log": CORE + "event_log.gd",
    "model_client": CORE + "model_client.gd",
    "mic": CORE + "voice_input.gd",
}

# A chain that passes through one of these is a read of loaded JSON (rules.agent.timeout_ms),
# not a member of the script that happens to share the next name.
DATA_ROOTS = {"rules", "case_data", "data"}

# Extra names that only mean something inside one file.
OBJECTS_PER_FILE = {
    "tests/run_tests.gd": {
        "v": CORE + "visit_state.gd",
        "vv": CORE + "visit_state.gd",
        "fresh": CORE + "visit_state.gd",
        "dirty": CORE + "visit_state.gd",
        "again": CORE + "shift_state.gd",
        "brain": CORE + "scripted_brain.gd",
        "second": CORE + "scripted_brain.gd",
        "log_writer": CORE + "event_log.gd",
    },
    "tests/run_ui_smoke.gd": {
        "main": UI + "main.gd",
    },
    "scripts/ui/main.gd": {
        "coach": UI + "coach.gd",
        "clipboard": UI + "clipboard.gd",
        "guide": UI + "guide.gd",
        "desk": UI + "desk.gd",
    },
}

# Members every object has (from RefCounted / Node / Control), so they are never reported.
BUILTIN_MEMBERS = {
    "new", "duplicate", "free", "queue_free", "get", "set", "call", "has_method", "connect", "emit",
    "position", "size", "visible", "text", "name", "add_child", "get_tree", "get_viewport",
    "mouse_filter", "queue_redraw", "is_empty", "has", "keys", "append",
}

BLOCK_WORDS = ("if ", "elif ", "else", "for ", "while ", "match ", "func ", "static func ", "class ")

RISKY_INFER = [
    (re.compile(r"\.get\("), ".get() returns Variant"),
    (re.compile(r"\bawait\b"), "await returns Variant unless the callee is typed"),
    (re.compile(r"(?<![\w])load\("), "load() returns Resource"),
    (re.compile(r"\.call\("), ".call() returns Variant"),
    (re.compile(r"\.pop_(front|back)\("), "pop returns Variant"),
    (re.compile(r"\.instantiate\("), "instantiate() returns Node"),
    (re.compile(r"JSON\.parse_string\("), "parse_string returns Variant"),
    (re.compile(r"\b(min|max|abs|clamp|sign|snapped)\("), "returns Variant; use the typed variant (mini, maxf ...)"),
    (re.compile(r"\w\[[^\]]*\]\s*$"), "an index read returns Variant"),
]

findings = []


def report(path, line_no, message):
    findings.append("%s:%d: %s" % (path, line_no, message))


def blank_strings(text):
    """Same text with string contents and comments replaced by spaces (length and newlines kept)."""
    out = []
    i = 0
    n = len(text)
    quote = None
    while i < n:
        ch = text[i]
        if quote:
            if ch == "\\" and i + 1 < n and text[i + 1] != "\n":
                out.append("  ")
                i += 2
                continue
            if ch == quote:
                quote = None
                out.append(ch)
            elif ch == "\n":
                quote = None
                out.append(ch)
            else:
                out.append(" ")
            i += 1
            continue
        if ch in "\"'":
            quote = ch
            out.append(ch)
            i += 1
            continue
        if ch == "#":
            j = text.find("\n", i)
            if j < 0:
                j = n
            out.append(" " * (j - i))
            i = j
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def split_top_level(text):
    """Split on commas that are not inside brackets. Returns [] for an empty argument list."""
    parts = []
    depth = 0
    current = []
    for ch in text:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append("".join(current))
            current = []
        else:
            current.append(ch)
    tail = "".join(current)
    if tail.strip() != "" or parts:
        parts.append(tail)
    return [p for p in parts if p.strip() != ""]


def matching_paren(text, open_at):
    depth = 0
    for i in range(open_at, len(text)):
        ch = text[i]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                return i
    return -1


FUNC_RE = re.compile(r"^(\t*)(?:static\s+)?func\s+(\w+)\s*\((.*)\)\s*(?:->\s*[\w\.]+\s*)?:\s*$")
VAR_RE = re.compile(r"^(?:static\s+)?(?:var|const)\s+(\w+)")
SIGNAL_RE = re.compile(r"^signal\s+(\w+)")
ENUM_RE = re.compile(r"^enum\s+(\w+)\s*\{([^}]*)\}")


class Script:
    def __init__(self, rel):
        self.rel = rel
        self.path = os.path.join(GAME, rel)
        with open(self.path, "r", encoding="utf-8") as handle:
            self.text = handle.read()
        self.blank = blank_strings(self.text)
        self.lines = self.text.split("\n")
        self.blank_lines = self.blank.split("\n")
        self.funcs = {}      # name -> (min_args, max_args), top level only
        self.members = set()  # vars, consts, signals, enums, funcs
        self.enums = {}      # enum name -> set of values
        self._collect()

    def _logical_lines(self):
        """The lines with a signature that runs on over several lines (its parameter list
        broken after a comma) joined into one."""
        out = []
        held = ""
        for line in self.blank_lines:
            if held:
                held += " " + line.strip()
            elif re.match(r"^\t*(?:static\s+)?func\s", line):
                held = line
            else:
                out.append(line)
                continue
            if held.count("(") <= held.count(")"):
                out.append(held)
                held = ""
        if held:
            out.append(held)
        return out

    def _collect(self):
        for line in self._logical_lines():
            m = FUNC_RE.match(line)
            if m:
                if m.group(1) != "":
                    continue  # a method of an inner class
                params = split_top_level(m.group(3))
                required = len([p for p in params if "=" not in p])
                self.funcs[m.group(2)] = (required, len(params))
                self.members.add(m.group(2))
                continue
            for pattern in (VAR_RE, SIGNAL_RE):
                m2 = pattern.match(line)
                if m2:
                    self.members.add(m2.group(1))
            m3 = ENUM_RE.match(line)
            if m3:
                values = set()
                for chunk in m3.group(2).split(","):
                    value = chunk.split("=")[0].strip()
                    if value:
                        values.add(value)
                self.enums[m3.group(1)] = values
                self.members.add(m3.group(1))


def check_layout(script):
    depth = 0
    stack = []
    for index, line in enumerate(script.blank_lines):
        line_no = index + 1
        raw = script.lines[index]
        lead = raw[: len(raw) - len(raw.lstrip())]
        if raw.strip() != "" and lead.replace("\t", "") != "":
            report(script.rel, line_no, "indentation is not tabs only")
        start_depth = depth
        for ch in line:
            if ch in "([{":
                stack.append((ch, line_no))
                depth += 1
            elif ch in ")]}":
                if not stack:
                    report(script.rel, line_no, "closing '%s' without an opening bracket" % ch)
                    continue
                opener, _ = stack.pop()
                depth -= 1
                if "([{".index(opener) != ")]}".index(ch):
                    report(script.rel, line_no, "bracket mismatch: '%s' closed by '%s'" % (opener, ch))
        stripped = line.strip()
        if start_depth == 0 and depth == 0 and stripped.startswith(BLOCK_WORDS):
            if stripped.startswith("else") and not re.match(r"^else\s*:", stripped):
                if not stripped.startswith("else:"):
                    pass
            if not stripped.endswith(":") and not re.search(r":\s*\S", stripped):
                report(script.rel, line_no, "block header without ':'")
    for opener, line_no in stack:
        report(script.rel, line_no, "'%s' is never closed" % opener)


# Calls that give a typed value whatever goes into them.
TYPED_CALLS = {
    "str", "int", "float", "bool", "String", "StringName", "Vector2", "Vector2i", "Rect2", "Rect2i", "Color",
    "Array", "Dictionary", "PackedStringArray", "PackedByteArray", "PackedVector2Array", "PackedInt32Array",
    "PackedFloat32Array", "absf", "absi", "minf", "mini", "maxf", "maxi", "clampf", "clampi", "roundi", "floori",
    "ceili", "snappedf", "snappedi", "lerpf", "signf", "signi", "is_equal_approx", "is_zero_approx", "len",
}
COMPARE_RE = re.compile(r"==|!=|<=|>=|<|>|\band\b|\bor\b|\bin\b|\bis\b")


def top_level(expr):
    """The expression with everything inside brackets blanked out (same length)."""
    out = []
    depth = 0
    for ch in expr:
        if ch in "([{":
            depth += 1
            out.append(" ")
        elif ch in ")]}":
            depth -= 1
            out.append(" ")
        else:
            out.append(ch if depth == 0 else " ")
    return "".join(out)


def shallow(expr):
    """The expression with the contents of its brackets blanked out: what is read inside a call's
    arguments does not decide the type of the call."""
    out = []
    depth = 0
    for ch in expr:
        if ch in ")]}":
            depth -= 1
        out.append(ch if depth == 0 else " ")
        if ch in "([{":
            depth += 1
    return "".join(out)


def typed_expression(expr):
    """True when Godot can infer the type although the expression reads something untyped."""
    expr = expr.strip()
    if expr == "":
        return False
    if expr.startswith(("\"", "'")):
        return True                      # a string, formatted or not
    flat = top_level(expr)
    if re.search(r"\bas\s+[\w\.]+\s*$", flat):
        return True                      # "... as Type"
    if expr.startswith("not ") or COMPARE_RE.search(flat):
        return True                      # a comparison or a boolean expression
    if expr.startswith("-"):
        return typed_expression(expr[1:])
    pieces = []
    start = 0
    for index, ch in enumerate(flat):
        if ch in "+-*/%":
            pieces.append(expr[start:index])
            start = index + 1
    if pieces:
        pieces.append(expr[start:])
        return all(typed_expression(piece) for piece in pieces)   # arithmetic: every operand typed
    m = re.match(r"^([A-Za-z_]\w*)\s*\(", expr)
    if m and matching_paren(expr, m.end() - 1) == len(expr) - 1:
        return m.group(1) in TYPED_CALLS
    if expr.startswith("(") and matching_paren(expr, 0) == len(expr) - 1:
        return typed_expression(expr[1:-1])
    return bool(re.match(r"^\d[\d\.]*$", expr))   # a number


def check_inference(script):
    pattern = re.compile(r"^\t*var\s+(\w+)\s*:=\s*(.+?)\s*$")
    for index, line in enumerate(script.blank_lines):
        m = pattern.match(line)
        if not m:
            continue
        expr = m.group(2)
        if expr.startswith(("[", "{")):
            continue  # a literal
        if typed_expression(expr):
            continue
        indexed = re.match(r"^(\w+)\[[^\]]*\]$", expr)
        if indexed and re.search(r"\b%s\s*:\s*(Packed\w+Array|Array\[|String\b)" % re.escape(indexed.group(1)), script.blank):
            continue  # an element of a typed array, or a character of a string
        flat = shallow(expr)
        for risky, why in RISKY_INFER:
            if risky.search(flat):
                report(script.rel, index + 1, "':=' on '%s': %s" % (m.group(1), why))
                break


CHAIN_RE = re.compile(r"(?<![\w\.])[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)+")
CALL_RE = re.compile(r"(?<![\w])((?:[A-Za-z_]\w*\.)*)([A-Za-z_]\w*)\s*\(")


def line_of(text, offset):
    return text.count("\n", 0, offset) + 1


def check_members_and_calls(script, scripts):
    objects = dict(OBJECTS)
    objects.update(OBJECTS_PER_FILE.get(script.rel, {}))
    blank = script.blank

    all_enums = {}
    for other in scripts.values():
        for enum_name, values in other.enums.items():
            all_enums[enum_name] = values

    for m in CHAIN_RE.finditer(blank):
        parts = m.group(0).split(".")
        line_no = line_of(blank, m.start())
        for i in range(len(parts) - 1):
            owner, member = parts[i], parts[i + 1]
            if DATA_ROOTS.intersection(parts[:i]):
                break  # a key of loaded JSON, not a member
            if owner in all_enums:
                if member not in all_enums[owner] and member not in ("keys", "values", "size", "has", "find_key"):
                    report(script.rel, line_no, "enum %s has no value '%s'" % (owner, member))
                continue
            target_rel = objects.get(owner)
            if target_rel is None or target_rel not in scripts:
                continue
            target = scripts[target_rel]
            if member in target.members or member in BUILTIN_MEMBERS:
                continue
            report(script.rel, line_no, "'%s.%s': %s does not define '%s'" % (owner, member, target_rel, member))

    for m in CALL_RE.finditer(blank):
        prefix, name = m.group(1), m.group(2)
        line_start = blank.rfind("\n", 0, m.start()) + 1
        before = blank[line_start:m.start()]
        if re.search(r"\bfunc\s+$", before):
            continue  # the definition itself
        open_at = m.end() - 1
        close_at = matching_paren(blank, open_at)
        if close_at < 0:
            continue
        count = len(split_top_level(blank[open_at + 1:close_at]))
        line_no = line_of(blank, m.start())
        target = None
        func_name = name
        if prefix == "":
            if name in script.funcs:
                target = script
        else:
            owner = prefix.rstrip(".").split(".")[-1]
            target_rel = objects.get(owner)
            if target_rel in scripts:
                target = scripts[target_rel]
                if name == "new":
                    func_name = "_init"
        if target is None or func_name not in target.funcs:
            continue
        low, high = target.funcs[func_name]
        if count < low or count > high:
            wanted = str(low) if low == high else "%d to %d" % (low, high)
            report(script.rel, line_no, "%s%s() called with %d argument(s), expects %s" % (prefix, name, count, wanted))


def check_resources():
    pattern = re.compile(r"res://[\w\./-]+")
    files = glob.glob(os.path.join(GAME, "**", "*.gd"), recursive=True)
    files += glob.glob(os.path.join(GAME, "**", "*.tscn"), recursive=True)
    files.append(os.path.join(GAME, "project.godot"))
    for path in files:
        rel = os.path.relpath(path, GAME).replace("\\", "/")
        with open(path, "r", encoding="utf-8") as handle:
            for index, line in enumerate(handle.read().split("\n")):
                for ref in pattern.findall(line):
                    if "/../" in ref or ref.startswith("res://.."):
                        continue  # a folder outside the project, made when it is needed
                    target = os.path.join(GAME, ref[len("res://"):])
                    if ref.endswith("/"):
                        if not os.path.isdir(target):
                            report(rel, index + 1, "folder %s does not exist" % ref)
                    elif not os.path.exists(target):
                        report(rel, index + 1, "file %s does not exist" % ref)
    for path in glob.glob(os.path.join(GAME, "data", "**", "*.json"), recursive=True):
        rel = os.path.relpath(path, GAME).replace("\\", "/")
        try:
            with open(path, "r", encoding="utf-8") as handle:
                json.load(handle)
        except ValueError as err:
            report(rel, 1, "not valid JSON: %s" % err)


def main():
    rels = []
    for path in glob.glob(os.path.join(GAME, "**", "*.gd"), recursive=True):
        rels.append(os.path.relpath(path, GAME).replace("\\", "/"))
    rels.sort()
    scripts = {rel: Script(rel) for rel in rels}
    for script in scripts.values():
        check_layout(script)
        check_inference(script)
        check_members_and_calls(script, scripts)
    check_resources()
    print("gd_static_check: %d script(s) checked" % len(scripts))
    if findings:
        for item in findings:
            print("  " + item)
        print("FINDINGS: %d (review each one; this tool can be wrong)" % len(findings))
        return 1
    print("No findings. This is a rough lint, not proof that the game runs.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
