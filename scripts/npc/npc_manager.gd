extends Node
## Spawns NPC nodes and drives their daily schedules.

var nodes := {}

func _ready() -> void:
	TimeManager.hour_changed.connect(func(_h): refresh(false))
	TimeManager.skipped.connect(func(): refresh(true))

func init_state() -> void:
	var st := {}
	for n in GameManager.data.npcs:
		st[n.id] = {"money": float(n.money), "hunger": 70.0, "energy": 80.0}
	GameManager.s.npcs = st

func spawn_all(world: Node2D, scene: PackedScene) -> void:
	nodes.clear()
	for n in GameManager.data.npcs:
		var node: Node2D = scene.instantiate()
		world.add_child(node)
		node.setup(n)
		nodes[n.id] = node
	refresh(true)

func target_loc(info: Dictionary) -> String:
	var sched: Array = info.weekend if TimeManager.is_weekend() else info.schedule
	var h := TimeManager.get_hour()
	var loc: String = sched[0][1]
	for e in sched:
		if h >= int(e[0]): loc = e[1]
	if loc == "home": return info.home
	if loc == "work": return info.work
	return loc

func refresh(snap: bool) -> void:
	for id in nodes:
		var node = nodes[id]
		node.set_destination(target_loc(node.info), snap)
	_update_needs()

func _update_needs() -> void:
	if not GameManager.s.has("npcs"): return
	var h := TimeManager.get_hour()
	for id in nodes:
		var n = GameManager.s.npcs.get(id)
		if n == null: continue
		var t: String = GameManager.idx.buildings[nodes[id].target_loc].type
		var sleeping: bool = (h >= 23 or h < 6) and t == "home"
		n.energy = clampf(float(n.energy) + (8.0 if sleeping else -2.0), 0.0, 100.0)
		var eating: bool = t in ["restaurant", "cafe"] or (t == "home" and h in [7, 19])
		n.hunger = clampf(float(n.hunger) + (35.0 if eating else -3.0), 0.0, 100.0)

func snap_all() -> void: refresh(true)

func npcs_at(loc_id: String) -> Array:
	var out := []
	for id in nodes:
		var node = nodes[id]
		if node.arrived and node.target_loc == loc_id: out.append(id)
	return out
