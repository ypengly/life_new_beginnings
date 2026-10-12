extends Node
## Builds the interaction menu for every building type and NPC. Everything is data-driven where possible.

const UIU = preload("res://scripts/ui/ui_util.gd")
const OPEN := {"shop_food": [7, 22], "shop_clothes": [9, 21], "shop_electronics": [9, 21], "shop_furniture": [9, 20], "restaurant": [11, 23],
	"cafe": [7, 21], "gym": [6, 23], "bank": [9, 17], "brokerage": [9, 17], "realestate": [9, 17], "school": [8, 17], "university": [8, 18],
	"library": [9, 20], "cinema": [11, 24], "arcade": [12, 24], "nightclub": [20, 28], "sports_center": [8, 22], "car_dealer": [9, 18],
	"office": [6, 21], "factory": [5, 22], "workshop": [7, 19], "construction": [5, 20], "warehouse": [5, 22], "hospital": [0, 24]}
const WEEKDAY_ONLY := ["bank", "brokerage", "realestate", "school", "university", "car_dealer"]
const OUTDOOR := ["park", "beach"]

var _body := ""

func is_open(t: String) -> bool:
	if not OPEN.has(t): return true
	if t in WEEKDAY_ONLY and TimeManager.is_weekend(): return false
	var h := TimeManager.get_hour()
	var o: Array = OPEN[t]
	if int(o[1]) > 24: return h >= int(o[0]) or h < int(o[1]) - 24
	return h >= int(o[0]) and h < int(o[1])

func hours_text(t: String) -> String:
	var o: Array = OPEN.get(t, [0, 24])
	return "%02d:00-%02d:00%s" % [o[0], int(o[1]) % 24, " (Mon-Fri)" if t in WEEKDAY_ONLY else ""]

func _o(label: String, call: Callable, disabled := false, tip := "") -> Dictionary:
	return {"label": label, "call": call, "disabled": disabled, "tip": tip}

func _od(label: String, disabled: bool, call: Callable) -> Dictionary:
	return {"label": label, "call": call, "disabled": disabled, "tip": ""}

func _odt(label: String, disabled: bool, tip: String, call: Callable) -> Dictionary:
	return {"label": label, "call": call, "disabled": disabled, "tip": tip}

func _say(text: String, back: Callable) -> void:
	GameManager.dialog(GameManager.idx.buildings.get(_cur, {}).get("name", "Result"), text, [_o("Continue", back)])

var _cur := ""

# ------------------------------------------------------------------ generic timed action
func _act(b: Dictionary, minutes: int, effects: Dictionary, msg: String, cost := 0.0, outdoor := false) -> Callable:
	return func():
		if outdoor and EventManager.weather() == "storm":
			GameManager.notify("It's too stormy to be outside.")
			open_building(b)
			return
		var en: float = effects.get("stats", {}).get("energy", 0.0)
		if en < 0.0 and GameManager.stat("energy") < -en * 0.6:
			GameManager.notify("You're too exhausted for that.")
			open_building(b)
			return
		if cost > 0.0 and not EconomyManager.spend(cost):
			open_building(b)
			return
		TimeManager.advance(minutes)
		GameManager.apply_effects(effects)
		GameManager.change_stat("experience", 0.5)
		GameManager.notify(msg)
		open_building(b)

