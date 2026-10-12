extends Node
## Multi-slot JSON saves. Slot 0 = autosave, slots 1-3 = manual. Writes are atomic (temp file + rename).

const DIR := "user://saves"
const SLOTS := 3

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

func path(slot: int) -> String: return "%s/slot_%d.json" % [DIR, slot]

func save(slot: int) -> bool:
	if not GameManager.in_game: return false
	var s = GameManager.s
	var payload := {"version": GameManager.SAVE_VERSION, "time": TimeManager.total_minutes, "saved_at": Time.get_datetime_string_from_system(),
		"meta": {"name": s.name, "day": TimeManager.get_day(), "money": s.money, "age": TimeManager.get_age()}, "state": s}
	var tmp := path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(payload))
	f.close()
	if FileAccess.file_exists(path(slot)): DirAccess.remove_absolute(path(slot))
	return DirAccess.rename_absolute(tmp, path(slot)) == OK

func autosave() -> void:
	if AudioManager.settings.autosave and GameManager.in_game and save(0):
		GameManager.notify("Autosaved.")

func _read(slot: int) -> Dictionary:
	if not FileAccess.file_exists(path(slot)): return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func load_slot(slot: int) -> bool:
	var p := _read(slot)
	if p.is_empty():
		GameManager.notify("Save file is missing or corrupted.")
		return false
	return GameManager.load_state(p)

func meta(slot: int) -> Dictionary:
	var p := _read(slot)
	if p.is_empty(): return {}
	var m: Dictionary = p.get("meta", {})
	m["saved_at"] = p.get("saved_at", "")
	return m

func delete_slot(slot: int) -> void:
	if FileAccess.file_exists(path(slot)): DirAccess.remove_absolute(path(slot))

func latest_slot() -> int:
	var best := -1
	var best_t := ""
	for i in range(0, SLOTS + 1):
		var m := meta(i)
		if not m.is_empty() and str(m.saved_at) > best_t:
			best_t = str(m.saved_at)
			best = i
	return best
