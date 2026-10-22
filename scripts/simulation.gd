class_name CitySimulation
extends RefCounted
## Pure minute-step simulation. No scene tree, rendering, OS clock or UI dependency.

const Catalog = preload("res://scripts/catalog.gd")
var residents: Array = []
var buildings: Array = []
var roads: Array = []
var events: Array = []
var ledger: Array = []
var streets: Array = []
var day: int = 1
var minute: int = 420
var treasury: float = 180000.0
var tax_rate: float = 0.12
var daily_income: float = 0.0
var daily_expense: float = 0.0
var last_income: float = 0.0
var last_expense: float = 0.0
var total_purchases: int = 0
var revision: int = 0
var rng = RandomNumberGenerator.new()
var navigation = AStarGrid2D.new()
var road_lookup: Dictionary = {}

func new_city(seed_value: int = 170017) -> void:
	residents.clear()
	buildings.clear()
	roads.clear()
	events.clear()
	ledger.clear()
	streets.clear()
	day = 1
	minute = 420
	treasury = 180000.0
	daily_income = 0.0
	daily_expense = 0.0
	last_income = 0.0
	last_expense = 0.0
	total_purchases = 0
	tax_rate = 0.12
	rng.seed = seed_value
	for y in Catalog.SIZE:
		for x in Catalog.SIZE:
			if Catalog.road_cell(x, y):
				roads.append([x, y])
	var layout = [
		["home", "shop", "home", "office", "", "park"],
		["home", "school", "", "cafe", "workshop", "home"],
		["park", "home", "clinic", "home", "shop", "office"],
		["", "workshop", "cafe", "home", "park", ""],
		["shop", "home", "", "office", "", ""],
		["", "", "park", "", "", ""]
	]
	for y in 6:
		streets.append({"name": ["Липовая", "Тихая", "Мастерская", "Солнечная", "Школьная", "Набережная"][y], "quality": 60.0})
		for x in 6:
			if layout[y][x] != "":
				_add_building(layout[y][x], x * 4 + 2, y * 4 + 2)
	_rebuild_navigation()
	var homes = of_type("home")
	for i in Catalog.POPULATION:
		var female = i % 2 == 1
		var first = Catalog.FIRST_NAMES[(rng.randi_range(0, 9) * 2) + int(female)]
		var surname: String = Catalog.LAST_NAMES[(i / 4) as int % Catalog.LAST_NAMES.size()]
		if female and surname != "Ким":
			surname += "а"
		var age = rng.randi_range(23, 57)
		if i % 4 == 2:
			age = rng.randi_range(8, 17)
		elif i % 12 == 3:
			age = rng.randi_range(63, 77)
		var home: Dictionary = homes[(i / 4) as int % homes.size()]
		var door = entrance(home)
		var r = {"id": i, "name": first + " " + surname, "age": age, "female": female,
			"trait": Catalog.TRAITS[rng.randi_range(0, 5)], "appearance": {"skin": rng.randi_range(0, 3), "hair": rng.randi_range(0, 4), "shirt": rng.randi_range(0, 7)},
			"home": home.id, "work": -1, "profession": "Школьник" if age < 18 else ("Пенсионер" if age >= 63 else "Ищет работу"),
			"salary": 0.0, "money": float(rng.randi_range(350, 2800)), "expenses": 0.0, "income": 0.0, "rent": 0.0,
			"mood": float(rng.randi_range(55, 90)), "food": float(rng.randi_range(45, 85)), "energy": 90.0, "social": float(rng.randi_range(45, 80)), "health": 95.0,
			"goal": Catalog.GOALS[rng.randi_range(0, 4)], "goal_done": false,
			"partner": i + 1 if i % 4 == 0 else (i - 1 if i % 4 == 1 else -1), "family": [], "friends": [], "rivals": [], "affinity": {},
			"history": [], "pos": [door.x, door.y], "path": [], "destination": home.id, "activity": "Дома", "wait_until": 0, "broke_days": 0, "employed_minutes": 0}
		for j in range((i / 4) as int * 4, (i / 4) as int * 4 + 4):
			if j != i:
				r.family.append(j)
		residents.append(r)
		_personal(r, "Переехал в район BLOCK 17. Начинается новая история.")
	for r in residents:
		if r.age >= 18 and r.age < 63:
			_find_work(r, false)
	_news("Район просыпается", "120 жителей обживают BLOCK 17. Рабочие места, доступное жильё и соседские связи определят его будущее.", "Город")
	revision += 1