# ------------------------------------------------------------------ buildings
func open_building(b: Dictionary) -> void:
	_cur = b.id
	var t: String = b.type
	if not is_open(t):
		GameManager.dialog(b.name, "Closed right now.\nOpening hours: %s" % hours_text(t), [])
		return
	_body = "%s\nHours: %s" % [TimeManager.clock_text(), hours_text(t) if OPEN.has(t) else "always open"]
	var o: Array = []
	match t:
		"home": o = _home(b)
		"shop_food", "shop_clothes", "shop_electronics", "shop_furniture": o = _shop(b)
		"restaurant", "cafe": o = _eatery(b)
		"gym": o = _gym(b)
		"sports_center": o = _sports(b)
		"park", "beach": o = _outdoors(b)
		"cinema": o = [_o("Watch a movie ($14, 2h)", _act(b, 120, {"stats": {"happiness": 12, "stress": -6, "energy": -2}}, "Great movie!", EconomyManager.price(14)))]
		"arcade": o = [_o("Play arcade games ($10, 1.5h)", _act(b, 90, {"stats": {"happiness": 9, "stress": -5, "energy": -3, "creativity": 0.3}}, "You beat your high score!", EconomyManager.price(10)))]
		"nightclub": o = [_o("Dance the night away ($30, 3h)", _act(b, 180, {"stats": {"happiness": 14, "social": 2, "charisma": 0.5, "energy": -20, "hygiene": -10, "stress": -8}}, "What a night!", EconomyManager.price(30)))]
		"bank": o = _bank(b)
		"brokerage": o = [_o("Open investment app", func(): get_tree().call_group("hud", "open_phone", "Invest"))]
		"realestate": o = _realestate(b)
		"hospital": o = [_o("Check-up & treatment ($80, 2h)", _act(b, 120, {"stats": {"health": 30, "stress": -5}}, "The doctor patched you up.", EconomyManager.price(80)))]
		"car_dealer": o = _dealer(b)
		"gas": o = _gas(b)
		"library": o = [_o("Read & study (2h, free)", _act(b, 120, {"stats": {"intelligence": 1.5, "stress": -3, "energy": -4}, "skills": {"communication": 0.3}}, "You learned something new.")),
			_o("Study a skill…", func(): _study_menu(b, "library"))]
		"school", "university": o = _school(b)
		"commercial_property": o = _unit(b)
	if _has_jobs(t): o.append_array(_job_options(b))
	if t != "home": o.append_array(_who_here(b))
	GameManager.dialog(b.name, _body, o)

func _has_jobs(t: String) -> bool:
	for j in GameManager.data.jobs:
		if j.workplace == t: return true
	return false

# ---- home -----------------------------------------------------------------
func _home(b: Dictionary) -> Array:
	var gs = GameManager.s
	var p = GameManager.idx.properties[b.prop]
	var o: Array = []
	_body = "%s\n%s\nQuality %d/6" % [p.name, p.desc, p.quality]
	if gs.home == p.id:
		_body += "\nThis is your home."
		o.append(_o("Sleep until morning", func(): _sleep(b, false)))
		o.append(_o("Take a nap (2h)", func(): _sleep(b, true)))
		o.append(_o("Take a shower (15m)", _act(b, 15, {"stats": {"hygiene": 70, "happiness": 2}}, "Fresh and clean.")))
		var can_cook := GameManager.has_item("ingredients")
		o.append(_odt("Cook a meal (45m)", not can_cook, "Needs Cooking Ingredients from a grocery store.", func():
			if GameManager.remove_item("ingredients"):
				GameManager.add_skill("cooking", 1.0)
				_act(b, 45, {"stats": {"hunger": 45, "happiness": 4}}, "A tasty home-cooked meal.").call()
			else: open_building(b)))
		o.append(_o("Study a skill… (3h)", func(): _study_menu(b, "home")))
		o.append(_o("Read a book (2h)", _act(b, 120, {"stats": {"intelligence": 1.0, "stress": -4, "happiness": 2, "energy": -3}}, "A good read.")))
		o.append(_o("Play video games (2h)", _act(b, 120, {"stats": {"happiness": 8 + GameManager.item_sum("game_bonus"), "stress": -6, "energy": -4}}, "Fun, but time flew by.")))
		o.append(_o("Exercise at home (1h)", _act(b, 60, {"stats": {"fitness": 1.0, "energy": -10, "hygiene": -8, "health": 0.5}}, "Sweaty but proud.")))
		o.append(_o("Freelance projects…", func(): _freelance(b)))
	else:
		if gs.home != "": _body += "\nYou live at: %s" % GameManager.idx.properties[gs.home].name
		if p.id in gs.owned:
			o.append(_o("Move in (free)", func():
				gs.home = p.id
				GameManager.notify("You moved into %s." % p.name)
				open_building(b)))
			o.append(_odt("Sell for %s" % UIU.money(p.price * float(EconomyManager.st().property_index) * 0.95), gs.home == p.id, "You can't sell the home you live in.", func():
				EconomyManager.add_money(p.price * float(EconomyManager.st().property_index) * 0.95)
				gs.owned.erase(p.id)
				GameManager.notify("Sold %s." % p.name)
				open_building(b)))
		else:
			if p.rent > 0:
				o.append(_o("Rent: %s/mo (first month now)" % UIU.money(EconomyManager.price(p.rent)), func():
					if EconomyManager.spend(EconomyManager.price(p.rent)):
						gs.home = p.id
						EconomyManager.st().missed_rent = 0
						GameManager.notify("You moved into %s." % p.name)
					open_building(b)))
			if p.price > 0:
				var price: float = p.price * float(EconomyManager.st().property_index)
				_body += "\nPrice: %s (maintenance %s/mo)" % [UIU.money(price), UIU.money(EconomyManager.price(p.maintenance))]
				o.append(_o("Buy for %s" % UIU.money(price), func():
					if EconomyManager.spend(price):
						gs.owned.append(p.id)
						gs.home = p.id
						GameManager.notify("Congratulations on your new home!")
						GameManager.check_achievements()
					open_building(b)))
		if p.rent > 0: _body += "\nRent: %s/mo" % UIU.money(EconomyManager.price(p.rent))
	return o

