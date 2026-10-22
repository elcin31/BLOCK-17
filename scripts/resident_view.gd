extends Node2D
var data: Dictionary
var selected: bool = false
var phase: float = 0.0
var walking: bool = false
var facing: float = 1.0
var tint: Color = Color.WHITE
const SHIRTS = ["e9b276", "779fba", "d28581", "96b58a", "c5b1d0", "e2cc95", "73b5af", "b78d78"]
const SKINS = ["f1ceaa", "dcb28d", "b78968", "8e624c"]
const HAIRS = ["52483c", "9f744b", "d2b770", "343d3b", "b1b6a8"]

func _draw() -> void:
	if data.is_empty():
		return
	var s = 0.8 if data.age < 18 else 1.0
	if selected:
		draw_arc(Vector2.ZERO, 11, 0, TAU, 22, Color("ffe4a1"), 2, true)
	var shadow = PackedVector2Array()
	for i in 12:
		shadow.append(Vector2(cos(i * TAU / 12) * 7, sin(i * TAU / 12) * 3))
	draw_colored_polygon(shadow, Color(0.08, 0.2, 0.23, 0.25))
	var stride = sin(phase) * 3.5 if walking else 0.0
	var bounce = absf(cos(phase)) * 0.7 if walking else 0.0
	var shirt = Color(SHIRTS[int(data.appearance.shirt)])
	var skin = Color(SKINS[int(data.appearance.skin)])
	var hair = Color(HAIRS[int(data.appearance.hair)])
	draw_line(Vector2(-2, -6) * s, Vector2(-2 + stride, 0) * s, Color("485963"), 2.5 * s, true)
	draw_line(Vector2(2, -6) * s, Vector2(2 - stride, 0) * s, Color("384c58"), 2.5 * s, true)
	draw_line(Vector2(-2 + stride, 0) * s, Vector2(-4 + stride, 0) * s, Color("e1dcc4"), 2 * s)
	draw_line(Vector2(2 - stride, 0) * s, Vector2(4 - stride, 0) * s, Color("e1dcc4"), 2 * s)
	draw_style_box(_jacket(shirt), Rect2(Vector2(-4, -15 - bounce) * s, Vector2(8, 10) * s))
	draw_line(Vector2(-4, -13) * s, Vector2(-5 - stride * 0.4, -7) * s, skin, 2 * s, true)
	draw_line(Vector2(4, -13) * s, Vector2(5 + stride * 0.4, -7) * s, skin, 2 * s, true)
	if data.female:
		draw_circle(Vector2(0, -19 - bounce) * s, 5.4 * s, hair)
	draw_circle(Vector2(facing * 0.5, -19 - bounce) * s, 4.3 * s, skin)
	draw_arc(Vector2(0, -20 - bounce) * s, 4.3 * s, PI, TAU + 0.2, 9, hair, 3 * s, true)
	draw_circle(Vector2(facing * 2, -19 - bounce) * s, 0.6 * s, Color("394d4e"))
	if data.age >= 63:
		draw_line(Vector2(6, -10), Vector2(8, 0), Color("7a6952"), 1.5)

var jacket: StyleBoxFlat
func _jacket(color: Color) -> StyleBoxFlat:
	if jacket == null:
		jacket = StyleBoxFlat.new()
		jacket.bg_color = color
		jacket.corner_radius_top_left = 3
		jacket.corner_radius_top_right = 3
	return jacket
