extends Node2D
## Builds the city from data/locations.json: districts, buildings (solid), locked-district barriers, day/night, interaction.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NPC_SCENE := preload("res://scenes/npc/npc.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const WALL := {"home": "#c9a27e", "shop_food": "#e8c468", "shop_clothes": "#d98cb3", "shop_electronics": "#6aa6d9", "shop_furniture": "#b58b5a",
	"restaurant": "#d9734e", "cafe": "#b78a6b", "gym": "#7f8c8d", "bank": "#6c8e74", "brokerage": "#8c7f5a", "realestate": "#9c8f6b",
	"school": "#e0b84a", "university": "#a05a5a", "library": "#8a7bb0", "cinema": "#8e5aa5", "arcade": "#4aa5a5", "nightclub": "#5a3a8a",
	"sports_center": "#5a8fb0", "beach": "#e8d9a0", "park": "#6fb56f", "hospital": "#e8e8e8", "car_dealer": "#c04a4a", "gas": "#d8d84a",
	"office": "#7d8fa8", "factory": "#7a7a7a", "workshop": "#8a6a4a", "construction": "#c9953a", "warehouse": "#6a7a8a", "commercial_property": "#9ab07a"}
const LIGHT := [[0.0, Color(0.32, 0.36, 0.6)], [5.0, Color(0.34, 0.38, 0.62)], [7.0, Color(0.95, 0.8, 0.7)], [9.0, Color(1, 1, 1)],
	[17.0, Color(1, 1, 1)], [19.5, Color(1.0, 0.72, 0.6)], [21.5, Color(0.36, 0.4, 0.66)], [24.0, Color(0.32, 0.36, 0.6)]]

var player: CharacterBody2D
var hud: CanvasLayer
var mod: CanvasModulate
var barriers := {}
var _near_b := {}
var _near_npc: Node2D = null
var _disc_t := 0.0

func _ready() -> void:
	if not GameManager.in_game:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	mod = CanvasModulate.new()
	add_child(mod)
	var wc = GameManager.data.locations.world
	var size := Vector2(wc.cols * wc.cell_w, wc.rows * wc.cell_h)
	_wall(Rect2(-100, -100, size.x + 200, 100))
	_wall(Rect2(-100, size.y, size.x + 200, 100))
	_wall(Rect2(-100, 0, 100, size.y))
	_wall(Rect2(size.x, 0, 100, size.y))
	for b in GameManager.data.locations.buildings:
		if b.type == "park" or b.type == "beach": continue # open areas, walkable
		_wall(Rect2(b.wx, b.wy, b.w, b.h - 14))
	for d in GameManager.data.locations.districts:
		if not GameManager.is_unlocked(d.id): barriers[d.id] = _wall(d.rect)
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.position = Vector2(GameManager.s.pos[0], GameManager.s.pos[1])
	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = 0; cam.limit_top = 0; cam.limit_right = int(size.x); cam.limit_bottom = int(size.y)
	NPCManager.spawn_all(self, NPC_SCENE)
	hud = HUD_SCENE.instantiate()
	add_child(hud)
	GameManager.district_unlocked.connect(_on_unlock)
	AudioManager.play_music("res://assets/audio/music/theme.ogg")
	AudioManager.play_music("res://assets/audio/ambience/city.ogg", true)
	GameManager.update_unlocks()
	queue_redraw()