func _sleep(b: Dictionary, nap: bool) -> void:
	var h := TimeManager.get_hour()
	var hours := 2 if nap else ((7 - h) + 24) % 24
	if not nap and hours < 4: hours = 8
	var gs = GameManager.s
	GameManager.sleeping = true
	TimeManager.advance(hours * 60)
	GameManager.sleeping = false
	var rate := 11.0 + GameManager.home_quality() * 1.5 + GameManager.item_sum("sleep_bonus")
	GameManager.change_stat("energy", minf(hours * rate, 100.0))
	GameManager.change_stat("health", hours * 0.8)
	GameManager.change_stat("stress", -hours * 1.2)
	GameManager.notify("You slept %d hours." % hours)
	open_building(b)

func _study_menu(b: Dictionary, where: String) -> void:
	var o: Array = []
	for sk in GameManager.SKILL_KEYS:
		var skill: String = sk
		o.append(_o("%s (%.0f)" % [skill.capitalize(), float(GameManager.s.skills[skill])], func():
			var bonus := 1.0 + GameManager.item_sum("study_bonus")
			_act(b, 180, {"skills": {skill: 1.0 * bonus}, "stats": {"intelligence": 0.5, "energy": -8, "stress": 2}}, "Studied %s." % skill).call()))
	o.append(_o("Back", func(): open_building(b)))
	GameManager.dialog("Study which skill?", "Each 3-hour session improves the skill. A laptop and desk help.", o)

func _freelance(b: Dictionary) -> void:
	var gs = GameManager.s
	var o: Array = []
	var body := "Freelance reputation: %d\n\nACTIVE PROJECTS" % int(gs.freelance_rep)
	if gs.active_gigs.is_empty(): body += "\n(none)"
	for g in gs.active_gigs:
		var gg: Dictionary = g
		body += "\n- %s: %.1f/%d, due day %d, pays %s" % [gg.title, float(gg.progress), int(gg.needed), int(gg.deadline), UIU.money(gg.pay)]
		o.append(_o("Work on: %s (3h)" % gg.title, func():
			var r := CareerManager.work_on_gig(int(gg.uid))
			GameManager.notify(r)
			_freelance(b)))
	for g in gs.gigs:
		var gg: Dictionary = g
		o.append(_od("Accept: %s [%s %d] %s" % [gg.title, gg.skill, int(gg.req), UIU.money(gg.pay)], float(gs.skills.get(gg.skill, 0.0)) < float(gg.req), func():
			CareerManager.accept_gig(int(gg.uid))
			_freelance(b)))
	o.append(_o("Back", func(): open_building(b)))
	GameManager.dialog("Freelance Board", body, o)

# ---- shops & eateries ------------------------------------------------------------
func _shop(b: Dictionary) -> Array:
	var o: Array = []
	_body += "\nMoney: %s" % UIU.money(EconomyManager.money())
	for it in GameManager.data.items:
		if it.shop != b.type: continue
		var item: Dictionary = it
		var cost := EconomyManager.price(item.price)
		var owned := int(GameManager.s.inventory.get(item.id, 0))
		var single: bool = item.cat in ["electronics", "furniture"] and owned > 0
		o.append(_odt("%s - %s%s" % [item.name, UIU.money(cost), (" (owned %d)" % owned) if owned > 0 else ""], single, "You already own one." if single else "", func():
			if EconomyManager.spend(cost):
				GameManager.add_item(item.id)
				GameManager.notify("Bought %s." % item.name)
			open_building(b)))
	return o

