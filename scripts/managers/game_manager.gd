extends Node
## Central game state. ALL mutable run state lives in the dictionary `s` so saving is trivial.

signal stats_changed
signal notified(text: String)
signal dialog_requested(title: String, body: String, options: Array)
signal game_started
signal district_unlocked(id: String)

const UIU = preload("res://scripts/ui/ui_util.gd")
const SAVE_VERSION := 1
const STAT_KEYS := ["health", "energy", "hunger", "hygiene", "happiness", "stress", "fitness", "intelligence", "social", "charisma", "discipline", "creativity"]
const SKILL_KEYS := ["programming", "business", "cooking", "marketing", "finance", "mechanics", "design", "communication", "management"]
const BACKGROUNDS := {
	"poor": {"name": "Poor", "money": 120.0, "desc": "Almost broke, but resourceful: hunger drains slower and everything costs 15% less.",
		"stats": {"discipline": 10.0}, "skills": {"cooking": 8.0}, "perks": {"hunger_mult": 0.7, "expense_mult": 0.85}},
	"average": {"name": "Average", "money": 400.0, "desc": "Balanced starting statistics.",
		"stats": {"social": 5.0, "intelligence": 5.0}, "skills": {}, "perks": {}},
	"wealthy": {"name": "Wealthy", "money": 3000.0, "desc": "Comfortable savings, but a pricey lifestyle (+30% costs).",
		"stats": {"charisma": 5.0}, "skills": {"business": 3.0}, "perks": {"expense_mult": 1.3}},
	"student": {"name": "Student", "money": 200.0, "desc": "High school diploma and sharper mind, limited cash.",
		"stats": {"intelligence": 15.0}, "skills": {"programming": 4.0}, "perks": {}},
	"entrepreneur": {"name": "Entrepreneur", "money": 800.0, "desc": "Business know-how and a head start in marketing.",
		"stats": {"discipline": 8.0}, "skills": {"business": 12.0, "marketing": 6.0}, "perks": {"biz_bonus": 0.1}},
	"athlete": {"name": "Athlete", "money": 300.0, "desc": "Fit and healthy, slower to tire.",
		"stats": {"fitness": 25.0, "health": 0.0}, "skills": {}, "perks": {"energy_mult": 0.8}},
}
const ACHIEVEMENTS := {
	"first_job": ["First Job", "Earn your first salary."],
	"entrepreneur": ["Entrepreneur", "Start your first business."],
	"millionaire": ["Millionaire", "Reach $1,000,000 net worth."],
	"homeowner": ["Homeowner", "Buy your first home."],
	"investor": ["Investor", "Make your first investment."],
	"family": ["Family", "Get married."],
	"successful_business": ["Successful Business", "Earn $100,000 profit from your businesses."],
	"legend": ["Legend", "Reach maximum reputation."],
	"scholar": ["Scholar", "Earn three qualifications."],
	"driver": ["Hit the Road", "Buy your first vehicle."],
	"best_friend": ["Best Friend", "Become best friends with someone."],
	"freelancer": ["Gig Worker", "Complete 5 freelance projects."],
}

var data := {}
var idx := {}
var s := {}
var in_game := false
var ui_open := false
var sleeping := false
var _collapsing := false

func _ready() -> void:
	_register_inputs()
	for n in ["jobs", "items", "events", "npcs", "locations", "courses", "stocks", "businesses", "properties", "vehicles", "gigs"]:
		data[n] = _load_json("res://data/%s.json" % n)
	for kind in ["jobs", "items", "events", "npcs", "courses", "stocks", "businesses", "properties", "vehicles"]:
		idx[kind] = {}
		for e in data[kind]:
			idx[kind][e.id] = e
	var w = data.locations.world
	idx["districts"] = {}
	for d in data.locations.districts:
		d["rect"] = Rect2(d.col * w.cell_w, d.row * w.cell_h, w.cell_w, w.cell_h)
		idx.districts[d.id] = d
	idx["buildings"] = {}
	for b in data.locations.buildings:
		var dr: Rect2 = idx.districts[b.district].rect
		b["wx"] = dr.position.x + b.x
		b["wy"] = dr.position.y + b.y
		idx.buildings[b.id] = b
	TimeManager.hour_changed.connect(_on_hour)
	TimeManager.day_changed.connect(_on_day)
	TimeManager.year_changed.connect(_on_year)

func _load_json(path: String) -> Variant:
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed == null:
		push_error("Failed to parse " + path)
		return []
	return parsed

