extends VBoxContainer
## Save/Load slot list. mode = "save" or "load".
const UIU = preload("res://scripts/ui/ui_util.gd")
var mode := "load"
signal loaded

func _ready() -> void:
	refresh()

func refresh() -> void:
	UIU.clear(self)
	add_child(UIU.label("Save slots" if mode == "save" else "Load game", 22, Color("#ffd166")))
	for slot in range(0 if mode == "load" else 1, SaveManager.SLOTS + 1):
		var m := SaveManager.meta(slot)
		var h := HBoxContainer.new()
		var title := "Autosave" if slot == 0 else "Slot %d" % slot
		var info := "(empty)" if m.is_empty() else "%s - Day %d, age %d, %s  [%s]" % [m.name, int(m.day), int(m.age), UIU.money(float(m.money)), str(m.saved_at).replace("T", " ")]
		var l := UIU.label("%s: %s" % [title, info])
		l.custom_minimum_size.x = 520
		h.add_child(l)
		var empty := m.is_empty()
		if mode == "save":
			var sb := UIU.button("Save", func():
				GameManager.notify("Game saved." if SaveManager.save(slot) else "Save failed!")
				refresh())
			h.add_child(sb)
		else:
			var lb := UIU.button("Load", func():
				if SaveManager.load_slot(slot): loaded.emit())
			lb.disabled = empty
			h.add_child(lb)
		var db := UIU.button("Delete", func():
			SaveManager.delete_slot(slot)
			refresh())
		db.disabled = empty
		h.add_child(db)
		add_child(h)