func _eatery(b: Dictionary) -> Array:
	var o: Array = []
	for it in GameManager.data.items:
		if it.shop != b.type: continue
		var item: Dictionary = it
		var cost := EconomyManager.price(item.price * (2.0 if b.id == "lux_rest" else 1.0))
		o.append(_o("%s - %s (%dm)" % [item.name, UIU.money(cost), int(item.minutes)], _act(b, int(item.minutes), item.effects, "Enjoyed: %s." % item.name, cost)))
	return o

func _gym(b: Dictionary) -> Array:
	return [_o("Workout ($12, 2h)", _act(b, 120, {"stats": {"fitness": 2.5, "health": 1.0, "energy": -18, "stress": -4, "happiness": 3, "hygiene": -15, "discipline": 0.5}}, "Great workout!", EconomyManager.price(12)))]

func _sports(b: Dictionary) -> Array:
	return [_o("Swim laps ($10, 1.5h)", _act(b, 90, {"stats": {"fitness": 2.0, "health": 1.5, "energy": -15, "happiness": 4}}, "Refreshing swim.", EconomyManager.price(10))),
		_o("Pick-up basketball ($8, 2h)", _act(b, 120, {"stats": {"fitness": 2.0, "social": 1.5, "happiness": 6, "energy": -18, "hygiene": -10}}, "Fun game!", EconomyManager.price(8)))]

func _outdoors(b: Dictionary) -> Array:
	var rain := EventManager.weather() in ["rain", "storm"]
	_body += "\nWeather: %s" % EventManager.weather()
	if b.type == "beach":
		return [_o("Swim & sunbathe (2h)", _act(b, 120, {"stats": {"happiness": 10 if not rain else 2, "fitness": 1.0, "stress": -8, "hygiene": -10, "energy": -10}}, "A day at the beach.", 0.0, true))]
	return [_o("Go for a run (1h)", _act(b, 60, {"stats": {"fitness": 1.5, "health": 1.0, "energy": -12, "happiness": 3 if not rain else -2, "hygiene": -8}}, "Good run.", 0.0, true)),
		_o("Relax on a bench (1h)", _act(b, 60, {"stats": {"stress": -8, "happiness": 4 if not rain else 0, "energy": 4}}, "Peaceful.", 0.0, true))]

# ---- bank, property, vehicles ----------------------------------------------------
func _bank(b: Dictionary) -> Array:
	var e = EconomyManager.st()
	_body += "\nCash: %s | Savings: %s | Credit score: %d\nDebt: %s | Credit limit: %s | APR: %.1f%%" % [UIU.money(EconomyManager.money()), UIU.money(e.bank),
		int(e.credit), UIU.money(EconomyManager.total_debt()), UIU.money(EconomyManager.max_loan()), EconomyManager.offer_rate() * 100.0]
	var o: Array = []
	for a in [100, 500, 2000]:
		var amt: int = a
		o.append(_od("Deposit %s" % UIU.money(amt), EconomyManager.money() < amt, func():
			EconomyManager.deposit(amt)
			open_building(b)))
	o.append(_od("Withdraw all savings", float(e.bank) <= 0.0, func():
		EconomyManager.withdraw(float(e.bank))
		open_building(b)))
	for l in [[2000, 12], [10000, 24], [50000, 60]]:
		var amt: int = l[0]
		var mo: int = l[1]
		o.append(_od("Loan %s / %d mo (%s per month)" % [UIU.money(amt), mo, UIU.money(EconomyManager.loan_monthly(amt, mo))], amt > EconomyManager.max_loan(), func():
			EconomyManager.take_loan(amt, mo)
			open_building(b)))
	for i in e.loans.size():
		var idx: int = i
		var L = e.loans[i]
		o.append(_o("Repay loan early: %s left (%d mo)" % [UIU.money(L.remaining), int(L.months_left)], func():
			EconomyManager.repay_loan(idx)
			open_building(b)))
	return o

