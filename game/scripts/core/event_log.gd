extends RefCounted
## Writes one JSON object per line (JSONL) for every interaction.
## The log is how playtests and model runs get measured later. It holds no personal data:
## only a random session id, case ids, clicks, patient moves, timings and results.
## Files land in user://logs/ (on Windows: %APPDATA%\Godot\app_userdata\Before the Cut\logs).
## Used as: const EventLog = preload("res://scripts/core/event_log.gd")

var session_id: String = ""
var path: String = ""
var memory: Array = []   # the same records, kept in memory for tests and debugging
var _file: FileAccess = null


func open(p_session_id: String, dir: String = "user://logs") -> bool:
	session_id = p_session_id
	memory = []
	DirAccess.make_dir_recursive_absolute(dir)
	path = "%s/session_%s.jsonl" % [dir, session_id]
	_file = FileAccess.open(path, FileAccess.WRITE)
	return _file != null


func write(event_type: String, data: Dictionary = {}) -> void:
	var record := {
		"ts": Time.get_datetime_string_from_system(true),
		"ms": Time.get_ticks_msec(),
		"session": session_id,
		"type": event_type,
	}
	record.merge(data)
	memory.append(record)
	if _file != null:
		_file.store_line(JSON.stringify(record))
		_file.flush()


func stop() -> void:
	_file = null
