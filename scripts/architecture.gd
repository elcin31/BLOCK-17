extends Node2D
## Architectural illustrations are retained CanvasItem commands, redrawn only on change.
const Catalog = preload("res://scripts/catalog.gd")
var data: Dictionary
var night: bool = false
var selected: bool = false
var font: Font = preload("res://assets/DejaVuSans.ttf")

func polygon(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func slab(center: Vector2, width: float, depth: float, height: float, color: Color) -> void:
	var l = center + Vector2(-width, 0)
	var f = center + Vector2(0, depth)
	var r = center + Vector2(width, 0)
	var t = center + Vector2(0, -depth)
	var up = Vector2(0, -height)
	polygon([l, f, f + up, l + up], color.darkened(0.17))
	polygon([f, r, r + up, f + up], color)
	polygon([l + up, t + up, r + up, f + up], color.lightened(0.17))

func tree(p: Vector2, size: float = 1.0, autumn: bool = false) -> void:
	ellipse(p + Vector2(3, 2) * size, Vector2(17, 7) * size, Color(0.09, 0.22, 0.2, 0.16))
	draw_set_transform(p, 0, Vector2.ONE * size)
	draw_line(Vector2.ZERO, Vector2(0, -29), Color("725643"), 4)
	draw_line(Vector2(0, -16), Vector2(8, -28), Color("725643"), 2)
	var c = Color("c5a759") if autumn else Color("54936f")
	draw_circle(Vector2(-7, -30), 15, c.darkened(0.12))
	draw_circle(Vector2(7, -35), 17, c)
	draw_circle(Vector2(-2, -46), 14, c.lightened(0.13))
	draw_arc(Vector2(-3, -43), 9, 3.4, 5.3, 9, c.lightened(0.25), 2, true)
	draw_set_transform(Vector2.ZERO)

func ellipse(p: Vector2, radius: Vector2, color: Color) -> void:
	draw_set_transform(p, 0, radius)
	draw_circle(Vector2.ZERO, 1, color)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if data.is_empty():
		return
	var kind: String = data.type
	var base = Color(Catalog.TYPES[kind].color)
	if selected:
		polygon([Vector2(-113, -36), Vector2(0, -92), Vector2(113, -36), Vector2(0, 20)], Color(0.97, 0.83, 0.47, 0.5))
	# All geometry is raised above the front edge, matching Y-sort at the pavement.
	var origin = Vector2(0, -40)
	polygon([origin + Vector2(-79, 6), origin + Vector2(7, -37), origin + Vector2(99, 4), origin + Vector2(13, 48)], Color(0.12, 0.22, 0.24, 0.19))
	slab(origin, 87, 43.5, 3, Color("cbcbb5"))
	if kind == "park":
		_park(origin)
		return
	var h = {"home": 115, "tower": 170, "shop": 48, "cafe": 58, "office": 152, "workshop": 62, "school": 87, "clinic": 95}.get(kind, 90)
	var width = 64.0
	var depth = 32.0
	var o = origin + Vector2(0, -4)
	slab(o, width, depth, h, base)
	# Foundation, cornice and a parapet give every facade an architectural profile.
	slab(o + Vector2(0, -3), 65, 32.5, 5, base.darkened(0.25))
	slab(o + Vector2(0, -h), 68, 34, 5, Color("e5dbc0"))
	var floors = int(h / 29)
	for floor_id in floors:
		var py = o.y - 16 - floor_id * 29
		for col in 3:
			var u = 0.17 + col * 0.31
			var light = night and (int(data.id) + floor_id * 3 + col) % 3 != 0
			var glass = Color("ffdda0") if light else Color("49717d")
			# Windows follow the two planes, with sills and individual panes.
			var a = Vector2(-64 + u * 64, py + u * 32)
			polygon([a, a + Vector2(12, 6), a + Vector2(12, -10), a + Vector2(0, -16)], glass.darkened(0.12))
			draw_line(a + Vector2(-1, 2), a + Vector2(14, 9), Color("e8d8b9"), 2, true)
			draw_line(a + Vector2(6, 3), a + Vector2(6, -12), base.lightened(0.2), 1)
			var b = Vector2(u * 64, py + 32 - u * 32)
			polygon([b, b + Vector2(13, -6.5), b + Vector2(13, -23), b + Vector2(0, -16.5)], glass)
			draw_line(b + Vector2(-1, 2), b + Vector2(15, -6), Color("f0dfc0"), 2, true)
			draw_line(b + Vector2(6, -3), b + Vector2(6, -20), base.lightened(0.3), 1)
		if kind == "home" and floor_id > 0:
			slab(Vector2(-27, py + 17), 18, 9, 5, Color("9baba5"))
			for bar in 4:
				draw_line(Vector2(-43 + bar * 8, py + 9 + bar * 2), Vector2(-43 + bar * 8, py + 1 + bar * 2), Color("6c7f79"), 1)
	# Entrance with glazed door, canopy and steps.
	var door = o + Vector2(15, 24)
	polygon([door, door + Vector2(15, -7.5), door + Vector2(15, -32), door + Vector2(0, -24.5)], Color("355764"))
	draw_line(door + Vector2(8, -5), door + Vector2(8, -27), Color("b2c6bd"), 1.5)
	slab(door + Vector2(6, 1), 17, 8.5, 3, Color("ded8be"))
	slab(door + Vector2(7, -27), 19, 9.5, 4, base.darkened(0.28))
	var rooftop = o + Vector2(0, -h - 6)
	if kind == "home":
		# Pitched tile roof, ridge, chimney, and roof seams.
		var ridge = rooftop + Vector2(0, -30)
		polygon([rooftop + Vector2(-68, 0), ridge + Vector2(0, -26), rooftop + Vector2(68, 0), rooftop + Vector2(0, 34)], Color("9f6658"))
		polygon([rooftop + Vector2(-68, 0), rooftop + Vector2(0, -34), ridge + Vector2(0, -26)], Color("bc7e65"))
		for i in range(1, 6):
			var u = i / 6.0
			draw_line((rooftop + Vector2(-68, 0)).lerp(ridge + Vector2(0, -26), u), (rooftop + Vector2(0, 34)).lerp(rooftop + Vector2(68, 0), u), Color(0.5, 0.27, 0.25, 0.3), 1)
		slab(rooftop + Vector2(-23, -25), 7, 3.5, 20, Color("ae775f"))
	elif kind == "office":
		slab(rooftop + Vector2(0, -2), 42, 21, 17, Color("a1cad0"))
		slab(rooftop + Vector2(-24, -7), 9, 4.5, 12, Color("d7e1d5"))
		draw_line(rooftop + Vector2(20, -12), rooftop + Vector2(20, -51), Color("dde9dd"), 2)
		draw_circle(rooftop + Vector2(20, -51), 3, Color("e6a576"))
	elif kind == "workshop":
		slab(rooftop + Vector2(-28, -8), 10, 5, 52, Color("a67c67"))
		slab(rooftop + Vector2(20, 7), 25, 12.5, 10, Color("9caeaa"))
		for i in 3:
			slab(rooftop + Vector2(-10 + 17 * i, -16 + i * 4), 8, 4, 9, Color("84adb4"))
	elif kind == "tower":
		slab(rooftop, 42, 21, 16, base.lightened(0.14))
		tree(rooftop + Vector2(-27, 5), 0.4)
		tree(rooftop + Vector2(34, 0), 0.4)
	else:
		slab(rooftop + Vector2(-16, 0), 15, 7.5, 9, Color("a5b9b1"))
		draw_arc(rooftop + Vector2(-16, -10), 6, 0, TAU, 12, Color("778e8b"), 2)
	if kind in ["shop", "cafe"]:
		_awning(o + Vector2(-44, -6), kind == "cafe")
		var sign = "СОСЕДИ" if kind == "cafe" else "ПРОДУКТЫ"
		_label(sign, o + Vector2(-46, -33), 10, Color("fff4da"))
		if kind == "cafe":
			for p in [Vector2(55, 13), Vector2(34, 31)]:
				draw_line(o + p, o + p + Vector2(0, -10), Color("796c54"), 3)
				ellipse(o + p + Vector2(0, -10), Vector2(10, 5), Color("f2dbab"))
				draw_circle(o + p + Vector2(0, -13), 2, Color("cc936c"))
	elif kind == "clinic":
		draw_line(rooftop + Vector2(30, -14), rooftop + Vector2(30, 5), Color("e88c7c"), 6)
		draw_line(rooftop + Vector2(20, -4), rooftop + Vector2(40, -4), Color("e88c7c"), 6)
	elif kind == "school":
		_label("17", rooftop + Vector2(-8, 7), 19, Color("6c7765"))
		draw_line(o + Vector2(65, -2), o + Vector2(65, -65), Color("81988b"), 2)
		polygon([o + Vector2(65, -65), o + Vector2(86, -59), o + Vector2(65, -50)], Color("e4af6f"))
	# Street furniture, planters, roof antenna, lamps, and house number.
	tree(origin + Vector2(-68, 15), 0.65, int(data.id) % 5 == 0)
	if kind not in ["shop", "cafe"]:
		tree(origin + Vector2(70, 4), 0.5)
	_label(str(int(data.id) + 1), o + Vector2(34, 3), 8, Color("fff1d1"))
	_lamp(origin + Vector2(66, 29))
	if data.closed:
		_label("ЗАКРЫТО", o + Vector2(-39, -40), 12, Color("e48376"))

func _awning(p: Vector2, red: bool) -> void:
	for i in 6:
		var a = p + Vector2(i * 9, i * 4.5)
		var c = Color("c77567") if red else Color("629c86")
		if i % 2 == 0:
			c = Color("f7e7c1")
		polygon([a + Vector2(0, -14), a + Vector2(9, -9.5), a + Vector2(-1, 0.5), a + Vector2(-10, -4)], c)
		draw_line(a + Vector2(-10, -4), a + Vector2(-1, 0.5), c.darkened(0.15), 4)

func _park(o: Vector2) -> void:
	polygon([o + Vector2(-78, 0), o + Vector2(0, -39), o + Vector2(78, 0), o + Vector2(0, 39)], Color("86b582"))
	draw_line(o + Vector2(-65, 23), o + Vector2(50, -28), Color("d9d1ab"), 10, true)
	draw_line(o + Vector2(-53, -23), o + Vector2(62, 29), Color("d9d1ab"), 9, true)
	ellipse(o + Vector2(4, -3), Vector2(26, 13), Color("b0c9bc"))
	ellipse(o + Vector2(4, -5), Vector2(21, 10), Color("79b9c4"))
	draw_line(o + Vector2(4, -8), o + Vector2(4, -29), Color("b4e1dc"), 3, true)
	draw_arc(o + Vector2(4, -15), 12, PI, TAU, 16, Color("d3eee0"), 2, true)
	for p in [Vector2(-47, 0), Vector2(43, -8), Vector2(-3, -25), Vector2(36, 23)]:
		tree(o + p, 0.7, p.x > 40)
	for p in [Vector2(-24, 23), Vector2(30, 4)]:
		slab(o + p, 13, 4, 6, Color("ba9670"))
	for i in 8:
		var p = o + Vector2(-52 + i * 12, 12 + sin(i * 2.5) * 10)
		draw_circle(p, 2.5, Color("e7bc81") if i % 2 == 0 else Color("e4a4a0"))
	_lamp(o + Vector2(67, 21))

func _lamp(p: Vector2) -> void:
	draw_line(p, p + Vector2(0, -41), Color("547472"), 2.5, true)
	draw_line(p + Vector2(0, -41), p + Vector2(-9, -43), Color("547472"), 2, true)
	if night:
		draw_circle(p + Vector2(-9, -40), 13, Color(1, 0.83, 0.46, 0.08))
		draw_circle(p + Vector2(-9, -40), 7, Color(1, 0.83, 0.46, 0.16))
	draw_circle(p + Vector2(-9, -41), 3.5, Color("ffe1a1") if night else Color("dfe6cd"))

func _label(text: String, p: Vector2, size: int, color: Color) -> void:
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
