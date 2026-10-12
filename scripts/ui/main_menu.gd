extends Control
## Main menu + character creator.
const UIU = preload("res://scripts/ui/ui_util.gd")
const CharDraw = preload("res://scripts/ui/char_draw.gd")
const SavePanel = preload("res://scripts/ui/save_panel.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
var box: VBoxContainer
var look := {"gender": "Female", "skin": 1, "hair": 0, "hair_color": 1, "top": 0, "shoes": 0, "acc": 0}
var pname := "Alex"
var bg := "average"
var preview: Control

func _ready() -> void:
	var bgc := ColorRect.new()
	bgc.color = Color("#1c2438")
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bgc)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	box = VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	c.add_child(box)
	_main()

func _main() -> void:
	UIU.clear(box)
	box.add_child(UIU.label("LIFE: NEW BEGINNINGS", 44, Color("#ffd166")))
	box.add_child(UIU.label("Start with almost nothing. Build any life you want.", 16, Color(1, 1, 1, 0.7)))
	box.add_child(UIU.button("New Game", func(): _creator()))
	var latest := SaveManager.latest_slot()
	var cont := UIU.button("Continue", func(): _load(latest))
	cont.disabled = latest < 0
	box.add_child(cont)
	box.add_child(UIU.button("Load Game", func(): _sub(SavePanel, "load")))
	box.add_child(UIU.button("Settings", func(): _sub(SettingsPanel, "")))
	box.add_child(UIU.button("Quit", func(): get_tree().quit()))

func _load(slot: int) -> void:
	if SaveManager.load_slot(slot): get_tree().change_scene_to_file("res://scenes/world/world.tscn")

func _sub(script: Script, mode: String) -> void:
	UIU.clear(box)
	var p = script.new()
	if mode != "": p.mode = mode
	if p.has_signal("loaded"): p.loaded.connect(func(): get_tree().change_scene_to_file("res://scenes/world/world.tscn"))
	box.add_child(p)
	box.add_child(UIU.button("Back", func(): _main()))

func _opt(label: String, items: Array, key: String, is_str := false) -> void:
	var h := HBoxContainer.new()
	var l := UIU.label(label); l.custom_minimum_size.x = 120
	h.add_child(l)
	var o := OptionButton.new()
	for i in items.size(): o.add_item(str(items[i]), i)
	o.selected = items.find(look[key]) if is_str else int(look[key])
	o.item_selected.connect(func(i):
		look[key] = items[i] if is_str else i
		preview.queue_redraw())
	h.add_child(o)
	box.add_child(h)

func _creator() -> void:
	UIU.clear(box)
	box.add_child(UIU.label("Create your character", 28, Color("#ffd166")))
	var nh := HBoxContainer.new()
	nh.add_child(UIU.label("Name  "))
	var le := LineEdit.new(); le.text = pname; le.custom_minimum_size.x = 240
	le.text_changed.connect(func(t): pname = t)
	nh.add_child(le)
	box.add_child(nh)
	preview = Control.new()
	preview.custom_minimum_size = Vector2(120, 110)
	preview.draw.connect(func():
		preview.draw_rect(Rect2(Vector2.ZERO, preview.size), Color(0, 0, 0, 0.3))
		preview.draw_set_transform(preview.size / 2.0 + Vector2(0, 5), 0.0, Vector2.ONE)
		CharDraw.paint(preview, look, 0.0, 1.8))
	box.add_child(preview)
	_opt("Gender", ["Female", "Male", "Non-binary"], "gender", true)
	_opt("Skin tone", ["1", "2", "3", "4", "5", "6"], "skin")
	_opt("Hair", CharDraw.HAIR_NAMES, "hair")
	_opt("Hair color", ["Black", "Brown", "Auburn", "Blonde", "Red", "Gray"], "hair_color")
	_opt("Clothing", ["Blue", "Red", "Green", "Yellow", "Purple", "Gray"], "top")
	_opt("Shoes", ["Black", "White", "Brown", "Red"], "shoes")
	_opt("Accessory", CharDraw.ACC_NAMES, "acc")
	var bh := HBoxContainer.new()
	bh.add_child(UIU.label("Background  "))
	var bo := OptionButton.new()
	var keys: Array = GameManager.BACKGROUNDS.keys()
	for i in keys.size(): bo.add_item(GameManager.BACKGROUNDS[keys[i]].name, i)
	bo.selected = keys.find(bg)
	var desc := UIU.label(GameManager.BACKGROUNDS[bg].desc, 14, Color(1, 1, 1, 0.75))
	bo.item_selected.connect(func(i):
		bg = keys[i]
		desc.text = "%s  Starting money: %s" % [GameManager.BACKGROUNDS[bg].desc, UIU.money(GameManager.BACKGROUNDS[bg].money)])
	bh.add_child(bo)
	box.add_child(bh)
	box.add_child(desc)
	box.add_child(UIU.button("Begin Life", func():
		GameManager.new_game(pname, bg, look.duplicate())
		get_tree().change_scene_to_file("res://scenes/world/world.tscn")))
	box.add_child(UIU.button("Back", func(): _main()))
