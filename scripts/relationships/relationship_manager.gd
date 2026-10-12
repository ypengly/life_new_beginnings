extends Node
## NPC relationships, romance, marriage and kids. State lives in GameManager.s.rel (+ s.children).

const LEVELS := [[0, "Stranger"], [10, "Acquaintance"], [30, "Friend"], [60, "Close Friend"], [85, "Best Friend"]]
const PERSONALITY_GAIN := {"friendly": 1.3, "shy": 0.7, "ambitious": 1.0, "lazy": 1.0, "aggressive": 0.9, "funny": 1.2, "serious": 0.8, "wealthy": 1.0, "poor": 1.0}
const LINES := {
	"friendly": ["\"Great to see you! How's life treating you?\"", "\"I was just thinking about you!\""],
	"shy": ["\"Oh... hi. Nice weather, isn't it?\"", "\"I don't talk much, but I like chatting with you.\""],
	"ambitious": ["\"Busy week. I'm going for that promotion.\"", "\"You should think bigger. Invest, build something.\""],
	"lazy": ["\"Ugh, Mondays. Wanna do nothing together?\"", "\"I'd work harder if the couch wasn't so comfy.\""],
	"aggressive": ["\"What do you want?... Fine, I've got a minute.\"", "\"People keep annoying me. Not you, though.\""],
	"funny": ["\"Did you hear the one about the broke landlord? Neither did I, he's broke.\"", "\"I'm not saying I'm funny, but my mom laughed once.\""],
	"serious": ["\"Efficiency matters. Make good decisions.\"", "\"I'm glad you take your life seriously.\""],
	"wealthy": ["\"Money isn't everything, but it keeps the lights on.\"", "\"Let me give you some advice on saving.\""],
	"poor": ["\"Times are tough, but we get by.\"", "\"Every dollar counts for me these days.\""],
}
var children: Array: # kept for readability; real storage is GameManager.s.children
	get: return GameManager.s.children

func init_state() -> void:
	GameManager.s.rel = {}
	GameManager.s.children = []

func _ready() -> void:
	TimeManager.day_changed.connect(_on_day)

func rec(id: String) -> Dictionary:
	var r: Dictionary = GameManager.s.rel
	if not r.has(id):
		r[id] = {"v": 0.0, "met": false, "stage": "none", "dates": 0, "memory": [], "talks": 0, "last_arg": -99, "married_day": -1}
	return r[id]

func npc_data(id: String) -> Dictionary: return GameManager.idx.npcs[id]
func value(id: String) -> float: return float(rec(id).v)

func level_name(v: float) -> String:
	var n: String = LEVELS[0][1]
	for l in LEVELS:
		if v >= l[0]: n = l[1]
	return n

func remember(id: String, text: String) -> void:
	var m: Array = rec(id).memory
	m.push_back("Day %d: %s" % [TimeManager.get_day(), text])
	if m.size() > 8: m.pop_front()

func add_rel(id: String, d: float, memory := "") -> void:
	if not GameManager.idx.npcs.has(id): return
	var r := rec(id)
	r.met = true
	if d > 0.0:
		d *= float(PERSONALITY_GAIN.get(npc_data(id).personality, 1.0)) * (1.0 + (GameManager.stat("charisma") + GameManager.charisma_bonus()) / 200.0)
	elif npc_data(id).personality == "aggressive":
		d *= 1.4
	r.v = clampf(float(r.v) + d, 0.0, 100.0)
	if memory != "": remember(id, memory)
	GameManager.check_achievements()

func _on_day(_d: int) -> void:
	if not GameManager.in_game or not GameManager.s.has("rel"): return
	for id in GameManager.s.rel:
		var r = GameManager.s.rel[id]
		r.talks = 0
		# relationships fade without contact (partners & spouses fade slower)
		var rate := 0.05 if r.stage in ["relationship", "living", "married"] else 0.12
		if TimeManager.get_day() - int(r.get("last_contact", 0)) > 10 and float(r.v) > 5.0:
			r.v = maxf(float(r.v) - rate, 5.0)

func happiness_bonus() -> float:
	var b := 0.0
	var friends := 0
	for id in GameManager.s.rel:
		var r = GameManager.s.rel[id]
		if float(r.v) >= 30.0: friends += 1
		match r.stage:
			"dating": b = maxf(b, 4.0)
			"relationship": b = maxf(b, 8.0)
			"living": b = maxf(b, 10.0)
			"married": b = maxf(b, 13.0)
	return b + minf(friends * 1.5, 6.0)

func partner() -> String:
	for id in GameManager.s.rel:
		if GameManager.s.rel[id].stage in ["dating", "relationship", "living", "married"]: return id
	return ""

# ---------------------------------------------------------------- interactions (return reply text)
func talk(id: String) -> String:
	var r := rec(id)
	r.last_contact = TimeManager.get_day()
	TimeManager.advance(15)
	var gain := 3.0 if int(r.talks) < 3 else 0.4
	r.talks = int(r.talks) + 1
	add_rel(id, gain, "")
	GameManager.change_stat("social", 0.4)
	GameManager.change_stat("happiness", 1.0)
	var lines: Array = LINES[npc_data(id).personality]
	var reply: String = lines[randi() % lines.size()]
	if r.memory.size() > 0 and randf() < 0.4:
		reply += "\n(They remember: %s)" % r.memory[r.memory.size() - 1]
	return reply

