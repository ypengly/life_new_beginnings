extends Node
## Player-owned businesses. They keep simulating every day, wherever the player is. State: s.business.

func st() -> Dictionary: return GameManager.s.business

func init_state() -> void:
	GameManager.s.business = {"list": [], "profit_sold": 0.0}

func _ready() -> void:
	TimeManager.day_changed.connect(_on_day)
	TimeManager.month_changed.connect(_on_month)

func list() -> Array: return GameManager.s.business.list if GameManager.s.has("business") else []
func count() -> int: return list().size()

func at(loc_id: String) -> Dictionary:
	for b in list():
		if b.loc == loc_id: return b
	return {}

func at_prop(prop_id: String) -> Dictionary:
	for b in list():
		if GameManager.idx.buildings[b.loc].prop == prop_id: return b
	return {}

func total_profit() -> float:
	if not GameManager.s.has("business"): return 0.0
	var t := float(st().profit_sold)
	for b in list(): t += float(b.profit_total)
	return t

func total_value() -> float:
	var t := 0.0
	for b in list(): t += value_of(b)
	return t

func value_of(b: Dictionary) -> float:
	var d = GameManager.idx.businesses[b.type]
	return d.equipment * 0.5 + maxf(float(b.cash), 0.0) + float(b.stock) * d.unit_cost * 0.8

func create(type_id: String, loc_id: String, buy_property: bool) -> bool:
	var d = GameManager.idx.businesses[type_id]
	var prop = GameManager.idx.properties[GameManager.idx.buildings[loc_id].prop]
	if not at(loc_id).is_empty(): return false
	if float(GameManager.s.skills.get(d.skill, 0.0)) < float(d.min_skill):
		GameManager.notify("You need %s %d to run this business." % [d.skill.capitalize(), int(d.min_skill)])
		return false
	var cost := float(EconomyManager.price(d.setup + d.equipment))
	cost += float(EconomyManager.price(prop.price)) if buy_property else float(EconomyManager.price(prop.rent))
	if EconomyManager.money() < cost:
		GameManager.notify("You need %s to start (equipment, setup and %s)." % [GameManager.UIU.money(cost), "property" if buy_property else "first month's rent"])
		return false
	EconomyManager.spend(cost)
	if buy_property: GameManager.s.owned.append(prop.id)
	st().list.append({"uid": randi(), "type": type_id, "loc": loc_id, "name": d.name, "employees": 0, "price_mult": 1.0, "stock": 0,
		"cash": 0.0, "reputation": 30.0, "revenue_total": 0.0, "profit_total": 0.0, "customers_total": 0, "open": false,
		"owned": buy_property, "auto_restock": false, "month_revenue": 0.0, "month_costs": 0.0, "last_customers": 0, "last_revenue": 0.0})
	GameManager.s.flags["had_business"] = true
	GameManager.notify("You founded %s! Hire staff, buy stock, then open the doors." % d.name)
	GameManager.check_achievements()
	return true

func hire(b: Dictionary) -> void:
	if EconomyManager.spend(EconomyManager.price(250)): b.employees = int(b.employees) + 1

func fire(b: Dictionary) -> void:
	b.employees = maxi(int(b.employees) - 1, 0)

func buy_stock(b: Dictionary, units: int) -> void:
	var d = GameManager.idx.businesses[b.type]
	if EconomyManager.spend(units * d.unit_cost * float(EconomyManager.st().inflation)):
		b.stock = int(b.stock) + units

func set_open(b: Dictionary, v: bool) -> String:
	var d = GameManager.idx.businesses[b.type]
	if v and (int(b.employees) < 1 or int(b.stock) < 20): return "Hire at least 1 employee and stock 20+ units first."
	b.open = v
	return "Open for business!" if v else "Closed."

func collect(b: Dictionary) -> String:
	var cash := float(b.cash)
	if cash <= 0.0: return "No cash to collect."
	var tax := snappedf(cash * 0.15, 0.01)
	b.cash = 0.0
	EconomyManager.add_money(cash - tax)
	return "Collected %s (15%% business tax: %s)." % [GameManager.UIU.money(cash - tax), GameManager.UIU.money(tax)]

