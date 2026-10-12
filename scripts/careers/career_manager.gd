extends Node
## Jobs, shifts, promotions, education and freelancing.

func _ready() -> void:
	TimeManager.day_changed.connect(_on_day)

func job_data(id: String) -> Dictionary:
	return GameManager.idx.jobs.get(id, {})

func current_job() -> Dictionary: return job_data(GameManager.s.job)

func job_level() -> String:
	var j := current_job()
	return j.level if not j.is_empty() else ""

func qual_name(id: String) -> String:
	var c = GameManager.idx.courses.get(id)
	return c.name if c != null else id

func req_problem(j: Dictionary) -> String:
	var r = j.req
	var gs = GameManager.s
	for sk in r.skills:
		if float(gs.skills.get(sk, 0.0)) < float(r.skills[sk]):
			return "%s %d needed" % [sk.capitalize(), int(r.skills[sk])]
	if r.has("education_any"):
		var ok := false
		for q in r.education_any:
			if GameManager.has_qual(q): ok = true
		if not ok:
			var names := []
			for q in r.education_any: names.append(qual_name(q))
			return "Needs: " + " or ".join(names)
	if float(gs.reputation) < float(r.rep): return "Reputation %d needed" % int(r.rep)
	if GameManager.stat("experience") < float(r.exp): return "Experience %d needed" % int(r.exp)
	return ""

func apply(job_id: String) -> void:
	var j := job_data(job_id)
	var problem := req_problem(j)
	if problem != "":
		GameManager.notify("Application rejected: " + problem)
		return
	GameManager.s.job = job_id
	GameManager.s.job_shifts = 0
	GameManager.s.days_absent = 0
	GameManager.notify("You are now a %s! Shifts: %02d:00-%02d:00 at a %s." % [j.title, j.start, j.end, j.workplace.replace("_", " ")])

func resign() -> void:
	GameManager.s.job = ""
	GameManager.notify("You resigned.")

func work_shift() -> String:
	var j := current_job()
	if j.is_empty(): return "You have no job."
	var h := TimeManager.get_hour()
	if h < int(j.start) or h >= int(j.end):
		return "Your shift runs %02d:00-%02d:00." % [j.start, j.end]
	if GameManager.stat("energy") < 20.0: return "You're too exhausted to work. Get some rest."
	var hours := maxi(int(j.end) - h, 1)
	TimeManager.advance(hours * 60)
	var gross := float(j.hourly) * hours * EconomyManager.wage_index()
	var net := snappedf(gross * 0.88, 0.01) # 12% income tax withheld
	EconomyManager.add_money(net)
	var gs = GameManager.s
	gs.total_earned = float(gs.total_earned) + net
	gs.flags["first_job"] = true
	gs.worked_today = true
	gs.days_absent = 0
	gs.job_shifts = int(gs.job_shifts) + 1
	gs.total_shifts = int(gs.total_shifts) + 1
	gs.reputation = clampf(float(gs.reputation) + 0.4, 0.0, 100.0)
	GameManager.change_stat("energy", -float(j.energy) * hours * GameManager.perk("energy_mult"))
	GameManager.change_stat("stress", float(j.stress) * hours)
	GameManager.change_stat("experience", 3.0)
	if j.skill != "": GameManager.add_skill(j.skill, 2.0)
	GameManager.check_achievements()
	var msg := "Shift done: earned %s (after tax)." % GameManager.UIU.money(net)
	_check_promotion(j)
	return msg

func _check_promotion(j: Dictionary) -> void:
	if j.promotes_to == "" or int(GameManager.s.job_shifts) < int(j.promo_shifts): return
	if GameManager.s.declined_promo == j.promotes_to: return
	var nj := job_data(j.promotes_to)
	if nj.is_empty() or req_problem(nj) != "": return
	GameManager.notify("Your manager has offered you a promotion!")
	GameManager.dialog("Promotion Offer", "Your manager offers you the role of %s (%s/hr, was %s/hr)." % [nj.title, GameManager.UIU.money(nj.hourly), GameManager.UIU.money(j.hourly)], [
		{"label": "Accept", "call": func():
			GameManager.s.job = nj.id
			GameManager.s.job_shifts = 0
			GameManager.change_stat("happiness", 10.0)
			GameManager.notify("Promoted to %s!" % nj.title)},
		{"label": "Decline", "call": func(): GameManager.s.declined_promo = nj.id}])

func _on_day(d: int) -> void:
	var gs = GameManager.s
	if not GameManager.in_game or gs.is_empty(): return
	# absence tracking (previous day was a workday and you never showed up)
	if gs.job != "" and (d - 1) % 7 < 5 and not gs.worked_today:
		gs.days_absent = int(gs.days_absent) + 1
		if int(gs.days_absent) in [3, 4]: GameManager.notify("Your boss noticed you've been absent.")
		if int(gs.days_absent) >= 5:
			gs.job = ""
			gs.days_absent = 0
			gs.reputation = clampf(float(gs.reputation) - 5.0, 0.0, 100.0)
			GameManager.notify("You were fired for repeated absence.")
	gs.worked_today = false
	_refresh_gigs(d)

# ---------------------------------------------------------------- education
func enroll(cid: String) -> bool:
	var c = GameManager.idx.courses[cid]
	var gs = GameManager.s
	if GameManager.has_qual(cid) or gs.enrolled.has(cid): return false
	for q in c.prereq:
		if not GameManager.has_qual(q):
			GameManager.notify("Prerequisite missing: " + qual_name(q))
			return false
	if not EconomyManager.spend(EconomyManager.price(c.cost)): return false
	gs.enrolled[cid] = 0
	GameManager.notify("Enrolled in %s." % c.name)
	return true