func _add_building(kind: String, x: int, y: int, owner: int = -1) -> Dictionary:
	var b = {"id": buildings.size(), "type": kind, "x": x, "y": y, "cash": 12000.0, "profit": 0.0, "sales": 0.0, "owner": owner, "closed": false, "loss_days": 0, "built_day": day}
	buildings.append(b)
	return b

func of_type(kind: String) -> Array:
	return buildings.filter(func(b): return b.type == kind)

func entrance(b: Dictionary) -> Vector2:
	return Vector2(b.x, b.y - 2)

func _rebuild_navigation() -> void:
	road_lookup.clear()
	for p in roads:
		road_lookup[Vector2i(int(p[0]), int(p[1]))] = true
	navigation.region = Rect2i(0, 0, Catalog.SIZE, Catalog.SIZE)
	navigation.cell_size = Vector2.ONE
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	for y in Catalog.SIZE:
		for x in Catalog.SIZE:
			navigation.set_point_solid(Vector2i(x, y), not road_lookup.has(Vector2i(x, y)))

func build_at(kind: String, cell: Vector2i, charge: bool = true, owner: int = -1) -> String:
	if not Catalog.TYPES.has(kind):
		return "Неизвестное здание"
	var cost = float(Catalog.TYPES[kind].cost)
	if charge and treasury < cost:
		return "В бюджете недостаточно средств"
	if cell.x < 0 or cell.y < 0 or cell.x >= Catalog.SIZE or cell.y >= Catalog.SIZE:
		return "Выберите участок внутри района"
	if kind == "road":
		if road_lookup.has(cell):
			return "Здесь уже есть улица"
		for b in buildings:
			if absi(b.x - cell.x) <= 1 and absi(b.y - cell.y) <= 1:
				return "Участок занят зданием"
		var connected = false
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			connected = connected or road_lookup.has(cell + d)
		if not connected:
			return "Продолжите существующую дорогу"
		roads.append([cell.x, cell.y])
		_rebuild_navigation()
	else:
		var x = (cell.x / 4) as int * 4 + 2
		var y = (cell.y / 4) as int * 4 + 2
		if x >= 24 or y >= 24:
			return "Выберите свободный участок между улицами"
		for b in buildings:
			if b.x == x and b.y == y:
				return "Участок уже застроен"
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if road_lookup.has(Vector2i(x + dx, y + dy)):
					return "Участок пересекает дорога"
		_add_building(kind, x, y, owner)
		_news("Новая точка на карте", "%s: %s. %s" % [streets[mini(y / 4, 5)].name, Catalog.TYPES[kind].name, Catalog.TYPES[kind].description], "Строительство")
	if charge:
		treasury -= cost
		daily_expense += cost
	revision += 1
	return ""

func advance(minutes: int = 1) -> void:
	for _step in minutes:
		minute += 1
		if minute >= 1440:
			minute = 0
			day += 1
			last_income = daily_income
			last_expense = daily_expense
			ledger.append({"day": day - 1, "income": last_income, "expense": last_expense, "balance": treasury, "mood": stats().mood})
			if ledger.size() > 60:
				ledger.pop_front()
			daily_income = 0.0
			daily_expense = 0.0
			for r in residents:
				r.expenses = 0.0
				r.income = 0.0
		for r in residents:
			_needs(r)
			_move(r)
			if minute % 15 == r.id % 15:
				_decide(r)
		if minute == 1080:
			_payroll()
		if minute == 1260:
			_rent_and_city()
		if minute == 1140:
			_social_evening()
		if minute == 660:
			_enterprise()
		if minute == 1320:
			_migration()
		if minute == 720:
			_street_report()

func _needs(r: Dictionary) -> void:
	r.food = maxf(0.0, r.food - 0.035)
	r.social = maxf(0.0, r.social - (0.025 if r.trait == "Общительный" else 0.014))
	if r.activity == "Спит":
		r.energy = minf(100.0, r.energy + 0.18)
	else:
		r.energy = maxf(0.0, r.energy - 0.035)
	if r.activity == "Отдыхает в сквере":
		r.energy = minf(100.0, r.energy + 0.07)
		r.social = minf(100.0, r.social + 0.1)
	if r.activity == "На приёме":
		r.health = minf(100.0, r.health + 0.3)
	if r.food < 10:
		r.health = maxf(10.0, r.health - 0.025)
	var target = (r.food + r.energy + r.social + r.health) / 4.0
	if r.money < 100:
		target -= 15.0
	r.mood = clampf(lerpf(r.mood, target, 0.002), 0.0, 100.0)
	if r.activity == "Работает":
		r.employed_minutes += 1