func gift(id: String, item_id: String) -> String:
	var it = GameManager.idx.items[item_id]
	if not GameManager.remove_item(item_id): return "You don't have that."
	var rec_r := rec(id)
	rec_r.last_contact = TimeManager.get_day()
	add_rel(id, float(it.gift), "You gave them %s" % it.name)
	return "%s loves the %s!" % [npc_data(id).name, it.name]

func eat_together(id: String) -> String:
	var cost := EconomyManager.price(18)
	if not EconomyManager.spend(cost): return "You can't afford a meal right now."
	TimeManager.advance(60)
	GameManager.change_stat("hunger", 40.0)
	GameManager.change_stat("happiness", 6.0)
	rec(id).last_contact = TimeManager.get_day()
	add_rel(id, 6.0, "Shared a meal")
	return "A lovely meal together. (-%s)" % GameManager.UIU.money(cost)

func help(id: String) -> String:
	if GameManager.stat("energy") < 20.0: return "You're too tired to help right now."
	TimeManager.advance(120)
	GameManager.change_stat("energy", -10.0)
	rec(id).last_contact = TimeManager.get_day()
	add_rel(id, 5.0, "You helped them out")
	GameManager.s.reputation = clampf(float(GameManager.s.reputation) + 0.3, 0.0, 100.0)
	return "You spent a couple of hours helping. They're grateful."

func argue(id: String) -> String:
	var r := rec(id)
	r.last_arg = TimeManager.get_day()
	add_rel(id, -10.0, "You argued")
	GameManager.change_stat("stress", 6.0)
	return "Harsh words were exchanged..."

func apologize(id: String) -> String:
	var r := rec(id)
	var recent := TimeManager.get_day() - int(r.last_arg) <= 7
	add_rel(id, 8.0 if recent else 1.0, "You apologized" if recent else "")
	return "They accept your apology." if recent else "They look confused: there was nothing to apologize for."

func ask_out(id: String) -> String:
	var r := rec(id)
	if not npc_data(id).romance_ok: return "They're not interested in dating."
	if value(id) < 40.0: return "\"I don't know you well enough yet.\" (needs Friend level 40+)"
	if partner() != "" and partner() != id: return "You're already seeing someone else."
	r.stage = "dating"
	remember(id, "Started dating")
	return "They said yes! You're dating."

func date(id: String) -> String:
	var cost := EconomyManager.price(50)
	if not EconomyManager.spend(cost): return "You can't afford a date right now."
	var r := rec(id)
	TimeManager.advance(180)
	r.dates = int(r.dates) + 1
	r.last_contact = TimeManager.get_day()
	add_rel(id, 8.0, "Went on a date")
	GameManager.change_stat("happiness", 12.0)
	GameManager.change_stat("stress", -6.0)
	return "A wonderful evening. (-%s)" % GameManager.UIU.money(cost)

func make_official(id: String) -> String:
	var r := rec(id)
	if int(r.dates) < 3 or value(id) < 60.0: return "Not yet: you need 3 dates and relationship 60+."
	r.stage = "relationship"
	remember(id, "Became a couple")
	return "You're officially a couple!"

func move_in(id: String) -> String:
	var r := rec(id)
	if value(id) < 75.0 or GameManager.home_quality() < 1.0: return "Not yet: relationship 75+ and a home of your own are required."
	r.stage = "living"
	remember(id, "Moved in together")
	return "They moved in with you."

func propose(id: String) -> String:
	var r := rec(id)
	if r.stage != "living" or value(id) < 85.0: return "Not yet: living together and relationship 85+ required."
	var cost := EconomyManager.price(2000)
	if not EconomyManager.spend(cost): return "A ring costs %s." % GameManager.UIU.money(cost)
	r.stage = "married"
	r.married_day = TimeManager.get_day()
	GameManager.s.flags["married"] = true
	GameManager.s.flags["spouse"] = id
	remember(id, "Got married")
	GameManager.change_stat("happiness", 25.0)
	GameManager.check_achievements()
	return "They said YES! You're married."

func breakup(id: String) -> String:
	var r := rec(id)
	r.stage = "none"
	r.dates = 0
	if GameManager.s.flags.get("spouse", "") == id:
		GameManager.s.flags.erase("spouse")
		GameManager.s.flags["married"] = false
	r.v = maxf(float(r.v) - 30.0, 0.0)
	remember(id, "Broke up")
	GameManager.change_stat("happiness", -20.0)
	return "It's over. You both needed some space."

func can_have_child(id: String) -> bool:
	var r := rec(id)
	return r.stage == "married" and TimeManager.get_day() - int(r.married_day) >= 360 and children.size() < 3

func have_child(id: String) -> String:
	if not can_have_child(id): return "Not yet: married for at least a year, max 3 kids."
	var cost := EconomyManager.price(3000)
	if not EconomyManager.spend(cost): return "Hospital and baby supplies cost %s." % GameManager.UIU.money(cost)
	var names := ["Ava", "Noah", "Mila", "Leo", "Zoe", "Kai"]
	children.append({"name": names[randi() % names.size()], "age": 0})
	GameManager.change_stat("happiness", 20.0)
	return "Congratulations! A baby joins your family."

func age_children() -> void:
	for c in children: c.age = int(c.age) + 1

func family_cost() -> float:
	var t := 0.0
	for c in children: t += EconomyManager.price(350 + (150 if int(c.age) >= 6 else 0))
	return t
