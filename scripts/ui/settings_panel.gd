extends VBoxContainer
## Reusable settings form (main menu + pause menu).
const UIU = preload("res://scripts/ui/ui_util.gd")

func _ready() -> void:
	var s: Dictionary = AudioManager.settings
	for k in [["master", "Master volume"], ["music", "Music volume"], ["sfx", "Sound effects"]]:
		var key: String = k[0]
		var h := HBoxContainer.new()
		var l := UIU.label(k[1]); l.custom_minimum_size.x = 170
		var sl := HSlider.new()
		sl.min_value = 0.0; sl.max_value = 1.0; sl.step = 0.05; sl.value = float(s[key]); sl.custom_minimum_size.x = 240
		sl.value_changed.connect(func(v): s[key] = v; AudioManager.apply_settings())
		h.add_child(l); h.add_child(sl)
		add_child(h)
	var fs := CheckButton.new(); fs.text = "Fullscreen"; fs.button_pressed = bool(s.fullscreen)
	fs.toggled.connect(func(v): s.fullscreen = v; AudioManager.apply_settings())
	add_child(fs)
	var vs := CheckButton.new(); vs.text = "VSync"; vs.button_pressed = bool(s.vsync)
	vs.toggled.connect(func(v): s.vsync = v; AudioManager.apply_settings())
	add_child(vs)
	var au := CheckButton.new(); au.text = "Autosave (weekly)"; au.button_pressed = bool(s.autosave)
	au.toggled.connect(func(v): s.autosave = v)
	add_child(au)
	var rh := HBoxContainer.new()
	rh.add_child(UIU.label("Resolution"))
	var ro := OptionButton.new()
	for r in AudioManager.RESOLUTIONS: ro.add_item(r)
	ro.selected = maxi(AudioManager.RESOLUTIONS.find(s.resolution), 0)
	ro.item_selected.connect(func(i): s.resolution = AudioManager.RESOLUTIONS[i]; AudioManager.apply_settings())
	rh.add_child(ro)
	add_child(rh)
	var lh := HBoxContainer.new()
	lh.add_child(UIU.label("Language"))
	var lo := OptionButton.new()
	lo.add_item("English")
	lo.add_item("Español (coming soon)")
	lo.selected = 0
	lh.add_child(lo)
	add_child(lh)
	var th := HBoxContainer.new()
	th.add_child(UIU.label("Text speed"))
	var ts := HSlider.new(); ts.min_value = 0.5; ts.max_value = 3.0; ts.step = 0.25; ts.value = float(s.text_speed); ts.custom_minimum_size.x = 200
	ts.value_changed.connect(func(v): s.text_speed = v)
	th.add_child(ts)
	add_child(th)
	add_child(UIU.button("Save settings", func(): AudioManager.save_settings()))
