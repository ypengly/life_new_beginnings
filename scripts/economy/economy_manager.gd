extends Node
## Money, prices, inflation, banking, loans and the stock market. State lives in GameManager.s.economy.

signal money_changed
const MAX_MONEY := 1.0e12

func st() -> Dictionary: return GameManager.s.economy

func init_state() -> void:
	var prices := {}
	var hist := {}
	for sd in GameManager.data.stocks:
		prices[sd.id] = float(sd.base)
		hist[sd.id] = [float(sd.base)]
	GameManager.s.economy = {"inflation": 1.0, "property_index": 1.0, "bank": 0.0, "credit": 650.0, "loans": [], "holdings": {},
		"basis": {}, "prices": prices, "history": hist, "mood": 0.0, "missed_rent": 0, "income_month": 0.0, "expense_month": 0.0, "traded": false}

func _ready() -> void:
	TimeManager.day_changed.connect(_on_day)
	TimeManager.month_changed.connect(_on_month)

# ---------------------------------------------------------------- money API (the ONLY place money changes)
func money() -> float: return float(GameManager.s.money)

func add_money(a: float, _reason := "") -> void:
	if is_nan(a) or is_inf(a) or a <= 0.0: return
	GameManager.s.money = snappedf(minf(money() + a, MAX_MONEY), 0.01)
	st().income_month += a
	money_changed.emit()

func spend(a: float, _reason := "") -> bool:
	if is_nan(a) or is_inf(a) or a < 0.0: return false
	a = snappedf(a, 0.01)
	if money() + 0.001 < a:
		GameManager.notify("Not enough money.")
		AudioManager.play_sfx("error")
		return false
	GameManager.s.money = snappedf(maxf(money() - a, 0.0), 0.01)
	st().expense_month += a
	money_changed.emit()
	return true

func spend_up_to(a: float) -> float:
	var paid := minf(maxf(a, 0.0), money())
	if paid > 0.0:
		GameManager.s.money = snappedf(money() - paid, 0.01)
		st().expense_month += paid
		money_changed.emit()
	return paid

func price(base: float) -> int:
	return int(ceil(base * float(st().inflation) * GameManager.perk("expense_mult")))

func wage_index() -> float: return 1.0 + (float(st().inflation) - 1.0) * 0.8

# ---------------------------------------------------------------- savings
func deposit(a: float) -> void:
	if a > 0.0 and spend(a):
		st().bank = snappedf(float(st().bank) + a, 0.01)

func withdraw(a: float) -> void:
	a = minf(a, float(st().bank))
	if a <= 0.0: return
	st().bank = snappedf(float(st().bank) - a, 0.01)
	GameManager.s.money = snappedf(money() + a, 0.01)
	money_changed.emit()

# ---------------------------------------------------------------- loans
func total_debt() -> float:
	var t := 0.0
	for L in st().loans: t += float(L.remaining)
	return t

func max_loan() -> float:
	return maxf(minf(float(st().credit) * 8.0 + maxf(net_worth(), 0.0) * 0.3, 250000.0) - total_debt(), 0.0)

func offer_rate() -> float: return 0.04 + (850.0 - float(st().credit)) / 850.0 * 0.12

func loan_monthly(amount: float, months: int) -> float:
	return snappedf(amount * (1.0 + offer_rate() * months / 12.0) / months, 0.01)

func take_loan(amount: float, months: int) -> bool:
	if amount <= 0.0 or amount > max_loan() + 0.001:
		GameManager.notify("The bank declined: your credit limit is %s." % GameManager.UIU.money(max_loan()))
		return false
	var total := amount * (1.0 + offer_rate() * months / 12.0)
	st().loans.append({"amount": amount, "remaining": snappedf(total, 0.01), "monthly": loan_monthly(amount, months), "months_left": months, "missed": 0})
	add_money(amount)
	GameManager.notify("Loan approved: %s over %d months." % [GameManager.UIU.money(amount), months])
	return true

func repay_loan(i: int) -> void:
	if i < 0 or i >= st().loans.size(): return
	var L = st().loans[i]
	if spend(float(L.remaining)):
		st().loans.remove_at(i)
		st().credit = minf(float(st().credit) + 10.0, 850.0)
		GameManager.notify("Loan fully repaid.")

# ---------------------------------------------------------------- stocks
func stock_price(id: String) -> float: return float(st().prices[id])

func shares(id: String) -> int: return int(st().holdings.get(id, 0))

func buy_stock(id: String, n: int) -> void:
	if n <= 0: return
	var cost := stock_price(id) * n
	if spend(cost):
		st().holdings[id] = shares(id) + n
		st().basis[id] = float(st().basis.get(id, 0.0)) + cost
		st().traded = true
		GameManager.check_achievements()

func sell_stock(id: String, n: int) -> void:
	n = mini(n, shares(id))
	if n <= 0: return
	var owned := shares(id)
	var avg_basis := float(st().basis.get(id, 0.0)) / owned
	add_money(stock_price(id) * n)
	st().holdings[id] = owned - n
	st().basis[id] = avg_basis * (owned - n)
	if shares(id) <= 0:
		st().holdings.erase(id)
		st().basis.erase(id)

