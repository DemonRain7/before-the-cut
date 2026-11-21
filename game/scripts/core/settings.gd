extends RefCounted
## The player's other choices, kept beside the language (lang.gd) in user://settings.cfg, in its
## [game] section: the blood, the sound and the screen. They are changed on the title card's
## SETTINGS page, and the screen with F11 as well. A test run pins its language (Lang.pin), and
## then nothing is read from the file or written to it: a test never sees, or changes, what a
## player chose.
## Used as: const Settings = preload("res://scripts/core/settings.gd")

const Lang = preload("res://scripts/core/lang.gd")

# volume: a step of AudioBank.VOLUME_STEPS, 0 (off) to 4 (full)
const DEFAULTS := {"blood": "full", "volume": 4, "screen": "window"}
const CHOICES := {"blood": ["full", "less"], "volume": [0, 1, 2, 3, 4], "screen": ["window", "fullscreen"]}


## What was saved, each value checked against CHOICES; the default wherever nothing usable was
## saved, and only the defaults on a test run.
static func load_all() -> Dictionary:
	var out := DEFAULTS.duplicate()
	if Lang.is_pinned():
		return out
	var cfg := ConfigFile.new()
	if cfg.load(Lang.SETTINGS) != OK:
		return out
	for key in DEFAULTS:
		var v: Variant = cfg.get_value("game", key, DEFAULTS[key])
		v = int(v) if typeof(DEFAULTS[key]) == TYPE_INT else str(v)
		if (CHOICES[key] as Array).has(v):
			out[key] = v
	return out


## Keeps one choice for the next start. Not on a test run.
static func save_value(key: String, value: Variant) -> void:
	if Lang.is_pinned() or not DEFAULTS.has(key):
		return
	var cfg := ConfigFile.new()
	cfg.load(Lang.SETTINGS)      # the language and anything else in there is kept; a missing file is a fresh one
	cfg.set_value("game", key, value)
	cfg.save(Lang.SETTINGS)
