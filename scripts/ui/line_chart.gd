extends Control
## Tiny line chart. Set `points` and call queue_redraw().

var points: Array = []
var color := Color("#66d9a0")
var caption := ""

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	if points.size() < 2:
		draw_string(ThemeDB.fallback_font, Vector2(10, size.y / 2.0), "Not enough data yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		return
	var lo: float = points[0]
	var hi: float = points[0]
	for p in points:
		lo = minf(lo, p)
		hi = maxf(hi, p)
	if is_equal_approx(lo, hi):
		hi = lo + 1.0
	var pts := PackedVector2Array()
	for i in points.size():
		var x := 8.0 + (size.x - 16.0) * float(i) / float(points.size() - 1)
		var y := size.y - 18.0 - (size.y - 36.0) * (float(points[i]) - lo) / (hi - lo)
		pts.append(Vector2(x, y))
	draw_polyline(pts, color, 2.0, true)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(8, 14), "%s  hi %.2f" % [caption, hi], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	draw_string(f, Vector2(8, size.y - 4), "lo %.2f" % lo, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