func _move(r: Dictionary) -> void:
	if r.path.is_empty():
		return
	var pos = Vector2(r.pos[0], r.pos[1])
	var target = Vector2(r.path[0][0], r.path[0][1])
	pos = pos.move_toward(target, 0.22 if r.age < 63 else 0.16)
	r.pos = [pos.x, pos.y]
	if pos.distance_squared_to(target) < 0.001:
		r.path.pop_front()
		if r.path.is_empty():
			_arrive(r)

func _travel(r: Dictionary, b: Dictionary, purpose: String) -> void:
	if r.destination == b.id and not r.path.is_empty():
		return
	var pos = Vector2i(roundi(r.pos[0]), roundi(r.pos[1]))
	if not road_lookup.has(pos):
		pos = Vector2i(entrance(buildings[r.home]))
	var end = Vector2i(entrance(b))
	var path = navigation.get_id_path(pos, end)
	r.path = []
	for i in range(1, path.size()):
		r.path.append([path[i].x, path[i].y])
	r.destination = b.id
	r.activity = purpose
	if r.path.is_empty():
		_arrive(r)

func _arrive(r: Dictionary) -> void:
	var b: Dictionary = buildings[r.destination]
	match r.activity:
		"Идёт за покупками":
			var price = 24.0 if b.type == "shop" else 38.0
			if r.money >= price and not b.closed:
				r.money -= price
				r.expenses += price
				b.cash += price
				b.sales += price
				r.food = minf(100.0, r.food + 65.0)
				r.social = minf(100.0, r.social + 8.0)
				total_purchases += 1
				r.activity = "Обедает" if b.type == "cafe" else "Покупает продукты"
			else:
				r.activity = "Не хватило денег на еду"
			r.wait_until = day * 1440 + minute + 25
		"Идёт на работу": r.activity = "Работает"
		"Идёт в школу": r.activity = "Учится"
		"Идёт в сквер": r.activity = "Отдыхает в сквере"
		"Идёт в поликлинику": r.activity = "На приёме"
		"Возвращается домой": r.activity = "Спит" if minute >= 1320 or minute < 420 else "Дома"

func _decide(r: Dictionary) -> void:
	if not r.path.is_empty():
		return
	if day * 1440 + minute < r.wait_until:
		return
	var home: Dictionary = buildings[r.home]
	if minute < 390 or minute >= 1320:
		if r.destination != r.home:
			_travel(r, home, "Возвращается домой")
		else:
			r.activity = "Спит"
		return
	if r.activity == "Спит":
		r.activity = "Дома"
	if r.health < 55:
		var clinic = _nearest(r, ["clinic"])
		if not clinic.is_empty():
			_travel(r, clinic, "Идёт в поликлинику")
			return
	if r.food < 42 and r.money >= 24:
		var shop = _nearest(r, ["shop", "cafe"])
		if not shop.is_empty():
			_travel(r, shop, "Идёт за покупками")
			return
	if r.age < 18 and minute >= 480 and minute < 840:
		var school = _nearest(r, ["school"])
		if not school.is_empty():
			_travel(r, school, "Идёт в школу")
			return
	if r.age >= 18 and r.age < 63 and r.work < 0:
		_find_work(r)
	if r.work >= 0 and minute >= 480 and minute < 1020:
		_travel(r, buildings[r.work], "Идёт на работу")
		return
	if minute >= 1020 and minute < 1260 and (r.social < 70 or r.energy < 65):
		var park = _nearest(r, ["park", "cafe"])
		if not park.is_empty():
			_travel(r, park, "Идёт в сквер" if park.type == "park" else "Идёт за покупками")
			return
	if r.destination != r.home:
		_travel(r, home, "Возвращается домой")
	_check_goal(r)

func _nearest(r: Dictionary, types: Array) -> Dictionary:
	var best: Dictionary = {}
	var distance = INF
	var pos = Vector2(r.pos[0], r.pos[1])
	for b in buildings:
		if b.type in types and not b.closed:
			var d = pos.distance_squared_to(entrance(b))
			if d < distance:
				distance = d
				best = b
	return best

func workers(id: int) -> int:
	var count = 0
	for r in residents:
		if r.work == id:
			count += 1
	return count

