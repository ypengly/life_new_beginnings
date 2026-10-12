extends PanelContainer
## Smartphone: Stats, Jobs, Bank, Invest, People, Property, Map, Items, Log.
const UIU = preload("res://scripts/ui/ui_util.gd")
const LineChart = preload("res://scripts/ui/line_chart.gd")
const MapView = preload("res://scripts/ui/map_view.gd")
const TABS := ["Stats", "Jobs", "Bank", "Invest", "People", "Property", "Map", "Items", "Log"]
var tabs: TabContainer
var boxes := {}
var chart_stock := "CITY"
var _t := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(760, 560)
	tabs = TabContainer.new()
	add_child(tabs)
	for n in TABS:
		var sc := ScrollContainer.new()
		sc.name = n
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(vb)
		tabs.add_child(sc)
		boxes[n] = vb
	tabs.tab_changed.connect(func(_i): refresh())
	EconomyManager.money_changed.connect(func(): if visible: refresh())

func open(tab := "") -> void:
	show()
	if tab != "" and TABS.has(tab): tabs.current_tab = TABS.find(tab)
	refresh()

func _process(delta: float) -> void:
	_t += delta
	if visible and _t > 1.0:
		_t = 0.0
		if tabs.current_tab in [0, 6]: refresh()

func refresh() -> void:
	var name: String = TABS[tabs.current_tab]
	var box: VBoxContainer = boxes[name]
	UIU.clear(box)
	call("_tab_" + name.to_lower(), box)

func _tab_stats(box: VBoxContainer) -> void:
	var gs = GameManager.s
	UIU.heading(box, "%s - Age %d" % [gs.name, TimeManager.get_age()])
	UIU.row(box, "Money / Net worth", "%s / %s" % [UIU.money(EconomyManager.money()), UIU.money(EconomyManager.net_worth())])
	var j := CareerManager.current_job()
	UIU.row(box, "Career", "%s (%s)" % [j.title, j.level] if not j.is_empty() else "Unemployed")
	UIU.row(box, "Reputation / Freelance rep", "%d / %d" % [int(gs.reputation), int(gs.freelance_rep)])
	UIU.row(box, "Education", ", ".join(gs.education.map(func(q): return CareerManager.qual_name(q))) if not gs.education.is_empty() else "none")
	var home = GameManager.idx.properties.get(gs.home)
	UIU.row(box, "Home", home.name if home != null else "Homeless")
	UIU.row(box, "Businesses / Vehicles / Children", "%d / %d / %d" % [BusinessManager.count(), gs.vehicles.size(), gs.children.size()])
	var ch := LineChart.new()
	ch.custom_minimum_size = Vector2(640, 110)
	ch.points = gs.history
	ch.caption = "Net worth"
	box.add_child(ch)
	for k in ["health", "energy", "hunger", "hygiene", "happiness", "stress", "fitness", "intelligence", "social", "charisma", "discipline", "creativity"]:
		UIU.bar(box, k.capitalize(), GameManager.stat(k), Color("#e05d5d") if k == "stress" else Color("#5dade0"))
	UIU.row(box, "Experience", str(int(GameManager.stat("experience"))))
	box.add_child(UIU.label("Skills", 18, Color("#ffd166")))
	for k in GameManager.SKILL_KEYS: UIU.bar(box, k.capitalize(), float(gs.skills[k]), Color("#8ccf6a"))
	box.add_child(UIU.label("Achievements (%d/%d)" % [gs.achievements.size(), GameManager.ACHIEVEMENTS.size()], 18, Color("#ffd166")))
	for id in GameManager.ACHIEVEMENTS:
		var got: bool = id in gs.achievements
		box.add_child(UIU.label("%s %s - %s" % ["[x]" if got else "[ ]", GameManager.ACHIEVEMENTS[id][0], GameManager.ACHIEVEMENTS[id][1]], 14, Color.WHITE if got else Color(1, 1, 1, 0.45)))
	if TimeManager.get_age() >= 30:
		box.add_child(UIU.button("Retire & see your ending", func(): GameManager.dialog("Your Life Story", "Ending: %s\n\nNet worth: %s, age %d." % [GameManager.ending_title(), UIU.money(EconomyManager.net_worth()), TimeManager.get_age()], [])))

