extends RefCounted
## The language the player reads. Every word the game shows is written in English, in the data
## files and in the scripts. A translation is a catalog keyed by that exact English text: the
## files under data/lang/<code>/ (data/lang/zh/cases/juno.json translates data/cases/juno.json,
## data/lang/zh/ui.json the words in the scripts). Text is translated where it is drawn
## (scripts/ui/gfx.gd) or, for words with numbers filled into them, where they are filled
## (fill, tf), so the rules, the data and the logs stay in English whatever the player reads.
##
## Both languages change together: tools/check_lang.py fails when an English line has no
## translation, when a translation's English is no longer in the game, or when a line and its
## translation disagree about their numbers ({name} and %d). A changed English line is a new key,
## so its old translation shows up as stale until it is brought up to date.
##
## The choice is kept in user://settings.cfg. Tests pin a language so a saved choice never
## reaches them.
## Used as: const Lang = preload("res://scripts/core/lang.gd")

const SETTINGS := "user://settings.cfg"
const CATALOGS := "res://data/lang"
const CODES := ["en", "zh"]
# each language by its own name, never translated: the switch on the title card shows these
const NAMES := {"en": "English", "zh": "中文"}
# how much one character says, against English: a line of Chinese is about half as many
# characters as the English it translates, so typewriters type it at half the rate and a page
# of it is held twice as long per character
const PER_CHAR := {"en": 1.0, "zh": 2.0}

static var code: String = "en"
static var record: bool = false          # tests: note English that reached the screen untranslated
static var misses: Dictionary = {}       # English text drawn untranslated -> times
static var errors: PackedStringArray = PackedStringArray()   # catalog problems, for the title card
static var topic_keys: Dictionary = {}   # topic id -> words the scripted patient listens for

static var _strings: Dictionary = {}     # English -> this language
static var _values: Dictionary = {}      # the translations themselves: already translated, not a miss
static var _keep: Dictionary = {}        # Latin words a translation keeps as they are (names, models, keys)
static var _pinned: bool = false
static var _word: RegEx = null


## The text in the player's language: the catalog's line for exactly this English, or the
## English itself when there is none (a name, a number, or a line that is not translated yet).
static func t(s: String) -> String:
	if code == "en" or s == "":
		return s
	var hit: Variant = _strings.get(s)
	if hit != null:
		return str(hit)
	if record:
		_note_miss(s)
	return s


## A format line in the player's language, with its values put in: tf("%d left", [n]).
## A translation keeps the English line's %-codes in the same order (tools/check_lang.py).
static func tf(fmt: String, values: Variant) -> String:
	return t(fmt) % values


## Puts values into authored words: every "{key}" in the translated s becomes values[key]. A
## value that is a string is translated too (a part's words); numbers are written as they are.
static func fill(s: String, values: Dictionary) -> String:
	var out := t(s)
	for key in values:
		var v: Variant = values[key]
		out = out.replace("{%s}" % str(key), t(str(v)) if typeof(v) == TYPE_STRING else str(v))
	return out


## Switches language and loads its catalog. An unknown code is English.
static func use(p_code: String) -> void:
	code = p_code if CODES.has(p_code) else "en"
	_load(code)


## Tests and captures: this language, whatever was saved or asked for on the command line.
static func pin(p_code: String) -> void:
	_pinned = true
	use(p_code)


## The saved choice, or --lang=<code> on the command line, which wins; English when neither.
## Does nothing once a language is pinned.
static func load_saved() -> void:
	if _pinned:
		return
	var said := asked("")
	if said != "":
		use(said)
		return
	var cfg := ConfigFile.new()
	var saved := "en"
	if cfg.load(SETTINGS) == OK:
		saved = str(cfg.get_value("game", "language", "en"))
	use(saved)


## --lang=<code> from the command line, or fallback when there is none.
static func asked(fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--lang="):
			return str(arg).substr(7)
	return fallback


## Keeps the choice for the next start. Not while pinned: a test never changes a player's choice.
static func save() -> void:
	if _pinned:
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)      # anything else in there is kept; a missing file is a fresh one
	cfg.set_value("game", "language", code)
	cfg.save(SETTINGS)


## See PER_CHAR: 1.0 for English.
static func per_char() -> float:
	return float(PER_CHAR.get(code, 1.0))


## The next language in CODES: what the switch offers.
static func other() -> String:
	return CODES[(CODES.find(code) + 1) % CODES.size()]


static func is_cjk(c: int) -> bool:
	return (c >= 0x2E80 and c <= 0x9FFF) or (c >= 0xF900 and c <= 0xFAFF) or (c >= 0xFF00 and c <= 0xFFEF)


## Whether s has any Chinese in it (hanzi, CJK punctuation, full-width forms).
static func has_cjk(s: String) -> bool:
	for i in s.length():
		if is_cjk(s.unicode_at(i)):
			return true
	return false


## Sorted, for a test to print: [[text, times], ...].
static func miss_list() -> Array:
	var out: Array = []
	for k in misses:
		out.append([k, misses[k]])
	out.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
	return out


# ------------------------------------------------------------------ the catalogs
static func _load(p_code: String) -> void:
	_strings = {}
	_values = {}
	_keep = {}
	topic_keys = {}
	errors = PackedStringArray()
	if p_code == "en":
		return
	var root := "%s/%s" % [CATALOGS, p_code]
	if not DirAccess.dir_exists_absolute(root):
		errors.append("data/lang/%s is missing." % p_code)
		return
	for path in _files(root):
		_read(path)


static func _files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(d)))
	return out


static func _read(path: String) -> void:
	var name := path.trim_prefix(CATALOGS + "/")
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		errors.append("%s is not valid JSON." % name)
		return
	var data: Dictionary = json.data
	var strings: Variant = data.get("strings", {})
	if typeof(strings) == TYPE_DICTIONARY:
		for k in strings:
			var v := str(strings[k])
			if v != "":
				_strings[str(k)] = v
				_values[v] = true
	for w in data.get("keep", []):
		_keep[str(w).to_lower()] = true
	var topics: Variant = data.get("topics", {})
	if typeof(topics) == TYPE_DICTIONARY:
		for id in topics:
			var list: Array = topic_keys.get(str(id), [])
			for w in topics[id]:
				list.append(str(w))
			topic_keys[str(id)] = list


## English that reached the screen with no translation: anything with a Latin word in it that is
## not a translation already, has no Chinese in it, and is not a word translations keep.
static func _note_miss(s: String) -> void:
	if _values.has(s) or has_cjk(s):
		return
	if _word == null:
		_word = RegEx.create_from_string("[A-Za-z][A-Za-z'-]+")
	for m in _word.search_all(s):
		if not _keep.has(m.get_string().to_lower().rstrip("-'")):
			misses[s] = int(misses.get(s, 0)) + 1
			return
