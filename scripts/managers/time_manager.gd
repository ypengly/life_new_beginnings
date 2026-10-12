extends Node
## Game clock. 1 real second = `speed` game minutes. Emits hour/day/month/year signals.

signal time_changed
signal hour_changed(hour: int)
signal day_changed(day: int)
signal month_changed(month: int)
signal year_changed(year: int)
signal skipped ## emitted after a big time jump (sleep, work shift) so NPCs can snap to schedule

const DAY_NAMES := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const MONTH_NAMES := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var total_minutes: int = 480 # day 0, 08:00 (Monday)
var speed: float = 1.0
var _acc: float = 0.0

func reset() -> void:
	total_minutes = 480
	_acc = 0.0

func _process(delta: float) -> void:
	if not GameManager.in_game or GameManager.ui_open:
		return
	_acc += delta * speed
	var steps := int(_acc)
	if steps > 0:
		_acc -= steps
		advance(steps, false)

func advance(minutes: int, big_skip := true) -> void:
	minutes = maxi(minutes, 0)
	for i in minutes:
		var old_day := get_day()
		total_minutes += 1
		if total_minutes % 60 == 0:
			hour_changed.emit(get_hour())
		var d := get_day()
		if d != old_day:
			day_changed.emit(d)
			if d % 30 == 0:
				month_changed.emit(get_month_index())
			if d % 360 == 0:
				year_changed.emit(get_year())
	time_changed.emit()
	if big_skip and minutes >= 30:
		skipped.emit()

func get_day() -> int: return total_minutes / 1440
func get_hour() -> int: return (total_minutes / 60) % 24
func get_minute() -> int: return total_minutes % 60
func get_hour_float() -> float: return float(total_minutes % 1440) / 60.0
func get_weekday() -> int: return get_day() % 7
func is_weekend() -> bool: return get_weekday() >= 5
func get_month_index() -> int: return (get_day() / 30) % 12
func get_year() -> int: return get_day() / 360
func get_age() -> int: return 18 + get_year()

func day_name() -> String: return DAY_NAMES[get_weekday()]

func clock_text() -> String:
	var h := get_hour()
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0: h12 = 12
	return "%02d:%02d %s" % [h12, get_minute(), suffix]

func date_text() -> String:
	return "%s %d, Year %d" % [MONTH_NAMES[get_month_index()], get_day() % 30 + 1, get_year() + 1]

func period_name() -> String:
	var h := get_hour()
	if h >= 5 and h < 12: return "Morning"
	if h >= 12 and h < 17: return "Afternoon"
	if h >= 17 and h < 21: return "Evening"
	return "Night"