# ---------------------------------------------------------------- time hooks
func _on_day(_d: int) -> void:
	if not GameManager.in_game or not GameManager.s.has("economy"): return
	var e = st()
	for sd in GameManager.data.stocks:
		var p: float = float(e.prices[sd.id])
		var r := randfn(sd.drift + float(e.mood) * 0.01 * sd.beta, sd.vol)
		p = maxf(1.0, snappedf(p * (1.0 + clampf(r, -0.25, 0.25)), 0.01))
		e.prices[sd.id] = p
		var h: Array = e.history[sd.id]
		h.append(p)
		if h.size() > 90: h.pop_front()
	e.mood = float(e.mood) * 0.9
	_vehicle_breakdowns()

func _vehicle_breakdowns() -> void:
	for v in GameManager.s.vehicles:
		var d = GameManager.idx.vehicles[v.id]
		if randf() < (1.0 - d.reliability) * 0.15:
			var cost := price(d.price * 0.04)
			var paid := spend_up_to(cost)
			v.condition = maxf(float(v.condition) - 10.0, 20.0)
			GameManager.notify("Your %s broke down. Repairs: %s." % [d.name, GameManager.UIU.money(paid)])

func _on_month(_m: int) -> void:
	if not GameManager.in_game or not GameManager.s.has("economy"): return
	var e = st()
	e.inflation = float(e.inflation) * (1.0 + randf_range(0.0, 0.004))
	e.property_index = float(e.property_index) * (1.0 + randf_range(-0.012, 0.02))
	e.bank = snappedf(float(e.bank) * 1.003, 0.01) # savings 0.3%/mo (always below the cheapest loan rate -> no arbitrage)
	_pay_housing()
	_pay_loans()
	e.income_month = 0.0
	e.expense_month = 0.0

func _pay_housing() -> void:
	var gs = GameManager.s
	var e = st()
	var p = GameManager.idx.properties.get(gs.home)
	spend_up_to(price(60)) # utilities
	if p != null:
		if gs.home in gs.owned:
			spend_up_to(price(p.maintenance))
		else:
			if spend(price(p.rent)):
				e.missed_rent = 0
			else:
				e.missed_rent = int(e.missed_rent) + 1
				GameManager.change_stat("stress", 15.0)
				GameManager.change_stat("happiness", -10.0)
				GameManager.notify("You could not pay rent (%d/3). Eviction after 3 misses." % int(e.missed_rent))
				if int(e.missed_rent) >= 3:
					gs.home = ""
					e.missed_rent = 0
					GameManager.notify("You were evicted! Find a new place to live.")
	for pid in gs.owned:
		if pid != gs.home: spend_up_to(price(GameManager.idx.properties[pid].maintenance))
	for v in gs.vehicles:
		spend_up_to(price(GameManager.idx.vehicles[v.id].maint))
	spend_up_to(RelationshipManager.family_cost())

func _pay_loans() -> void:
	var e = st()
	for L in e.loans.duplicate():
		if money() >= float(L.monthly) - 0.001:
			spend(float(L.monthly))
			L.remaining = snappedf(maxf(float(L.remaining) - float(L.monthly), 0.0), 0.01)
			L.months_left = int(L.months_left) - 1
			L.missed = 0
			e.credit = minf(float(e.credit) + 2.0, 850.0)
		else:
			L.missed = int(L.missed) + 1
			e.credit = maxf(float(e.credit) - 30.0, 300.0)
			L.remaining = snappedf(float(L.remaining) * 1.03, 0.01)
			GameManager.change_stat("stress", 10.0)
			GameManager.notify("Missed a loan payment (%d/3). Your credit score dropped." % int(L.missed))
			if int(L.missed) >= 3: _repossess(L)
		if int(L.months_left) <= 0 or float(L.remaining) <= 0.01:
			e.loans.erase(L)

func _repossess(L: Dictionary) -> void:
	var gs = GameManager.s
	var seized := 0.0
	for v in gs.vehicles: seized += GameManager.idx.vehicles[v.id].price * 0.5
	if seized > 0.0:
		gs.vehicles.clear()
		gs.active_vehicle = ""
		GameManager.notify("Lenders repossessed your vehicles.")
	else:
		seized = minf(float(st().bank), float(L.remaining))
		st().bank = float(st().bank) - seized
		GameManager.notify("The bank seized your savings to cover the loan.")
	L.remaining = maxf(float(L.remaining) - seized, 0.0)
	L.missed = 0

func net_worth() -> float:
	var gs = GameManager.s
	var e = st()
	var nw := money() + float(e.bank)
	for id in e.holdings: nw += float(e.prices.get(id, 0.0)) * int(e.holdings[id])
	for pid in gs.owned: nw += float(GameManager.idx.properties[pid].price) * float(e.property_index)
	for v in gs.vehicles: nw += GameManager.idx.vehicles[v.id].price * 0.6 * float(v.condition) / 100.0
	nw += BusinessManager.total_value()
	nw -= total_debt()
	return nw