func _tab_jobs(box: VBoxContainer) -> void:
	var gs = GameManager.s
	UIU.heading(box, "Jobs")
	var j := CareerManager.current_job()
	if j.is_empty(): box.add_child(UIU.label("Unemployed. Visit a workplace to apply."))
	else:
		box.add_child(UIU.label("%s at a %s, %02d:00-%02d:00, %s/hr. Shifts in role: %d/%d. Promotes to: %s" % [j.title, j.workplace.replace("_", " "), j.start, j.end,
			UIU.money(j.hourly * EconomyManager.wage_index()), int(gs.job_shifts), int(j.promo_shifts), CareerManager.job_data(j.promotes_to).get("title", "top of track")]))
	box.add_child(UIU.label("All jobs (apply in person at the matching workplace; you can also apply here)", 14, Color("#ffd166")))
	for jd in GameManager.data.jobs:
		var jj: Dictionary = jd
		var prob := CareerManager.req_problem(jj)
		var h := HBoxContainer.new()
		var l := UIU.label("%s [%s] %s/hr @%s %s" % [jj.title, jj.level, UIU.money(jj.hourly), jj.workplace.replace("_", " "), "" if prob == "" else "- " + prob], 13, Color.WHITE if prob == "" else Color(1, 1, 1, 0.5))
		l.custom_minimum_size.x = 540
		h.add_child(l)
		var b := UIU.button("Apply", func():
			CareerManager.apply(jj.id)
			refresh())
		b.disabled = prob != "" or jj.id == gs.job
		h.add_child(b)
		box.add_child(h)

func _tab_bank(box: VBoxContainer) -> void:
	var e = EconomyManager.st()
	UIU.heading(box, "Banking")
	UIU.row(box, "Cash", UIU.money(EconomyManager.money()))
	UIU.row(box, "Savings (0.3%/month)", UIU.money(e.bank))
	UIU.row(box, "Credit score", str(int(e.credit)))
	UIU.row(box, "Debt", UIU.money(EconomyManager.total_debt()))
	UIU.row(box, "This month: income / expenses", "%s / %s" % [UIU.money(e.income_month), UIU.money(e.expense_month)])
	UIU.row(box, "Inflation index", "%.1f%%" % (float(e.inflation) * 100.0))
	box.add_child(UIU.label("Loans", 18, Color("#ffd166")))
	for L in e.loans: UIU.row(box, "Left %s, %s/mo" % [UIU.money(L.remaining), UIU.money(L.monthly)], "%d months, missed %d" % [int(L.months_left), int(L.missed)])
	box.add_child(UIU.label("Visit a bank branch to deposit, borrow or repay.", 13, Color(1, 1, 1, 0.6)))

func _tab_invest(box: VBoxContainer) -> void:
	var e = EconomyManager.st()
	UIU.heading(box, "Investments")
	var ch := LineChart.new()
	ch.custom_minimum_size = Vector2(640, 130)
	ch.points = e.history[chart_stock]
	ch.caption = chart_stock
	box.add_child(ch)
	for sd in GameManager.data.stocks:
		var id: String = sd.id
		var hist: Array = e.history[id]
		var chg := 0.0 if hist.size() < 2 else (float(hist[-1]) / float(hist[-2]) - 1.0) * 100.0
		var h := HBoxContainer.new()
		var l := UIU.label("%s  $%.2f (%+.1f%%)  owned %d" % [sd.name, float(e.prices[id]), chg, EconomyManager.shares(id)], 14, Color("#7be08b") if chg >= 0 else Color("#ff8080"))
		l.custom_minimum_size.x = 340
		h.add_child(l)
		h.add_child(UIU.button("Chart", func():
			chart_stock = id
			refresh()))
		h.add_child(UIU.button("Buy 1", func():
			EconomyManager.buy_stock(id, 1)
			refresh()))
		h.add_child(UIU.button("Buy 10", func():
			EconomyManager.buy_stock(id, 10)
			refresh()))
		var sell := UIU.button("Sell all", func():
			EconomyManager.sell_stock(id, EconomyManager.shares(id))
			refresh())
		sell.disabled = EconomyManager.shares(id) <= 0
		h.add_child(sell)
		box.add_child(h)
	box.add_child(UIU.label("Hold = do nothing. Prices follow the economy, market events and random news.", 13, Color(1, 1, 1, 0.6)))