func _register_inputs() -> void:
	var map := {"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E], "inventory": [KEY_I], "map": [KEY_M], "phone": [KEY_P], "pause": [KEY_ESCAPE], "toggle_vehicle": [KEY_V]}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# Controller bindings (ready for later expansion)
	var pad := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in pad:
		var m := InputEventJoypadMotion.new()
		m.axis = pad[action][0]
		m.axis_value = pad[action][1]
		InputMap.action_add_event(action, m)
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	InputMap.action_add_event("interact", jb)

# ------------------------------------------------------------------ state
func _default_state() -> Dictionary:
	var stats := {}
	for k in STAT_KEYS:
		stats[k] = 50.0
	stats.health = 100.0; stats.energy = 85.0; stats.hunger = 75.0; stats.hygiene = 80.0
	stats.happiness = 60.0; stats.stress = 10.0; stats.fitness = 20.0
	stats.intelligence = 20.0; stats.social = 20.0; stats.charisma = 20.0; stats.discipline = 20.0; stats.creativity = 20.0
	stats["experience"] = 0.0
	var skills := {}
	for k in SKILL_KEYS:
		skills[k] = 0.0
	return {"name": "Alex", "background": "average", "look": {}, "money": 0.0, "stats": stats, "skills": skills,
		"inventory": {}, "equipped": {}, "job": "", "job_shifts": 0, "total_shifts": 0, "days_absent": 0, "worked_today": false,
		"reputation": 0.0, "freelance_rep": 0.0, "freelance_done": 0, "education": [], "enrolled": {}, "home": "apt_basic", "owned": [],
		"vehicles": [], "active_vehicle": "", "achievements": [], "flags": {}, "pos": [0.0, 0.0], "history": [], "unlocked": [],
		"discovered": [], "children": [], "notifications": [], "gigs": [], "active_gigs": [], "total_earned": 0.0, "story": 0, "declined_promo": ""}

func new_game(pname: String, bg: String, look: Dictionary) -> void:
	var b = BACKGROUNDS[bg]
	s = _default_state()
	s.name = pname.strip_edges() if pname.strip_edges() != "" else "Alex"
	s.background = bg
	s.look = look
	s.money = b.money
	for k in b.stats:
		s.stats[k] = clampf(float(s.stats[k]) + b.stats[k], 0.0, 100.0)
	for k in b.skills:
		s.skills[k] += b.skills[k]
	if bg == "student":
		s.education.append("high_school")
	TimeManager.reset()
	EconomyManager.init_state()
	RelationshipManager.init_state()
	NPCManager.init_state()
	BusinessManager.init_state()
	EventManager.init_state()
	s.pos = [door_of("apt_basic").x, door_of("apt_basic").y]
	s.history = [EconomyManager.net_worth()]
	in_game = true
	game_started.emit()
	notify("Welcome to town, %s. Rent is due every 30 days. Check your phone (P)." % s.name)

func load_state(payload: Dictionary) -> bool:
	if typeof(payload) != TYPE_DICTIONARY or not payload.has("state") or typeof(payload.state) != TYPE_DICTIONARY:
		return false
	if int(payload.get("version", 0)) > SAVE_VERSION:
		return false
	var st: Dictionary = payload.state
	if not st.has("stats") or not st.has("money"):
		return false
	s = _merge_defaults(_default_state(), st)
	# sanitize against corrupted / hand-edited values
	var m := float(s.money)
	s.money = 0.0 if (is_nan(m) or is_inf(m) or m < 0.0) else minf(m, EconomyManager.MAX_MONEY)
	for k in s.stats:
		s.stats[k] = float(s.stats[k]) if k == "experience" else clampf(float(s.stats[k]), 0.0, 100.0)
	if not idx.properties.has(s.home) and s.home != "":
		s.home = "apt_basic"
	TimeManager.total_minutes = maxi(int(payload.get("time", 480)), 0)
	if not s.has("economy"): EconomyManager.init_state()
	if not s.has("rel"): RelationshipManager.init_state()
	if not s.has("npcs"): NPCManager.init_state()
	if not s.has("business"): BusinessManager.init_state()
	if not s.has("events"): EventManager.init_state()
	in_game = true
	game_started.emit()
	return true

func _merge_defaults(dst: Dictionary, src: Dictionary) -> Dictionary:
	var out: Dictionary = dst.duplicate(true)
	for k in src:
		if out.has(k) and typeof(out[k]) == TYPE_DICTIONARY and typeof(src[k]) == TYPE_DICTIONARY and k != "inventory" and k != "flags" and k != "enrolled" and k != "equipped":
			out[k] = _merge_defaults(out[k], src[k])
		else:
			out[k] = src[k]
	return out

# ------------------------------------------------------------------ helpers
func door_of(id: String) -> Vector2:
	var b = idx.buildings[id]
	return Vector2(b.wx + b.w / 2.0, b.wy + b.h + 26.0)

func perk(name: String, default := 1.0) -> float:
	if s.is_empty(): return default
	return float(BACKGROUNDS[s.background].perks.get(name, default))

func notify(text: String) -> void:
	if not s.is_empty():
		s.notifications.push_front("[%s %s] %s" % [TimeManager.day_name().substr(0, 3), TimeManager.clock_text(), text])
		if s.notifications.size() > 60: s.notifications.pop_back()
	notified.emit(text)

func dialog(title: String, body: String, options: Array) -> void:
	dialog_requested.emit(title, body, options)

func stat(k: String) -> float: return float(s.stats.get(k, 0.0))

func change_stat(k: String, d: float) -> void:
	if k == "experience":
		s.stats["experience"] = float(s.stats.get("experience", 0.0)) + d
	else:
		s.stats[k] = clampf(stat(k) + d, 0.0, 100.0)
	stats_changed.emit()

func add_skill(k: String, d: float) -> void:
	s.skills[k] = clampf(float(s.skills.get(k, 0.0)) + d, 0.0, 100.0)

func has_qual(q: String) -> bool: return q in s.education

func add_item(id: String, n := 1) -> void:
	s.inventory[id] = int(s.inventory.get(id, 0)) + n

func remove_item(id: String, n := 1) -> bool:
	if int(s.inventory.get(id, 0)) < n: return false
	s.inventory[id] = int(s.inventory[id]) - n
	if int(s.inventory[id]) <= 0: s.inventory.erase(id)
	return true

func has_item(id: String) -> bool: return int(s.inventory.get(id, 0)) > 0

func item_sum(key: String) -> float:
	var t := 0.0
	for id in s.inventory:
		var it = idx.items.get(id)
		if it != null and it.has(key) and it.cat != "clothing": t += float(it[key])
	return t

func charisma_bonus() -> float:
	var t := 0.0
	for slot in s.equipped:
		var it = idx.items.get(s.equipped[slot])
		if it != null: t += float(it.get("charisma", 0))
	return t

func home_quality() -> float:
	var p = idx.properties.get(s.home)
	return float(p.quality) if p != null else 0.0

func active_vehicle() -> Dictionary:
	for v in s.vehicles:
		if v.id == s.active_vehicle: return v
	return {}

func speed_mult() -> float:
	var v := active_vehicle()
	if v.is_empty(): return 1.0
	var d = idx.vehicles[v.id]
	if d.fuel_use > 0 and float(v.fuel) <= 0.0: return 0.6
	return float(d.speed)

func apply_effects(e: Dictionary, ctx := {}) -> void:
	for k in e:
		var v = e[k]
		match k:
			"money":
				if v >= 0: EconomyManager.add_money(v)
				else: EconomyManager.spend_up_to(-v)
			"stats": for sk in v: change_stat(sk, v[sk] * (perk("energy_mult") if (sk == "energy" and v[sk] < 0) else 1.0))
			"skills": for sk in v: add_skill(sk, v[sk])
			"rep": s.reputation = clampf(float(s.reputation) + v, 0.0, 100.0)
			"rel_npc": if ctx.has("npc"): RelationshipManager.add_rel(ctx.npc, v)
			"mood": EconomyManager.st().mood += v
			"flag": s.flags[v] = true
			"time": TimeManager.advance(int(v))
	stats_changed.emit()

# ------------------------------------------------------------------ needs & time hooks
func _on_hour(_h: int) -> void:
	if not in_game or _collapsing: return
	var slp := sleeping
	change_stat("hunger", -3.0 * perk("hunger_mult") * (0.6 if slp else 1.0))
	change_stat("hygiene", -1.5)
	if not slp: change_stat("energy", -2.5 * perk("energy_mult"))
	if stat("hunger") <= 0.0:
		change_stat("health", -4.0); change_stat("happiness", -3.0)
	elif stat("hunger") < 20.0:
		change_stat("happiness", -2.0)
	if stat("energy") <= 0.0:
		change_stat("health", -3.0); change_stat("stress", 3.0)
	if stat("hygiene") < 20.0: change_stat("happiness", -1.5)
	if stat("stress") > 80.0: change_stat("health", -1.0)
	if stat("health") > 0.0 and stat("hunger") > 40.0 and stat("stress") < 60.0: change_stat("health", 0.3)
	# happiness drifts toward a baseline made of housing, comfort and relationships
	var base := 38.0 + home_quality() * 7.0 + item_sum("comfort") * 1.2 + RelationshipManager.happiness_bonus() - stat("stress") * 0.15
	var h := stat("happiness")
	change_stat("happiness", clampf(base - h, -1.0, 1.0) * 0.8)
	change_stat("stress", -0.4 if stat("stress") > 15.0 else 0.0)
	if stat("health") <= 0.0: _collapse()

func _on_day(_d: int) -> void:
	if not in_game: return
	if s.history.size() >= 180: s.history.pop_front()
	s.history.append(snappedf(EconomyManager.net_worth(), 1.0))
	update_unlocks()
	check_achievements()
	if _d % 7 == 0: SaveManager.autosave()

func _on_year(_y: int) -> void:
	if not in_game: return
	notify("Happy birthday! You are now %d." % TimeManager.get_age())
	RelationshipManager.age_children()

func _collapse() -> void:
	_collapsing = true
	var fee := EconomyManager.spend_up_to(EconomyManager.price(300))
	TimeManager.advance(12 * 60)
	s.stats.health = 40.0; s.stats.hunger = 50.0; s.stats.energy = 50.0; s.stats.stress = 40.0
	notify("You collapsed and woke up in hospital. Bill: %s." % UIU.money(fee))
	_collapsing = false

# ------------------------------------------------------------------ districts, achievements, endings
func is_unlocked(id: String) -> bool:
	return idx.districts[id].unlock <= 0 or id in s.unlocked

func update_unlocks() -> void:
	var nw := EconomyManager.net_worth()
	for d in data.locations.districts:
		if not is_unlocked(d.id) and nw >= d.unlock:
			s.unlocked.append(d.id)
			notify("New district unlocked: %s!" % d.name)
			district_unlocked.emit(d.id)

func unlock(id: String) -> void:
	if id in s.achievements: return
	s.achievements.append(id)
	notify("Achievement unlocked: %s" % ACHIEVEMENTS[id][0])
	AudioManager.play_sfx("event")

func check_achievements() -> void:
	var nw := EconomyManager.net_worth()
	if s.flags.get("first_job", false): unlock("first_job")
	if BusinessManager.count() > 0 or s.flags.get("had_business", false): unlock("entrepreneur")
	if nw >= 1000000.0: unlock("millionaire")
	for p in s.owned:
		if idx.properties[p].kind == "home": unlock("homeowner")
	if EconomyManager.st().traded: unlock("investor")
	if s.flags.get("married", false): unlock("family")
	if BusinessManager.total_profit() >= 100000.0: unlock("successful_business")
	if float(s.reputation) >= 100.0: unlock("legend")
	if s.education.size() >= 3: unlock("scholar")
	if not s.vehicles.is_empty(): unlock("driver")
	if int(s.freelance_done) >= 5: unlock("freelancer")
	for id in s.rel:
		if float(s.rel[id].v) >= 85.0: unlock("best_friend")

func ending_title() -> String:
	var nw := EconomyManager.net_worth()
	var best := ["A Quiet, Ordinary Life", 0.0]
	var cands := {
		"Successful Entrepreneur": BusinessManager.total_profit() / 2000.0 + BusinessManager.count() * 10.0,
		"Corporate Executive": (60.0 if CareerManager.job_level() == "Executive" else 0.0) + float(s.reputation) * 0.5,
		"Wealthy Investor": nw / 20000.0,
		"Happy Family": (50.0 if s.flags.get("married", false) else 0.0) + s.children.size() * 15.0 + stat("happiness") * 0.4,
		"Famous Celebrity": float(s.freelance_rep) * 1.2 + float(s.reputation) * 0.4 + (30.0 if s.flags.get("story_legacy", false) else 0.0),
		"Academic Success": s.education.size() * 18.0 + stat("intelligence") * 0.5,
		"World Traveler": s.discovered.size() * 1.5,
	}
	for k in cands:
		if cands[k] > best[1]: best = [k, cands[k]]
	if nw < 1000.0 and TimeManager.get_age() >= 40: return "Financial Failure"
	return best[0]
