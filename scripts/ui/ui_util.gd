extends RefCounted
## Small static helpers for building UI in code.

static func money(v: float) -> String:
	var n := int(round(v))
	var neg := n < 0
	var digits := str(absi(n))
	var out := ""
	var c := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if neg else "") + "$" + out

static func label(text: String, size := 16, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func button(text: String, cb: Callable, disabled := false, tip := "") -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.tooltip_text = tip
	b.pressed.connect(func():
		AudioManager.play_sfx("click")
		cb.call())
	return b

static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

static func heading(box: Control, text: String) -> void:
	var l := label(text, 20, Color("#ffd166"))
	box.add_child(l)
	box.add_child(HSeparator.new())

static func row(box: Control, left: String, right: String) -> void:
	var h := HBoxContainer.new()
	var a := label(left)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(label(right, 16, Color("#b8e0ff")))
	box.add_child(h)

static func bar(box: Control, name: String, value: float, color: Color, max_v := 100.0) -> void:
	var h := HBoxContainer.new()
	var l := label(name)
	l.custom_minimum_size.x = 110
	h.add_child(l)
	var p := ProgressBar.new()
	p.max_value = max_v
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(220, 16)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	p.add_theme_stylebox_override("fill", sb)
	h.add_child(p)
	h.add_child(label(str(int(value))))
	box.add_child(h)