func sell(b: Dictionary) -> void:
	var v := value_of(b)
	st().profit_sold = float(st().profit_sold) + float(b.profit_total)
	EconomyManager.add_money(v)
	if b.owned: GameManager.s.owned.erase(GameManager.idx.buildings[b.loc].prop)
	st().list.erase(b)
	GameManager.notify("Business sold for %s." % GameManager.UIU.money(v))

func _demand_index() -> float:
	return clampf(1.0 + float(EconomyManager.st().mood) * 0.04, 0.7, 1.3)

func _on_day(_d: int) -> void:
	if not GameManager.in_game or not GameManager.s.has("business"): return
	for b in list():
		var d = GameManager.idx.businesses[b.type]
		b.last_customers = 0
		b.last_revenue = 0.0
		if not b.open: continue
		var infl := float(EconomyManager.st().inflation)
		var price_mult := float(b.price_mult)
		var skill_bonus := 1.0 + float(GameManager.s.skills.get(d.skill, 0.0)) / 200.0 + GameManager.perk("biz_bonus", 0.0)
		var demand: float = d.base_customers * (0.6 + float(b.reputation) / 100.0 * 0.8) * pow(price_mult, -1.5) * _demand_index() * skill_bonus * randf_range(0.85, 1.15)
		var capacity: float = int(b.employees) * d.cap_per_staff
		var want := mini(int(demand), int(capacity))
		if b.auto_restock and int(b.stock) < want * 3:
			var units := want * 7
			var cost: float = units * d.unit_cost * infl
			if float(b.cash) >= cost:
				b.cash = float(b.cash) - cost
				b.stock = int(b.stock) + units
				b.month_costs = float(b.month_costs) + cost
		var sold := mini(want, int(b.stock))
		var revenue: float = sold * d.avg_price * price_mult * infl
		b.stock = int(b.stock) - sold
		b.cash = float(b.cash) + revenue
		b.revenue_total = float(b.revenue_total) + revenue
		b.month_revenue = float(b.month_revenue) + revenue
		b.customers_total = int(b.customers_total) + sold
		b.last_customers = sold
		b.last_revenue = revenue
		var rep := float(b.reputation)
		if sold < int(demand): rep -= 0.5 # turned customers away
		if price_mult > 1.3: rep -= 0.3
		elif price_mult < 0.95: rep += 0.2
		rep += 0.15 if sold > 0 else -0.2
		b.reputation = clampf(rep, 0.0, 100.0)

func _on_month(_m: int) -> void:
	if not GameManager.in_game or not GameManager.s.has("business"): return
	for b in list().duplicate():
		var d = GameManager.idx.businesses[b.type]
		var prop = GameManager.idx.properties[GameManager.idx.buildings[b.loc].prop]
		var wages: float = int(b.employees) * EconomyManager.price(d.wage)
		var rent: float = 0.0 if b.owned else float(EconomyManager.price(prop.rent))
		var due := wages + rent
		if float(b.cash) >= due:
			b.cash = float(b.cash) - due
		else:
			b.cash = 0.0
			if int(b.employees) > 0:
				b.employees = int(b.employees) - 1
				b.reputation = maxf(float(b.reputation) - 5.0, 0.0)
				GameManager.notify("%s couldn't pay everyone: an employee quit." % b.name)
			if rent > 0.0 and float(b.cash) <= 0.0 and int(b.employees) == 0:
				b.open = false
				GameManager.notify("%s is closed: it can't cover wages and rent. Fund it by buying stock/cash." % b.name)
		b.profit_total = float(b.profit_total) + float(b.month_revenue) - float(b.month_costs) - due
		GameManager.notify("%s monthly: revenue %s." % [b.name, GameManager.UIU.money(float(b.month_revenue))])
		b.month_revenue = 0.0
		b.month_costs = 0.0