func _wall(r: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	shape.shape = rs
	body.position = r.position + r.size / 2.0
	body.add_child(shape)
	add_child(body)
	return body

func _on_unlock(id: String) -> void:
	if barriers.has(id):
		barriers[id].queue_free()
		barriers.erase(id)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_instance_valid(player): return
	mod.color = mod.color.lerp(_light(), minf(delta * 3.0, 1.0))
	if EventManager.weather() in ["rain", "storm"]:
		mod.color = mod.color.darkened(0.15 if EventManager.weather() == "rain" else 0.3)
	player.rain.emitting = EventManager.weather() in ["rain", "storm"]
	_find_nearest()
	_disc_t += delta
	if _disc_t > 0.7:
		_disc_t = 0.0
		for b in GameManager.data.locations.buildings:
			if b.id not in GameManager.s.discovered and GameManager.door_of(b.id).distance_to(player.position) < 450.0:
				GameManager.s.discovered.append(b.id)

func _light() -> Color:
	var h := TimeManager.get_hour_float()
	for i in range(LIGHT.size() - 1):
		var a = LIGHT[i]
		var b = LIGHT[i + 1]
		if h >= a[0] and h <= b[0]:
			return a[1].lerp(b[1], (h - a[0]) / (b[0] - a[0]))
	return Color.WHITE

func _find_nearest() -> void:
	_near_b = {}
	_near_npc = null
	var best := 90.0
	for b in GameManager.data.locations.buildings:
		var dd := GameManager.door_of(b.id).distance_to(player.position)
		if dd < best:
			best = dd
			_near_b = b
	var nbest := 70.0
	for id in NPCManager.nodes:
		var n = NPCManager.nodes[id]
		if n.is_interactable() and n.position.distance_to(player.position) < nbest:
			nbest = n.position.distance_to(player.position)
			_near_npc = n
	if _near_npc != null: hud.set_prompt("E: Talk to %s" % _near_npc.info.name)
	elif not _near_b.is_empty(): hud.set_prompt("E: %s" % _near_b.name)
	else: hud.set_prompt("")

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.ui_open or not event.is_action_pressed("interact"): return
	if _near_npc != null:
		ActivityManager.open_npc(_near_npc.info.id)
	elif not _near_b.is_empty():
		ActivityManager.open_building(_near_b)

func teleport_to(building_id: String) -> void:
	var b = GameManager.idx.buildings[building_id]
	if not GameManager.is_unlocked(b.district):
		GameManager.notify("That district is still locked.")
		return
	player.position = GameManager.door_of(building_id)
	TimeManager.advance(15)
	GameManager.notify("You traveled to %s." % b.name)

func _draw() -> void:
	var f := ThemeDB.fallback_font
	for d in GameManager.data.locations.districts:
		var r: Rect2 = d.rect
		draw_rect(r, Color(d.color))
		draw_rect(Rect2(r.position.x, r.position.y + 290, r.size.x, 220), Color(0.32, 0.33, 0.36))
		for x in range(0, int(r.size.x), 90):
			draw_rect(Rect2(r.position.x + x, r.position.y + 396, 50, 6), Color(0.9, 0.85, 0.4))
		draw_rect(r, Color(0, 0, 0, 0.35), false, 4.0)
		draw_string(f, r.position + Vector2(20, 50), d.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, 0.55))
	for b in GameManager.data.locations.buildings:
		var rc := Rect2(b.wx, b.wy, b.w, b.h)
		var col := Color(WALL.get(b.type, "#aaaaaa"))
		if b.type == "park":
			draw_rect(rc, col.lightened(0.1))
			draw_circle(rc.get_center(), 50, Color("#5aa0d0"))
		elif b.type == "beach":
			draw_rect(rc, col)
			draw_rect(Rect2(rc.position.x, rc.position.y + 90, rc.size.x, 80), Color("#4aa3d8"))
		else:
			draw_rect(rc, col)
			draw_rect(Rect2(rc.position.x, rc.position.y, rc.size.x, 28), col.darkened(0.3))
			draw_rect(Rect2(rc.position.x + rc.size.x / 2 - 16, rc.position.y + rc.size.y - 34, 32, 34), Color(0.2, 0.12, 0.08))
		draw_string(f, rc.position + Vector2(0, 20), b.name, HORIZONTAL_ALIGNMENT_CENTER, rc.size.x, 15, Color.WHITE)
		draw_string(f, rc.position + Vector2(0, 60), b.type.replace("_", " "), HORIZONTAL_ALIGNMENT_CENTER, rc.size.x, 12, Color(1, 1, 1, 0.7))
	for d in GameManager.data.locations.districts:
		if not GameManager.is_unlocked(d.id):
			draw_rect(d.rect, Color(0, 0, 0, 0.6))
			draw_multiline_string(f, d.rect.position + Vector2(0, 430), "LOCKED - %s\nReach net worth %s" % [d.name, GameManager.UIU.money(d.unlock)], HORIZONTAL_ALIGNMENT_CENTER, d.rect.size.x, 28, -1, Color(1, 0.85, 0.4))