func _find_work(r: Dictionary, announce: bool = true) -> void:
	var best: Dictionary = {}
	var best_score = -INF
	for b in buildings:
		var info: Dictionary = Catalog.TYPES[b.type]
		if b.closed or info.jobs <= workers(b.id):
			continue
		var score: float = info.wage - Vector2(r.pos[0], r.pos[1]).distance_to(entrance(b)) * 2.0
		if r.trait == "Амбициозный":
			score += info.wage * 0.2
		if score > best_score:
			best_score = score
			best = b
	if not best.is_empty() and (r.work < 0 or Catalog.TYPES[best.type].wage > r.salary * 1.15):
		r.work = best.id
		r.salary = float(Catalog.TYPES[best.type].wage)
		r.profession = {"shop": "Продавец", "cafe": "Бариста", "office": "Специалист", "workshop": "Мастер", "school": "Педагог", "clinic": "Медработник"}.get(best.type, "Сотрудник")
		if announce:
			_personal(r, "Новая работа: %s, %s в день." % [Catalog.TYPES[best.type].name, Catalog.money(r.salary)])
			_news("Новая работа", "%s устроился: %s." % [r.name, Catalog.TYPES[best.type].name], "Работа", r.id)

func _payroll() -> void:
	for b in buildings:
		var info: Dictionary = Catalog.TYPES[b.type]
		b.profit = b.sales
		if b.type in ["office", "workshop"] and not b.closed:
			# Money enters through external orders, not resident purchases.
			var exports = workers(b.id) * info.wage * rng.randf_range(1.25, 1.65)
			b.cash += exports
			b.profit += exports
		for r in residents:
			if r.work != b.id:
				continue
			var wage = r.salary * clampf(r.employed_minutes / 350.0, 0.2, 1.0)
			if b.type in ["clinic", "school"]:
				treasury -= wage
				daily_expense += wage
			elif b.cash >= wage:
				b.cash -= wage
			else:
				r.work = -1
				r.salary = 0.0
				r.profession = "Ищет работу"
				r.mood = maxf(0, r.mood - 20)
				_personal(r, "Потерял работу: предприятию не хватило денег на зарплату.")
				_news("Сокращение в районе", "%s потерял работу. Предприятию нужны покупатели или новые заказы." % r.name, "Работа", r.id)
				continue
			var tax = wage * tax_rate
			r.money += wage - tax
			r.income += wage - tax
			r.employed_minutes = 0
			treasury += tax
			daily_income += tax
			b.profit -= wage
		b.sales = 0.0
		if info.jobs > 0 and b.type not in ["clinic", "school"]:
			b.loss_days = b.loss_days + 1 if b.profit < 0 else 0
			if b.cash < 50 and b.loss_days >= 3 and not b.closed:
				b.closed = true
				_news("Закрылись двери", "%s временно закрывается из-за убытков." % info.name, "Бизнес")
			if b.owner >= 0 and b.profit > 0:
				var dividend = minf(b.profit * 0.25, maxf(0, b.cash - 2000))
				b.cash -= dividend
				residents[b.owner].money += dividend
	for r in residents:
		if r.age >= 63 or (r.age >= 18 and r.work < 0):
			var benefit = 65.0 if r.age >= 63 else 45.0
			r.money += benefit
			r.income += benefit
			treasury -= benefit
			daily_expense += benefit
		if r.trait == "Амбициозный" and rng.randf() < 0.15:
			_find_work(r)

func rent_multiplier() -> float:
	var capacity = 0
	for b in buildings:
		capacity += Catalog.TYPES[b.type].homes
	return clampf(0.7 + pow(residents.size() / float(maxi(1, capacity)), 3) * 0.75, 0.75, 2.0)

