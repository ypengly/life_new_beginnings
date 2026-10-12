extends RefCounted
## Placeholder character painter shared by the player, preview and (later) replaced by AnimatedSprite2D art.
const SKIN := [Color("#f5d0b0"), Color("#e8b88a"), Color("#c68e5f"), Color("#a56b3f"), Color("#7a4a2a"), Color("#4e2e1a")]
const HAIR := [Color("#1b1b1b"), Color("#5a3a1e"), Color("#a0522d"), Color("#e6c36a"), Color("#c0392b"), Color("#9aa0a6")]
const TOP := [Color("#3b82c4"), Color("#c0392b"), Color("#2e8b57"), Color("#e0a030"), Color("#7d5ba6"), Color("#444444")]
const SHOES := [Color("#222222"), Color("#f2f2f2"), Color("#8b5a2b"), Color("#c0392b")]
const HAIR_NAMES := ["Short", "Long", "Bun", "Bald"]
const ACC_NAMES := ["None", "Glasses", "Cap", "Watch"]

static func paint(ci: CanvasItem, look: Dictionary, bob := 0.0, k := 1.0) -> void:
	var skin: Color = SKIN[clampi(int(look.get("skin", 0)), 0, SKIN.size() - 1)]
	var hc: Color = HAIR[clampi(int(look.get("hair_color", 0)), 0, HAIR.size() - 1)]
	var top: Color = TOP[clampi(int(look.get("top", 0)), 0, TOP.size() - 1)]
	var shoes: Color = SHOES[clampi(int(look.get("shoes", 0)), 0, SHOES.size() - 1)]
	var hair := int(look.get("hair", 0))
	var acc := int(look.get("acc", 0))
	ci.draw_set_transform(Vector2(0, bob), 0.0, Vector2(k, k))
	ci.draw_circle(Vector2(0, 20), 11, Color(0, 0, 0, 0.2))
	if hair == 1:
		ci.draw_rect(Rect2(-10, -24, 20, 24), hc)
	ci.draw_rect(Rect2(-7, 8, 5, 10), Color("#2c3e50"))
	ci.draw_rect(Rect2(2, 8, 5, 10), Color("#2c3e50"))
	ci.draw_rect(Rect2(-8, 16, 7, 4), shoes)
	ci.draw_rect(Rect2(1, 16, 7, 4), shoes)
	ci.draw_rect(Rect2(-9, -6, 18, 16), top)
	ci.draw_circle(Vector2(0, -14), 9, skin)
	match hair:
		0: ci.draw_rect(Rect2(-9, -25, 18, 8), hc)
		1: ci.draw_rect(Rect2(-9, -25, 18, 7), hc)
		2:
			ci.draw_rect(Rect2(-9, -25, 18, 7), hc)
			ci.draw_circle(Vector2(0, -28), 5, hc)
	ci.draw_circle(Vector2(-3, -14), 1.3, Color.BLACK)
	ci.draw_circle(Vector2(3, -14), 1.3, Color.BLACK)
	if acc == 1:
		ci.draw_rect(Rect2(-6, -16, 5, 4), Color(0, 0, 0, 0.6), false, 1.0)
		ci.draw_rect(Rect2(1, -16, 5, 4), Color(0, 0, 0, 0.6), false, 1.0)
	elif acc == 2:
		ci.draw_rect(Rect2(-10, -27, 20, 6), Color("#c0392b"))
		ci.draw_rect(Rect2(-10, -22, 24, 2), Color("#c0392b"))
	elif acc == 3:
		ci.draw_circle(Vector2(-10, 3), 2.5, Color("#ffd166"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
