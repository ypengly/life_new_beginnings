extends CanvasLayer
## HUD: money/time/needs, bottom buttons, toasts, generic dialog, phone and pause menu.
const UIU = preload("res://scripts/ui/ui_util.gd")
const PhoneScript = preload("res://scripts/ui/phone.gd")
const SavePanel = preload("res://scripts/ui/save_panel.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

var money_l: Label
var time_l: Label
var weather_l: Label
var prompt_l: Label
var bars := {}
var toasts: VBoxContainer
var dlg: PanelContainer
var dlg_title: Label
var dlg_body: Label
var dlg_opts: VBoxContainer
var phone: PanelContainer
var pause: PanelContainer
var pause_box: VBoxContainer

func _ready() -> void:
	add_to_group("hud")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# top bar
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.add_child(top)
	var tv := VBoxContainer.new()
	top.add_child(tv)
	var row := HBoxContainer.new()
	tv.add_child(row)
	money_l = UIU.label("", 22, Color("#7be08b")); money_l.custom_minimum_size.x = 260
	time_l = UIU.label("", 20); time_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; time_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weather_l = UIU.label("", 16, Color("#b8e0ff")); weather_l.custom_minimum_size.x = 160
	row.add_child(money_l); row.add_child(time_l); row.add_child(weather_l)
	for sp in [["1x", 1.0], ["4x", 4.0], ["12x", 12.0]]:
		var v: float = sp[1]
		row.add_child(UIU.button(sp[0], func(): TimeManager.speed = v))
	var brow := HBoxContainer.new()
	tv.add_child(brow)
	for k in [["health", "Health", "#e05d5d"], ["energy", "Energy", "#e0c85d"], ["hunger", "Hunger", "#e0925d"], ["happiness", "Happy", "#5de0a0"], ["stress", "Stress", "#b05de0"], ["hygiene", "Hygiene", "#5dc8e0"]]:
		var vb := VBoxContainer.new()
		vb.add_child(UIU.label(k[1], 12))
		var p := ProgressBar.new()
		p.custom_minimum_size = Vector2(120, 12); p.show_percentage = false
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(k[2]); p.add_theme_stylebox_override("fill", sb)
		vb.add_child(p)
		brow.add_child(vb)
		bars[k[0]] = p
	# bottom buttons
	var bot := HBoxContainer.new()
	bot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bot)
	bot.add_child(UIU.button("Map (M)", func(): open_phone("Map")))
	bot.add_child(UIU.button("Phone (P)", func(): open_phone("Stats")))
	bot.add_child(UIU.button("Inventory (I)", func(): open_phone("Items")))
	bot.add_child(UIU.button("Menu (Esc)", func(): toggle_pause()))
	prompt_l = UIU.label("", 20, Color("#ffd166"))
	prompt_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt_l.position.y -= 50
	root.add_child(prompt_l)
	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toasts.position = Vector2(-20, 90)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)
	# dialog
	dlg = PanelContainer.new()
	dlg.set_anchors_preset(Control.PRESET_CENTER)
	dlg.grow_horizontal = Control.GROW_DIRECTION_BOTH; dlg.grow_vertical = Control.GROW_DIRECTION_BOTH
	dlg.custom_minimum_size = Vector2(620, 0)
	dlg.hide()
	root.add_child(dlg)
	var dv := VBoxContainer.new()
	dlg.add_child(dv)
	dlg_title = UIU.label("", 24, Color("#ffd166"))
	dlg_body = UIU.label("", 15)
	dv.add_child(dlg_title); dv.add_child(dlg_body)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(600, 300)
	dv.add_child(sc)
	dlg_opts = VBoxContainer.new()
	dlg_opts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(dlg_opts)
	dv.add_child(UIU.button("Close (Esc)", func(): dlg.hide()))
	# phone
	phone = PhoneScript.new()
	phone.set_anchors_preset(Control.PRESET_CENTER)
	phone.grow_horizontal = Control.GROW_DIRECTION_BOTH; phone.grow_vertical = Control.GROW_DIRECTION_BOTH
	phone.hide()
	root.add_child(phone)
	# pause
	pause = PanelContainer.new()
	pause.set_anchors_preset(Control.PRESET_CENTER)
	pause.grow_horizontal = Control.GROW_DIRECTION_BOTH; pause.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause.hide()
	root.add_child(pause)
	pause_box = VBoxContainer.new()
	pause_box.custom_minimum_size = Vector2(620, 0)
	pause.add_child(pause_box)
	GameManager.notified.connect(_toast)
	GameManager.dialog_requested.connect(show_dialog)