func _realestate(b: Dictionary) -> Array:
	_body += "\nProperty market index: %.1f%% of base. Visit any listed home to rent or buy." % (float(EconomyManager.st().property_index) * 100.0)
	var o: Array = []
	for pid in GameManager.s.owned:
		var p = GameManager.idx.properties[pid]
		var id: String = pid
		o.append(_od("Sell %s (%s)" % [p.name, UIU.money(p.price * float(EconomyManager.st().property_index) * 0.95)], id == GameManager.s.home or not BusinessManager.at_prop(id).is_empty(), func():
			EconomyManager.add_money(p.price * float(EconomyManager.st().property_index) * 0.95)
			GameManager.s.owned.erase(id)
			BusinessManager.list().size()
			GameManager.notify("Sold %s." % p.name)
			open_building(b)))
	return o

func _dealer(b: Dictionary) -> Array:
	var o: Array = []
	for v in GameManager.data.vehicles:
		var vd: Dictionary = v
		var cost := EconomyManager.price(vd.price)
		var owned := false
		for ov in GameManager.s.vehicles:
			if ov.id == vd.id: owned = true
		o.append(_od("%s - %s (speed x%.1f)" % [vd.name, UIU.money(cost), vd.speed], owned, func():
			if EconomyManager.spend(cost):
				GameManager.s.vehicles.append({"id": vd.id, "fuel": 100.0, "condition": 100.0})
				if GameManager.s.active_vehicle == "": GameManager.s.active_vehicle = vd.id
				GameManager.notify("You bought a %s! Press V to ride/drive." % vd.name)
				GameManager.check_achievements()
			open_building(b)))
	for ov in GameManager.s.vehicles:
		var vv: Dictionary = ov
		var vd = GameManager.idx.vehicles[vv.id]
		var val: float = vd.price * 0.55 * float(vv.condition) / 100.0
		o.append(_o("Sell %s for %s" % [vd.name, UIU.money(val)], func():
			EconomyManager.add_money(val)
			GameManager.s.vehicles.erase(vv)
			if GameManager.s.active_vehicle == vv.id: GameManager.s.active_vehicle = ""
			open_building(b)))
	return o

func _gas(b: Dictionary) -> Array:
	var v := GameManager.active_vehicle()
	if v.is_empty() or GameManager.idx.vehicles[v.id].fuel_use <= 0:
		_body += "\nYou have no motorized vehicle equipped."
		return []
	var missing := 100.0 - float(v.fuel)
	var cost := EconomyManager.price(0.5) * missing
	_body += "\nFuel: %d%%" % int(v.fuel)
	return [_od("Fill up (%s)" % UIU.money(cost), missing < 1.0, func():
		if EconomyManager.spend(cost): v.fuel = 100.0
		open_building(b))]

# ---- education & jobs ------------------------------------------------------------
func _school(b: Dictionary) -> Array:
	var gs = GameManager.s
	var o: Array = []
	_body += "\nQualifications: %s" % (", ".join(gs.education.map(func(q): return CareerManager.qual_name(q))) if not gs.education.is_empty() else "none")
	for c in GameManager.data.courses:
		var cd: Dictionary = c
		if cd.school != b.type or GameManager.has_qual(cd.id): continue
		if gs.enrolled.has(cd.id):
			o.append(_o("Attend class: %s (%d/%d, 4h)" % [cd.name, int(gs.enrolled[cd.id]), int(cd.sessions)], func():
				_say(CareerManager.attend(cd.id), func(): open_building(b))))
		else:
			o.append(_o("Enroll: %s - %s, %d classes" % [cd.name, UIU.money(EconomyManager.price(cd.cost)), int(cd.sessions)], func():
				CareerManager.enroll(cd.id)
				open_building(b)))
	return o

func _job_options(b: Dictionary) -> Array:
	var o: Array = []
	var j := CareerManager.current_job()
	if not j.is_empty() and j.workplace == b.type:
		_body += "\nYour job: %s (%s/hr, %02d:00-%02d:00)" % [j.title, UIU.money(j.hourly * EconomyManager.wage_index()), j.start, j.end]
		o.append(_o("Work your shift", func(): _say(CareerManager.work_shift(), func(): open_building(b))))
		o.append(_o("Resign", func():
			CareerManager.resign()
			open_building(b)))
	o.append(_o("Browse jobs here…", func(): _job_list(b)))
	return o