func _tab_people(box: VBoxContainer) -> void:
	UIU.heading(box, "Contacts & Relationships")
	var any := false
	for n in GameManager.data.npcs:
		var r := RelationshipManager.rec(n.id)
		if not r.met: continue
		any = true
		var nid: String = n.id
		var h := HBoxContainer.new()
		var l := UIU.label("%s - %s (%d)%s" % [n.name, RelationshipManager.level_name(float(r.v)), int(r.v), "" if r.stage == "none" else " - " + str(r.stage)], 14)
		l.custom_minimum_size.x = 430
		h.add_child(l)
		h.add_child(UIU.button("Open", func():
			hide()
			ActivityManager.open_npc(nid)))
		box.add_child(h)
	if not any: box.add_child(UIU.label("You haven't met anyone yet. Talk to people on the street or at cafes."))

func _tab_property(box: VBoxContainer) -> void:
	var gs = GameManager.s
	UIU.heading(box, "Properties")
	var home = GameManager.idx.properties.get(gs.home)
	UIU.row(box, "Home", home.name if home != null else "Homeless")
	for p in gs.owned: UIU.row(box, "Owned: " + GameManager.idx.properties[p].name, UIU.money(GameManager.idx.properties[p].price * float(EconomyManager.st().property_index)))
	box.add_child(UIU.label("Vehicles", 18, Color("#ffd166")))
	for v in gs.vehicles:
		var vv: Dictionary = v
		var d = GameManager.idx.vehicles[vv.id]
		var h := HBoxContainer.new()
		var l := UIU.label("%s - fuel %d%%, condition %d%%%s" % [d.name, int(vv.fuel), int(vv.condition), " (active)" if gs.active_vehicle == vv.id else ""], 14)
		l.custom_minimum_size.x = 440
		h.add_child(l)
		h.add_child(UIU.button("Use", func():
			gs.active_vehicle = vv.id
			refresh()))
		box.add_child(h)
	box.add_child(UIU.label("Businesses", 18, Color("#ffd166")))
	for b in BusinessManager.list():
		var bb: Dictionary = b
		var h := HBoxContainer.new()
		var l := UIU.label("%s - cash %s, %s" % [bb.name, UIU.money(bb.cash), "open" if bb.open else "closed"], 14)
		l.custom_minimum_size.x = 440
		h.add_child(l)
		h.add_child(UIU.button("Manage", func():
			hide()
			ActivityManager.business_menu(bb)))
		box.add_child(h)

func _tab_map(box: VBoxContainer) -> void:
	UIU.heading(box, "City Map (click a discovered location to fast travel: 15 min)")
	var mv := MapView.new()
	mv.custom_minimum_size = Vector2(680, 300)
	mv.travel_requested.connect(func(id):
		hide()
		get_tree().current_scene.teleport_to(id))
	box.add_child(mv)
	box.add_child(UIU.label("Red = you, blue = NPCs, white = discovered places. Districts unlock with net worth.", 13, Color(1, 1, 1, 0.6)))

func _tab_items(box: VBoxContainer) -> void:
	var gs = GameManager.s
	UIU.heading(box, "Inventory")
	if gs.inventory.is_empty(): box.add_child(UIU.label("Empty."))
	for id in gs.inventory:
		var it = GameManager.idx.items.get(id)
		if it == null: continue
		var iid: String = id
		var h := HBoxContainer.new()
		var l := UIU.label("%s x%d" % [it.name, int(gs.inventory[id])], 15)
		l.custom_minimum_size.x = 300
		h.add_child(l)
		if it.get("usable", false):
			var label := "Equip" if it.cat == "clothing" else "Use"
			h.add_child(UIU.button(label, func():
				if it.cat == "clothing":
					gs.equipped[it.slot] = iid
					GameManager.notify("Equipped %s." % it.name)
				elif GameManager.remove_item(iid):
					GameManager.apply_effects(it.effects)
				refresh()))
		box.add_child(h)
	if not gs.equipped.is_empty():
		box.add_child(UIU.label("Wearing: " + ", ".join(gs.equipped.values().map(func(i): return GameManager.idx.items[i].name)) + "  (charisma +%d)" % int(GameManager.charisma_bonus()), 14))

func _tab_log(box: VBoxContainer) -> void:
	UIU.heading(box, "Notifications")
	for n in GameManager.s.notifications: box.add_child(UIU.label(n, 13))
