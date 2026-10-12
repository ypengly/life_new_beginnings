extends SceneTree
## Run:  godot --headless --path . -s tests/test_runner.gd
## Autoloads are looked up dynamically because this runs as a plain SceneTree script.

var fails := 0

func check(cond: bool, label: String) -> void:
	if cond: print("  PASS  ", label)
	else:
		print("  FAIL  ", label)
		fails += 1

func _initialize() -> void:
	var G = root.get_node("GameManager")
	var E = root.get_node("EconomyManager")
	var T = root.get_node("TimeManager")
	var C = root.get_node("CareerManager")
	var B = root.get_node("BusinessManager")
	var R = root.get_node("RelationshipManager")
	var S = root.get_node("SaveManager")
	var NM = root.get_node("NPCManager")
	G.new_game("Tester", "average", {})

	print("Economy")
	var m0: float = E.money()
	check(not E.spend(m0 + 1.0), "cannot overspend")
	check(E.money() == m0, "money unchanged after failed spend")
	check(not E.spend(-50.0), "negative spend rejected")
	E.add_money(-100.0)
	check(E.money() == m0, "negative add rejected (no duplication)")
	E.add_money(1000.0)
	check(E.money() == m0 + 1000.0, "add money")
	check(E.spend_up_to(1.0e9) <= m0 + 1000.0 and E.money() >= 0.0, "spend_up_to never negative")
	E.add_money(5000.0)
	var dep0: float = E.money()
	E.deposit(1000.0)
	E.withdraw(1000.0)
	check(is_equal_approx(E.money(), dep0), "deposit/withdraw round-trip")
	var mm: float = E.money()
	check(E.take_loan(1000.0, 12), "loan approved")
	check(E.money() == mm + 1000.0 and E.total_debt() > 1000.0, "loan pays out, debt includes interest")
	check(not E.take_loan(9999999.0, 12), "huge loan refused")
	E.buy_stock("CITY", 2)
	check(E.shares("CITY") == 2, "buy stock")
	E.sell_stock("CITY", 5)
	check(E.shares("CITY") == 0, "sell clamps to holdings")

	print("Time")
	var d0: int = T.get_day()
	T.advance(1440)
	check(T.get_day() == d0 + 1, "advance one day")
	check(T.clock_text().length() > 0, "clock text")

	print("Careers")
	check(C.req_problem(C.job_data("cashier")) == "", "cashier has no requirements")
	check(C.req_problem(C.job_data("cto")) != "", "cto locked")
	C.apply("cashier")
	check(G.s.job == "cashier", "hired as cashier")
	T.total_minutes = (T.get_day() * 1440) + 9 * 60
	var before: float = E.money()
	C.work_shift()
	check(E.money() > before, "shift pays")

	print("Business")
	G.s.skills.cooking = 30.0
	E.add_money(50000.0)
	check(B.create("coffee_shop", "unit_shop_a", false), "create business")
	var biz = B.at("unit_shop_a")
	B.hire(biz); B.hire(biz); B.buy_stock(biz, 200)
	check(B.set_open(biz, true) == "Open for business!", "open business")
	T.advance(1440)
	check(float(biz.cash) > 0.0, "business earns while player is away")

	print("Relationships")
	R.add_rel("sarah", 50.0)
	check(R.ask_out("sarah").find("yes") >= 0, "ask out after friendship")
	check(R.level_name(50.0) == "Friend", "level names")

	print("NPC schedules")
	T.total_minutes = T.get_day() * 1440 + 9 * 60
	check(NM.target_loc(G.idx.npcs["sarah"]) in G.idx.buildings, "schedule resolves to a real building")

	print("Save / load")
	check(S.save(1), "save slot 1")
	var money_saved: float = G.s.money
	G.s.money = 1.0
	check(S.load_slot(1), "load slot 1")
	check(G.s.money == money_saved, "money restored")
	var f := FileAccess.open(S.path(2), FileAccess.WRITE)
	f.store_string("{ not valid json")
	f.close()
	check(not S.load_slot(2), "corrupted save rejected")
	S.delete_slot(1); S.delete_slot(2)

	print("\n%s (%d failures)" % ["ALL TESTS PASSED" if fails == 0 else "TESTS FAILED", fails])
	quit(1 if fails > 0 else 0)