func _job_list(b: Dictionary) -> void:
	var o: Array = []
	for jd in GameManager.data.jobs:
		var j: Dictionary = jd
		if j.workplace != b.type or j.id == GameManager.s.job: continue
		var prob := CareerManager.req_problem(j)
		o.append(_od("%s (%s) %s/hr%s" % [j.title, j.level, UIU.money(j.hourly * EconomyManager.wage_index()), "" if prob == "" else "  [" + prob + "]"], prob != "", func():
			CareerManager.apply(j.id)
			open_building(b)))
	o.append(_o("Back", func(): open_building(b)))
	GameManager.dialog("Open Positions", "Requirements are shown in brackets. Promotions come from working shifts.", o)

# ---- business --------------------------------------------------------------------
func _unit(b: Dictionary) -> Array:
	var p = GameManager.idx.properties[b.prop]
	var biz := BusinessManager.at(b.id)
	if not biz.is_empty():
		return [_o("Manage %s…" % biz.name, func(): business_menu(biz))]
	_body += "\n%s\nRent %s/mo or buy for %s." % [p.desc, UIU.money(EconomyManager.price(p.rent)), UIU.money(EconomyManager.price(p.price))]
	var o: Array = []
	for bd in GameManager.data.businesses:
		var d: Dictionary = bd
		o.append(_o("Start a %s (setup %s, needs %s %d)" % [d.name, UIU.money(EconomyManager.price(d.setup + d.equipment)), d.skill, int(d.min_skill)], func(): _confirm_business(b, d)))
	return o

func _confirm_business(b: Dictionary, d: Dictionary) -> void:
	var p = GameManager.idx.properties[b.prop]
	GameManager.dialog("Start %s" % d.name, "Choose how to take the property.", [
		_o("Rent unit (setup + first month: %s)" % UIU.money(EconomyManager.price(d.setup + d.equipment) + EconomyManager.price(p.rent)), func():
			BusinessManager.create(d.id, b.id, false)
			open_building(b)),
		_o("Buy unit (setup + %s)" % UIU.money(EconomyManager.price(p.price)), func():
			BusinessManager.create(d.id, b.id, true)
			open_building(b)),
		_o("Back", func(): open_building(b))])

func business_menu(biz: Dictionary) -> void:
	var d = GameManager.idx.businesses[biz.type]
	var b = GameManager.idx.buildings[biz.loc]
	var body := "%s | %s\nStatus: %s | Employees: %d (needs %d) | Stock: %d | Price: x%.2f | Reputation: %d\nCash: %s | Last day: %d customers, %s revenue\nLifetime revenue: %s | Profit: %s" % [
		biz.name, "owned property" if biz.owned else "rented", "OPEN" if biz.open else "CLOSED", int(biz.employees), int(d.staff_needed), int(biz.stock),
		float(biz.price_mult), int(biz.reputation), UIU.money(biz.cash), int(biz.last_customers), UIU.money(biz.last_revenue), UIU.money(biz.revenue_total), UIU.money(biz.profit_total)]
	var again := func(): business_menu(biz)
	var o: Array = [
		_o("Hire employee (%s fee, %s/mo)" % [UIU.money(EconomyManager.price(250)), UIU.money(EconomyManager.price(d.wage))], func():
			BusinessManager.hire(biz)
			again.call()),
		_od("Fire an employee", int(biz.employees) <= 0, func():
			BusinessManager.fire(biz)
			again.call()),
		_o("Buy 100 stock (%s)" % UIU.money(100 * d.unit_cost * float(EconomyManager.st().inflation)), func():
			BusinessManager.buy_stock(biz, 100)
			again.call()),
		_o("Buy 500 stock", func():
			BusinessManager.buy_stock(biz, 500)
			again.call()),
		_o("Auto-restock from cash: %s" % ("ON" if biz.auto_restock else "OFF"), func():
			biz.auto_restock = not biz.auto_restock
			again.call()),
		_o("Collect cash (%s)" % UIU.money(biz.cash), func():
			GameManager.notify(BusinessManager.collect(biz))
			again.call()),
		_o("Close business" if biz.open else "Open for business", func():
			GameManager.notify(BusinessManager.set_open(biz, not biz.open))
			again.call()),
		_o("Sell business (%s)" % UIU.money(BusinessManager.value_of(biz)), func():
			BusinessManager.sell(biz)
			open_building(b))]
	for pm in [0.8, 0.9, 1.0, 1.1, 1.25, 1.5]:
		var m: float = pm
		o.append(_od("Set prices x%.2f" % m, is_equal_approx(float(biz.price_mult), m), func():
			biz.price_mult = m
			again.call()))
	o.append(_o("Back", func(): open_building(b)))
	GameManager.dialog(biz.name, body, o)