func _rent_and_city() -> void:
	var pressure = rent_multiplier()
	for r in residents:
		if r.age < 18:
			# Children share the household budget for food; no money is minted here.
			var parent = residents[r.family[0]]
			var allowance = minf(45.0, maxf(0, parent.money - 120))
			parent.money -= allowance
			parent.expenses += allowance
			r.money += allowance
			continue
		var home: Dictionary = buildings[r.home]
		var rent = float(Catalog.TYPES[home.type].rent) * pressure
		r.rent = rent
		var paid = minf(rent, maxf(0, r.money))
		r.money -= paid
		r.expenses += paid
		home.cash += paid * 0.85
		treasury += paid * 0.15
		daily_income += paid * 0.15
		r.broke_days = r.broke_days + 1 if r.money < 80 else 0
		if r.broke_days == 2:
			_personal(r, "Финансовые трудности: аренда и еда съедают сбережения.")
			_news("Трудный месяц", "%s едва сводит концы с концами. Доступное жильё и работа помогут семье." % r.name, "Финансы", r.id)
	for b in buildings:
		var upkeep = float(Catalog.TYPES[b.type].upkeep)
		if b.type in ["park", "school", "clinic"]:
			treasury -= upkeep
			daily_expense += upkeep
		else:
			b.cash = maxf(0, b.cash - upkeep)
	var road_cost = roads.size() * 0.1
	treasury -= road_cost
	daily_expense += road_cost
	if treasury < 0:
		_news("Бюджет в минусе", "Расходы превысили доходы. Новое строительство временно недоступно; проверьте налоги и занятость.", "Бюджет")

func _social_evening() -> void:
	# People meet only when physically close; family bonds also recover at home.
	for r in residents:
		var other: Dictionary = residents[rng.randi_range(0, residents.size() - 1)]
		if other.id == r.id or Vector2(r.pos[0], r.pos[1]).distance_to(Vector2(other.pos[0], other.pos[1])) > 4.0:
			continue
		var key = str(other.id)
		var score = float(r.affinity.get(key, 0))
		if (r.trait == "Вспыльчивый" or r.mood < 35) and rng.randf() < 0.35:
			score -= 25
			if score <= -25 and other.id not in r.rivals:
				r.rivals.append(other.id)
				_personal(r, "Повздорил с жителем: %s." % other.name)
		else:
			score += 20
			r.social = minf(100, r.social + 18)
			other.social = minf(100, other.social + 18)
			if score >= 20 and other.id not in r.friends:
				r.friends.append(other.id)
				if r.id not in other.friends:
					other.friends.append(r.id)
				_personal(r, "Подружился с жителем: %s." % other.name)
				_personal(other, "Новое знакомство: %s." % r.name)
				_news("Соседи стали ближе", "%s и %s познакомились на прогулке." % [r.name, other.name], "Люди", r.id)
		r.affinity[key] = clampf(score, -100, 100)
		other.affinity[str(r.id)] = r.affinity[key]
		if score >= 40 and r.partner < 0 and other.partner < 0 and r.age >= 18 and other.age >= 18 and other.id not in r.family:
			r.partner = other.id
			other.partner = r.id
			_personal(r, "Создал семью: %s." % other.name)
			_personal(other, "Создал семью: %s." % r.name)
			_news("Новая семья", "%s и %s решили быть вместе." % [r.name, other.name], "Семья", r.id)

func _enterprise() -> void:
	for r in residents:
		if r.age < 18 or r.money < 6500 or r.goal != "Открыть своё дело":
			continue
		if buildings.any(func(b): return b.owner == r.id):
			continue
		for y in range(2, 24, 4):
			for x in range(2, 24, 4):
				if buildings.any(func(b): return b.x == x and b.y == y):
					continue
				var kind = "shop" if of_type("shop").size() < 5 else "cafe"
				if build_at(kind, Vector2i(x, y), false, r.id) != "":
					continue
				r.money -= 6500
				buildings.back().cash = 6500.0
				r.goal_done = true
				_personal(r, "Открыл своё дело: %s." % Catalog.TYPES[kind].name)
				_news("Бизнес из мечты", "%s вложил сбережения и открыл %s." % [r.name, Catalog.TYPES[kind].name], "Бизнес", r.id)
				return

func _migration() -> void:
	# Move whole connected households only when the destination has enough beds.
	for r in residents:
		if r.age < 18 or (r.goal != "Переехать в новый дом" and r.broke_days < 2):
			continue
		var household = [r.id]
		for id in r.family:
			if residents[id].home == r.home:
				household.append(id)
		if r.partner >= 0 and r.partner not in household:
			household.append(r.partner)
		for b in buildings:
			var info: Dictionary = Catalog.TYPES[b.type]
			if info.homes <= 0 or b.id == r.home:
				continue
			var occupants = residents.filter(func(p): return p.home == b.id).size()
			if occupants + household.size() > info.homes:
				continue
			if r.broke_days >= 2 and info.rent >= Catalog.TYPES[buildings[r.home].type].rent:
				continue
			if r.goal_done and r.broke_days < 2:
				continue
			for id in household:
				residents[id].home = b.id
				_personal(residents[id], "Семья переехала: %s, %s." % [streets[mini(b.y / 4, 5)].name, Catalog.TYPES[b.type].name])
				r.goal_done = true
			_news("Новоселье", "Семья жителя %s нашла новый дом на улице %s." % [r.name, streets[mini(b.y / 4, 5)].name], "Семья", r.id)
			return

