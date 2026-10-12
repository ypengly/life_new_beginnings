extends CharacterBody2D
## Top-down player. Visuals are drawn by CharDraw (placeholder). To use real art, add an AnimatedSprite2D child:
## player.gd will then skip the placeholder drawing and play "idle"/"walk" animations automatically.

const CharDraw = preload("res://scripts/ui/char_draw.gd")
const BASE_SPEED := 190.0
var _bob := 0.0
var _step_t := 0.0
var _sprite: AnimatedSprite2D = null
var rain: CPUParticles2D

func _ready() -> void:
	add_to_group("player")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_sprite = get_node_or_null("AnimatedSprite2D")
	rain = CPUParticles2D.new()
	rain.position = Vector2(0, -380)
	rain.amount = 160
	rain.lifetime = 0.9
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(700, 8)
	rain.direction = Vector2(0.15, 1)
	rain.spread = 4.0
	rain.gravity = Vector2(0, 1100)
	rain.initial_velocity_min = 300.0
	rain.initial_velocity_max = 380.0
	rain.scale_amount_min = 1.5
	rain.scale_amount_max = 2.5
	rain.color = Color(0.7, 0.8, 1.0, 0.5)
	rain.emitting = false
	add_child(rain)

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if not GameManager.ui_open:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var spd := BASE_SPEED * GameManager.speed_mult()
	if GameManager.stat("energy") < 15.0: spd *= 0.7
	velocity = dir * spd
	move_and_slide()
	if dir != Vector2.ZERO:
		_bob += delta * 12.0
		_step_t += delta
		var v := GameManager.active_vehicle()
		if not v.is_empty():
			var d = GameManager.idx.vehicles[v.id]
			v.fuel = maxf(float(v.fuel) - d.fuel_use * spd * delta / 1000.0, 0.0)
		if _step_t > 0.35:
			_step_t = 0.0
			AudioManager.play_sfx("step")
		if _sprite: _sprite.play("walk")
	else:
		_bob = 0.0
		if _sprite: _sprite.play("idle")
	GameManager.s.pos = [position.x, position.y]
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_vehicle") and not GameManager.ui_open:
		_cycle_vehicle()

func _cycle_vehicle() -> void:
	var gs = GameManager.s
	if gs.vehicles.is_empty():
		GameManager.notify("You don't own a vehicle yet. Visit Drive Auto Sales in the Suburbs.")
		return
	var ids: Array = gs.vehicles.map(func(v): return v.id)
	if gs.active_vehicle == "":
		gs.active_vehicle = ids[0]
	else:
		var i := ids.find(gs.active_vehicle)
		gs.active_vehicle = "" if i == ids.size() - 1 else ids[i + 1]
	AudioManager.play_sfx("engine")
	GameManager.notify("On foot." if gs.active_vehicle == "" else "Riding: %s" % GameManager.idx.vehicles[gs.active_vehicle].name)

func _draw() -> void:
	if _sprite: return
	var v := GameManager.active_vehicle()
	if not v.is_empty():
		var d = GameManager.idx.vehicles[v.id]
		draw_rect(Rect2(-20, 2, 40, 20), Color(d.color))
		draw_circle(Vector2(-12, 24), 5, Color.BLACK)
		draw_circle(Vector2(12, 24), 5, Color.BLACK)
	CharDraw.paint(self, GameManager.s.look, sin(_bob) * 1.5)