func _process(_d: float) -> void:
	var gs = GameManager.s
	if gs.is_empty(): return
	money_l.text = UIU.money(EconomyManager.money())
	time_l.text = "%s  %s  (%s)" % [TimeManager.day_name(), TimeManager.clock_text(), TimeManager.period_name()]
	weather_l.text = "%s | Age %d" % [EventManager.weather().capitalize(), TimeManager.get_age()]
	for k in bars: bars[k].value = GameManager.stat(k)
	GameManager.ui_open = dlg.visible or phone.visible or pause.visible

func set_prompt(t: String) -> void: prompt_l.text = t

func _toast(text: String) -> void:
	var l := UIU.label(text, 15)
	l.custom_minimum_size.x = 340
	var pc := PanelContainer.new()
	pc.add_child(l)
	toasts.add_child(pc)
	AudioManager.play_sfx("notify")
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_callback(pc.queue_free)

func show_dialog(title: String, body: String, options: Array) -> void:
	dlg_title.text = title
	dlg_body.text = body
	UIU.clear(dlg_opts)
	for o in options:
		var opt: Dictionary = o
		var b := Button.new()
		b.text = opt.label
		b.disabled = opt.get("disabled", false)
		b.tooltip_text = opt.get("tip", "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			AudioManager.play_sfx("click")
			dlg.hide()
			if opt.has("call"): opt.call.call())
		dlg_opts.add_child(b)
	dlg.show()

func open_phone(tab := "Stats") -> void:
	dlg.hide(); pause.hide()
	phone.open(tab)

func toggle_pause() -> void:
	if pause.visible:
		pause.hide()
		return
	dlg.hide(); phone.hide()
	_pause_main()
	pause.show()

func _pause_main() -> void:
	UIU.clear(pause_box)
	pause_box.add_child(UIU.label("Paused", 28, Color("#ffd166")))
	pause_box.add_child(UIU.button("Resume", func(): pause.hide()))
	pause_box.add_child(UIU.button("Save game", func(): _pause_panel(SavePanel, "save")))
	pause_box.add_child(UIU.button("Load game", func(): _pause_panel(SavePanel, "load")))
	pause_box.add_child(UIU.button("Settings", func(): _pause_panel(SettingsPanel, "")))
	pause_box.add_child(UIU.button("Main menu", func():
		SaveManager.autosave()
		pause.hide()
		GameManager.in_game = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")))
	pause_box.add_child(UIU.button("Quit", func(): get_tree().quit()))

func _pause_panel(script: Script, mode: String) -> void:
	UIU.clear(pause_box)
	var p = script.new()
	if mode != "": p.mode = mode
	if p.has_signal("loaded"):
		p.loaded.connect(func():
			pause.hide()
			get_tree().reload_current_scene())
	pause_box.add_child(p)
	pause_box.add_child(UIU.button("Back", func(): _pause_main()))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if dlg.visible: dlg.hide()
		elif phone.visible: phone.hide()
		else: toggle_pause()
	elif event.is_action_pressed("phone"): _toggle_phone("Stats")
	elif event.is_action_pressed("map"): _toggle_phone("Map")
	elif event.is_action_pressed("inventory"): _toggle_phone("Items")

func _toggle_phone(tab: String) -> void:
	if phone.visible: phone.hide()
	elif not dlg.visible and not pause.visible: open_phone(tab)
