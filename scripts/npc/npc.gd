extends Node2D
## One city NPC. Walks to the door of its scheduled building; hidden while "inside".

var info: Dictionary = {}
var target := Vector2.ZERO
var target_loc := ""
var arrived := true
var speed := 125.0
var color := Color.WHITE
const OUTDOOR := ["park", "beach"]

func setup(d: Dictionary) -> void:
	info = d
	name = d.id
	color = Color.from_hsv(float(hash(d.id) % 360) / 360.0, 0.55, 0.9)
	target_loc = d.home
	position = GameManager.door_of(d.home)
	z_index = 5

func set_destination(loc_id: String, snap: bool) -> void:
	if loc_id == target_loc and not snap: return
	target_loc = loc_id
	target = GameManager.door_of(loc_id) + Vector2(randf_range(-30, 30), randf_range(-6, 6))
	arrived = false
	if snap:
		position = target
		arrived = true
		_update_visibility()

func _update_visibility() -> void:
	visible = (not arrived) or GameManager.idx.buildings[target_loc].type in OUTDOOR
	queue_redraw()

func _process(delta: float) -> void:
	if arrived: return
	var to := target - position
	if to.length() < 6.0:
		position = target
		arrived = true
		_update_visibility()
		return
	position += to.normalized() * speed * delta
	visible = true
	queue_redraw()

func is_interactable() -> bool: return visible and arrived

func _draw() -> void:
	draw_circle(Vector2(0, 18), 9, Color(0, 0, 0, 0.2))
	draw_rect(Rect2(-8, -4, 16, 20), color)
	draw_circle(Vector2(0, -12), 8, Color("#e8b88a"))
	draw_string(ThemeDB.fallback_font, Vector2(-30, -26), info.get("name", "?"), HORIZONTAL_ALIGNMENT_CENTER, 60, 11, Color(1, 1, 1, 0.9))