# ---- people ----------------------------------------------------------------------
func _who_here(b: Dictionary) -> Array:
	var o: Array = []
	for id in NPCManager.npcs_at(b.id):
		var nid: String = id
		o.append(_o("Talk to %s (%s)" % [RelationshipManager.npc_data(nid).name, RelationshipManager.level_name(RelationshipManager.value(nid))], func(): open_npc(nid)))
	return o

func open_npc(id: String, note := "") -> void:
	var n = RelationshipManager.npc_data(id)
	var r := RelationshipManager.rec(id)
	r.met = true
	var mem := ""
	if r.memory.size() > 0: mem = "\nLast memory: %s" % r.memory[r.memory.size() - 1]
	var body := "%s, %d - %s (%s)\nRelationship: %s (%d)%s%s%s" % [n.name, int(n.age), n.job, n.personality, RelationshipManager.level_name(float(r.v)), int(r.v),
		("  |  " + str(r.stage).capitalize()) if r.stage != "none" else "", mem, ("\n\n" + note) if note != "" else ""]
	var again := func(txt: String): open_npc(id, txt)
	var o: Array = [
		_o("Chat (15m)", func(): again.call(RelationshipManager.talk(id))),
		_o("Eat together (%s, 1h)" % UIU.money(EconomyManager.price(18)), func(): again.call(RelationshipManager.eat_together(id))),
		_o("Help them out (2h)", func(): again.call(RelationshipManager.help(id))),
		_o("Give a gift…", func(): _gift_menu(id)),
		_o("Argue", func(): again.call(RelationshipManager.argue(id))),
		_o("Apologize", func(): again.call(RelationshipManager.apologize(id)))]
	if n.romance_ok:
		match r.stage:
			"none": o.append(_o("Ask on a date", func(): again.call(RelationshipManager.ask_out(id))))
			"dating":
				o.append(_o("Go on a date (%s, 3h)" % UIU.money(EconomyManager.price(50)), func(): again.call(RelationshipManager.date(id))))
				o.append(_o("Make it official", func(): again.call(RelationshipManager.make_official(id))))
			"relationship":
				o.append(_o("Go on a date (%s, 3h)" % UIU.money(EconomyManager.price(50)), func(): again.call(RelationshipManager.date(id))))
				o.append(_o("Ask to move in", func(): again.call(RelationshipManager.move_in(id))))
			"living":
				o.append(_o("Go on a date", func(): again.call(RelationshipManager.date(id))))
				o.append(_o("Propose (ring %s)" % UIU.money(EconomyManager.price(2000)), func(): again.call(RelationshipManager.propose(id))))
			"married":
				o.append(_od("Have a child", not RelationshipManager.can_have_child(id), func(): again.call(RelationshipManager.have_child(id))))
		if r.stage != "none": o.append(_o("Break up", func(): again.call(RelationshipManager.breakup(id))))
	GameManager.dialog(n.name, body, o)

func _gift_menu(id: String) -> void:
	var o: Array = []
	for item_id in GameManager.s.inventory:
		var it = GameManager.idx.items.get(item_id)
		if it != null and it.has("gift"):
			var iid: String = item_id
			o.append(_o("%s x%d" % [it.name, int(GameManager.s.inventory[iid])], func(): open_npc(id, RelationshipManager.gift(id, iid))))
	o.append(_o("Back", func(): open_npc(id)))
	GameManager.dialog("Give a gift", "Buy gifts at shops (flowers, chocolates, perfume, headphones...).", o)
