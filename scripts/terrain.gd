extends Node2D
const Catalog = preload("res://scripts/catalog.gd")
var sim: CitySimulation
var building_mode: bool = false
var font: Font = preload("res://assets/DejaVuSans.ttf")

func diamond(p: Vector2, w: float, h: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w, 0), p + Vector2(0, -h), p + Vector2(w, 0), p + Vector2(0, h)]), color)

func _draw() -> void:
	if sim == null:
		return
	# A raised island, river embankment and shoreline frame the district.
	var center = Catalog.iso(Vector2(12, 12))
	diamond(center + Vector2(0, 45), 1160, 580, Color("284954"))
	diamond(center + Vector2(0, 20), 1090, 545, Color("607d70"))
	diamond(center, 1090, 545, Color("8ab28d"))
	for y in Catalog.SIZE:
		for x in Catalog.SIZE:
			var p = Catalog.iso(Vector2(x, y))
			if sim.road_lookup.has(Vector2i(x, y)):
				diamond(p, 42.3, 21.2, Color("74878a"))
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if not sim.road_lookup.has(Vector2i(x, y) + d):
						var edge = Catalog.iso(Vector2(d)) * 0.5
						var along = Vector2(21, 10.5) if d.x == 0 else Vector2(-21, 10.5)
						draw_line(p + edge - along, p + edge + along, Color("cccbb7"), 7, true)
				if x % 4 == 0 and y % 4 != 0:
					draw_line(p + Vector2(-9, 4.5), p + Vector2(9, -4.5), Color("b3b8a7"), 1.6, true)
				elif y % 4 == 0 and x % 4 != 0:
					draw_line(p + Vector2(-9, -4.5), p + Vector2(9, 4.5), Color("b3b8a7"), 1.6, true)
				if x % 4 == 0 and y % 4 == 0 and x > 0 and y > 0:
					for stripe in 4:
						var q = p + Vector2(14 + stripe * 4, -2 - stripe * 2)
						draw_line(q, q + Vector2(11, 5.5), Color("d5d2bc"), 2.5)
			else:
				var noise = fmod(x * 7 + y * 13, 9) / 100.0
				diamond(p, 42.2, 21.1, Color(0.52 + noise, 0.68 + noise * 0.6, 0.48 + noise * 0.6))
				if (x * 7 + y * 11) % 5 == 0:
					draw_line(p + Vector2(-4, 1), p + Vector2(-2, -3), Color("799e71"), 1)
	for y in range(2, 24, 4):
		for x in range(2, 24, 4):
			if sim.buildings.any(func(b): return b.x == x and b.y == y):
				continue
			var p = Catalog.iso(Vector2(x, y))
			var c = Color(0.96, 0.87, 0.59, 0.75) if building_mode else Color(0.8, 0.87, 0.64, 0.35)
			var corners = PackedVector2Array([p + Vector2(-90, 0), p + Vector2(0, -45), p + Vector2(90, 0), p + Vector2(0, 45), p + Vector2(-90, 0)])
			draw_polyline(corners, c, 2, true)
			if building_mode:
				draw_string(font, p + Vector2(-5, 5), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("fff0c7"))
	for i in 6:
		var p = Catalog.iso(Vector2(-0.8, i * 4 + 2))
		draw_string(font, p + Vector2(-75, 0), sim.streets[i].name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d0dac6"))