func attend(cid: String) -> String:
	var c = GameManager.idx.courses[cid]
	var gs = GameManager.s
	var h := TimeManager.get_hour()
	if TimeManager.is_weekend() or h < 8 or h > 14: return "Classes run Mon-Fri, starting between 08:00 and 14:00."
	if GameManager.stat("energy") < 25.0: return "You're too tired to concentrate."
	TimeManager.advance(240)
	gs.enrolled[cid] = int(gs.enrolled[cid]) + 1
	GameManager.change_stat("energy", -15.0 * GameManager.perk("energy_mult"))
	GameManager.change_stat("intelligence", 0.4)
	GameManager.change_stat("stress", 3.0)
	GameManager.change_stat("experience", 1.0)
	for sk in c.skills: GameManager.add_skill(sk, float(c.skills[sk]) / float(c.sessions))
	if int(gs.enrolled[cid]) >= int(c.sessions): return _exam(c)
	return "Class attended (%d/%d)." % [int(gs.enrolled[cid]), int(c.sessions)]

func _exam(c: Dictionary) -> String:
	var score := GameManager.stat("intelligence") * 0.5 + GameManager.stat("discipline") * 0.3 + randf() * 30.0 + 15.0
	if score >= float(c.exam):
		GameManager.s.education.append(c.id)
		GameManager.s.enrolled.erase(c.id)
		GameManager.change_stat("happiness", 15.0)
		GameManager.s.reputation = clampf(float(GameManager.s.reputation) + 2.0, 0.0, 100.0)
		GameManager.check_achievements()
		return "You PASSED the final exam and earned: %s!" % c.name
	GameManager.s.enrolled[c.id] = int(c.sessions) - 3
	return "You failed the exam (score %d, needed %d). Retake after 3 more classes." % [int(score), int(c.exam)]

# ---------------------------------------------------------------- freelance
func wage_mult() -> float: return EconomyManager.wage_index()

func _refresh_gigs(d: int) -> void:
	var gs = GameManager.s
	for g in gs.gigs.duplicate():
		if int(g.expires) < d: gs.gigs.erase(g)
	for g in gs.active_gigs.duplicate():
		if int(g.deadline) < d:
			gs.active_gigs.erase(g)
			gs.freelance_rep = maxf(float(gs.freelance_rep) - 3.0, 0.0)
			GameManager.notify("You missed the deadline for '%s'. Reputation hurt." % g.title)
	var tries := 2
	while gs.gigs.size() < 5 and tries > 0:
		tries -= 1
		var t = GameManager.data.gigs[randi() % GameManager.data.gigs.size()]
		var diff := randi_range(1, 3)
		gs.gigs.append({"uid": randi(), "title": "%s (lvl %d)" % [t.title, diff], "skill": t.skill, "req": int(t.req * diff * 0.8),
			"pay": snappedf(t.pay * (0.8 + 0.5 * diff) * wage_mult(), 1.0), "needed": int(t.sessions * (1 + diff * 0.5)),
			"progress": 0, "expires": d + 3, "days": 4 + diff * 2, "diff": diff})

func accept_gig(uid: int) -> void:
	var gs = GameManager.s
	if gs.active_gigs.size() >= 2:
		GameManager.notify("You can handle at most 2 projects at once.")
		return
	for g in gs.gigs:
		if int(g.uid) == uid:
			if float(gs.skills.get(g.skill, 0.0)) < float(g.req):
				GameManager.notify("Needs %s %d." % [g.skill.capitalize(), int(g.req)])
				return
			gs.gigs.erase(g)
			g.deadline = TimeManager.get_day() + int(g.days)
			gs.active_gigs.append(g)
			GameManager.notify("Accepted: %s (due in %d days)." % [g.title, int(g.days)])
			return

func work_on_gig(uid: int) -> String:
	var gs = GameManager.s
	if GameManager.stat("energy") < 20.0: return "Too tired to focus."
	for g in gs.active_gigs:
		if int(g.uid) == uid:
			TimeManager.advance(180)
			var ratio := clampf(float(gs.skills.get(g.skill, 0.0)) / maxf(float(g.req), 1.0), 0.5, 1.5)
			g.progress = float(g.progress) + ratio * (1.0 + GameManager.item_sum("study_bonus") * 0.3)
			GameManager.change_stat("energy", -12.0 * GameManager.perk("energy_mult"))
			GameManager.change_stat("stress", 3.0)
			GameManager.add_skill(g.skill, 0.8)
			GameManager.change_stat("experience", 1.0)
			if float(g.progress) >= float(g.needed):
				gs.active_gigs.erase(g)
				var pay := snappedf(float(g.pay) * 0.9, 0.01) # 10% platform fee
				EconomyManager.add_money(pay)
				gs.freelance_rep = clampf(float(gs.freelance_rep) + 2.0, 0.0, 100.0)
				gs.freelance_done = int(gs.freelance_done) + 1
				gs.reputation = clampf(float(gs.reputation) + 0.5, 0.0, 100.0)
				GameManager.check_achievements()
				return "Project delivered! Paid %s." % GameManager.UIU.money(pay)
			return "Progress: %.1f / %d" % [float(g.progress), int(g.needed)]
	return "Project not found."
