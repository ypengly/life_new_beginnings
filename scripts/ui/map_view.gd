extends Control
## Interactive city map. Click a discovered building to fast travel.
signal travel_requested(building_id: String)

func _scale() -> float:
	var w = GameManager.data.locations.world
	return minf(size.x / (w.cols * w.cell_w), size.y / (w.rows * w.cell_h))

func _draw() -> void:
	var k := _scale()
	var f := ThemeDB.fallback_font
	for d in GameManager.data.locations.districts:
		var r: Rect2 = d.rect
		var rr := Rect2(r.position * k, r.size * k)
		draw_rect(rr, Color(d.color).darkened(0.1 if GameManager.is_unlocked(d.id) else 0.6))
		draw_rect(rr, Color(0, 0, 0, 0.5), false, 1.0)
		draw_string(f, rr.position + Vector2(4, 14), d.name + ("" if GameManager.is_unlocked(d.id) else " (locked)"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	for b in GameManager.data.locations.buildings:
		if b.id in GameManager.s.discovered:
			var p := GameManager.door_of(b.id) * k
			var c := Color("#ffd166") if b.type == "commercial_property" and not BusinessManager.at(b.id).is_empty() else Color.WHITE
			draw_circle(p, 4, c)
	for id in NPCManager.nodes:
		var n = NPCManager.nodes[id]
		if n.visible: draw_circle(n.position * k, 2.5, Color("#66ccff"))
	var pl := get_tree().get_first_node_in_group("player")
	if pl: draw_circle(pl.position * k, 6, Color("#ff4d4d"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var k := _scale()
		var best := 14.0
		var pick := ""
		for b in GameManager.data.locations.buildings:
			if b.id in GameManager.s.discovered:
				var dd := (GameManager.door_of(b.id) * k).distance_to(event.position)
				if dd < best:
					best = dd
					pick = b.id
		if pick != "": travel_requested.emit(pick)