func _street_report() -> void:
	for i in streets.size():
		var quality = 45.0
		for b in buildings:
			if (b.y / 4) as int != i:
				continue
			quality += 12 if b.type == "park" else (-8 if b.closed else 3)
		var old = streets[i].quality
		streets[i].quality = clampf(quality, 0, 100)
		if absf(old - streets[i].quality) >= 8:
			_news("Пульс улицы", "Улица %s: качество среды %d/100. %s" % [streets[i].name, streets[i].quality, "Новые места притягивают людей." if quality > old else "Жителям нужны зелень и работа."], "Улицы")

func _check_goal(r: Dictionary) -> void:
	if r.goal_done:
		return
	var achieved = (r.goal == "Накопить 5 000 ₽" and r.money >= 5000) or (r.goal == "Найти друзей" and r.friends.size() >= 3) or (r.goal == "Создать семью" and r.partner >= 0)
	if achieved:
		r.goal_done = true
		r.mood = minf(100, r.mood + 15)
		_personal(r, "Исполнил мечту: %s." % r.goal)

func _personal(r: Dictionary, message: String) -> void:
	r.history.push_front({"day": day, "minute": minute, "text": message})
	if r.history.size() > 45:
		r.history.pop_back()

func _news(title: String, body: String, category: String, person: int = -1) -> void:
	events.push_front({"day": day, "minute": minute, "title": title, "body": body, "category": category, "person": person})
	if events.size() > 160:
		events.pop_back()

func stats() -> Dictionary:
	var employed = 0
	var workforce = 0
	var happiness = 0.0
	var wealth = 0.0
	var capacity = 0
	var jobs = 0
	for r in residents:
		if r.age >= 18 and r.age < 63:
			workforce += 1
			if r.work >= 0:
				employed += 1
		happiness += r.mood
		wealth += r.money
	for b in buildings:
		capacity += Catalog.TYPES[b.type].homes
		if not b.closed:
			jobs += Catalog.TYPES[b.type].jobs
	return {"population": residents.size(), "employed": employed, "workforce": workforce, "unemployment": (workforce - employed) * 100.0 / maxi(1, workforce), "mood": happiness / maxi(1, residents.size()), "wealth": wealth, "capacity": capacity, "jobs": jobs, "rent": rent_multiplier(), "purchases": total_purchases}

func serialize() -> Dictionary:
	return {"version": 1, "day": day, "minute": minute, "treasury": treasury, "tax_rate": tax_rate, "daily_income": daily_income, "daily_expense": daily_expense, "last_income": last_income, "last_expense": last_expense, "total_purchases": total_purchases, "rng_seed": str(rng.seed), "rng_state": str(rng.state), "residents": residents.duplicate(true), "buildings": buildings.duplicate(true), "roads": roads.duplicate(true), "events": events.duplicate(true), "ledger": ledger.duplicate(true), "streets": streets.duplicate(true)}

func restore(data: Dictionary) -> void:
	day = int(data.day)
	minute = int(data.minute)
	treasury = float(data.treasury)
	tax_rate = float(data.tax_rate)
	daily_income = float(data.daily_income)
	daily_expense = float(data.daily_expense)
	last_income = float(data.last_income)
	last_expense = float(data.last_expense)
	total_purchases = int(data.total_purchases)
	residents = data.residents.duplicate(true)
	buildings = data.buildings.duplicate(true)
	roads = data.roads.duplicate(true)
	events = data.events.duplicate(true)
	ledger = data.ledger.duplicate(true)
	streets = data.streets.duplicate(true)
	# JSON numbers are doubles; IDs remain integers in the runtime model.
	for r in residents:
		for key in ["id", "age", "home", "work", "partner", "destination", "wait_until", "broke_days", "employed_minutes"]:
			r[key] = int(r[key])
		for key in ["family", "friends", "rivals"]:
			r[key] = r[key].map(func(id): return int(id))
	for b in buildings:
		for key in ["id", "x", "y", "owner", "loss_days", "built_day"]:
			b[key] = int(b[key])
	rng.seed = int(data.rng_seed)
	rng.state = int(data.rng_state)
	_rebuild_navigation()
	revision += 1
