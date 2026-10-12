extends Node
## Weather, random life events and story beats. State: s.events.

func st() -> Dictionary: return GameManager.s.events

func init_state() -> void:
	GameManager.s.events = {"weather": "clear", "done": {}}

func _ready() -> void:
	TimeManager.day_changed.connect(_on_day)

func weather() -> String:
	return st().weather if GameManager.in_game and GameManager.s.has("events") else "clear"

func _on_day(d: int) -> void:
	if not GameManager.in_game or not GameManager.s.has("events"): return
	var r := randf()
	st().weather = "clear" if r < 0.6 else ("cloudy" if r < 0.8 else ("rain" if r < 0.95 else "storm"))
	var story := false
	for e in GameManager.data.events:
		if e.id.begins_with("story_") and _eligible(e, d):
			roll_event(e)
			story = true
			break
	if not story and randf() < 0.3:
		var pool := []
		for e in GameManager.data.events:
			if not e.id.begins_with("story_") and _eligible(e, d):
				for i in int(e.weight): pool.append(e)
		if not pool.is_empty(): roll_event(pool[randi() % pool.size()])

func _eligible(e: Dictionary, d: int) -> bool:
	var done: Dictionary = st().done
	if done.has(e.id) and (e.once or d - int(done[e.id]) < 25): return false
	var c = e.cond
	var gs = GameManager.s
	if c.has("min_day") and d < int(c.min_day): return false
	if c.has("min_money") and EconomyManager.money() < float(c.min_money): return false
	if c.has("min_networth") and EconomyManager.net_worth() < float(c.min_networth): return false
	if c.get("has_job", false) and gs.job == "": return false
	if c.get("has_vehicle", false) and gs.vehicles.is_empty(): return false
	if c.get("has_business", false) and BusinessManager.count() == 0: return false
	if c.has("need_flag") and not gs.flags.get(c.need_flag, false): return false
	if c.has("min_skill_any"):
		var ok := false
		for k in gs.skills: if float(gs.skills[k]) >= float(c.min_skill_any): ok = true
		if not ok: return false
	return true

func roll_event(e: Dictionary) -> void:
	st().done[e.id] = TimeManager.get_day()
	var ctx := {}
	var body: String = e.body
	if e.cond.get("need_npc", false) or "{npc}" in body:
		var ids: Array = GameManager.idx.npcs.keys()
		var known := ids.filter(func(i): return RelationshipManager.value(i) >= 10.0)
		var pick: String = known[randi() % known.size()] if not known.is_empty() else ids[randi() % ids.size()]
		ctx["npc"] = pick
		body = body.replace("{npc}", RelationshipManager.npc_data(pick).name)
	AudioManager.play_sfx("event")
	GameManager.notify("Event: " + e.title)
	var opts := []
	for o in e.options:
		var opt: Dictionary = o
		var afford: bool = true
		if opt.effects.has("money") and opt.effects.money < 0:
			afford = EconomyManager.money() >= -float(opt.effects.money)
		opts.append({"label": opt.label, "disabled": not afford, "call": func():
			GameManager.apply_effects(opt.effects, ctx)
			var res: String = opt.result
			if ctx.has("npc"): res = res.replace("{npc}", RelationshipManager.npc_data(ctx.npc).name)
			GameManager.notify(res)
			if e.id.begins_with("story_"): GameManager.s.story = int(GameManager.s.story) + 1})
	GameManager.dialog(e.title, body, opts)
