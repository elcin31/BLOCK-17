extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Store = preload("res://scripts/save_store.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var start = Time.get_ticks_msec()
	var city = Sim.new()
	city.new_city(17)
	check(city.residents.size() == 120, "120 autonomous residents")
	check(city.stats().capacity >= 120, "initial housing accommodates population")
	check(city.stats().employed > 50, "initial businesses employ residents")
	check(Store.validate(city.serialize()) == "", "new city passes save schema validation")
	for r in city.residents:
		check(r.family.size() == 3, "family references")
		check(city.buildings[r.home].type == "home", "everyone has a home")
	var before = city.residents[0].pos.duplicate()
	city.advance(120)
	check(city.residents.any(func(r): return r.activity == "Работает"), "people arrive at work")
	check(city.residents[0].pos != before, "residents physically travel")
	check(city.residents.any(func(r): return r.activity == "Учится"), "children attend school")
	var old_jobs = city.stats().jobs
	var budget = city.treasury
	check(city.build_at("office", Vector2i(18, 2)) == "", "office builds on empty lot")
	check(city.stats().jobs == old_jobs + 22, "construction creates real job capacity")
	check(is_equal_approx(city.treasury, budget - 48000), "construction debits city treasury")
	var size = city.buildings.size()
	check(city.build_at("home", Vector2i(18, 2)) != "", "occupied lot rejected")
	check(city.buildings.size() == size, "failed construction does not mutate buildings")
	var old_rent = city.rent_multiplier()
	check(city.build_at("home", Vector2i(10, 6)) == "", "new home builds")
	check(city.rent_multiplier() < old_rent, "new housing reduces rent pressure")
	check(city.build_at("road", Vector2i(21, 17)) == "", "connected road builds")
	check(city.road_lookup.has(Vector2i(21, 17)), "road updates navigation")
	check(city.build_at("home", Vector2i(22, 18)) != "", "building cannot cross custom road")
	city.treasury = 0
	check(city.build_at("home", Vector2i(22, 22)) != "", "insufficient budget rejected")
	check(city.build_at("park", Vector2i(-5, 0), false) != "", "out of bounds rejected")
	city.treasury = 180000
	city.advance(1200)
	check(city.total_purchases > 50, "residents purchase goods")
	check(city.daily_income > 0 or city.last_income > 0, "city receives real tax payments")
	check(city.ledger.size() > 0, "daily budget history recorded")
	check(city.residents.any(func(r): return r.rent > 0), "rent charged to adults")
	check(city.residents.any(func(r): return r.friends.size() > 0), "physical encounters form friendships")
	# Round-trip through the actual JSON file, including RNG and routes.
	check(Store.save_city(city, "slot3", {"test": true}) == OK, "atomic save succeeds")
	var loaded = Store.load_city("slot3")
	check(not loaded.has("error"), "save loads with checksum")
	var restored = Sim.new()
	restored.restore(loaded.simulation)
	check(restored.day == city.day and restored.minute == city.minute, "clock restored")
	check(restored.rng.state == city.rng.state, "RNG state restored without integer precision loss")
	check(restored.residents.size() == 120, "all residents restored")
	check(is_equal_approx(restored.treasury, city.treasury), "budget restored")
	city.advance(1440)
	restored.advance(1440)
	check(city.rng.state == restored.rng.state, "continued simulation stays deterministic")
	check(is_equal_approx(city.treasury, restored.treasury), "continued budget identical after load")
	for i in city.residents.size():
		check(is_equal_approx(city.residents[i].money, restored.residents[i].money), "continued resident finances identical")
		check(Vector2(city.residents[i].pos[0], city.residents[i].pos[1]).distance_to(Vector2(restored.residents[i].pos[0], restored.residents[i].pos[1])) < 0.001, "continued resident route identical")
	# Recover a deliberately corrupted primary from the previous verified write.
	check(Store.save_city(city, "slot3") == OK, "second atomic write creates backup")
	var corrupt = FileAccess.open(Store.path_for("slot3"), FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	var fallback = Store.load_city("slot3")
	check(not fallback.has("error") and fallback.get("recovered", false), "corrupt save recovers from backup")
	var malformed = city.serialize()
	malformed.residents[0].home = 9999
	check(Store.validate(malformed) != "", "invalid references rejected before restore")
	# Deterministically exercise autonomous business creation and layoffs.
	var entrepreneur = city.residents[0]
	entrepreneur.goal = "Открыть своё дело"
	entrepreneur.money = 10000.0
	var count_before = city.buildings.size()
	city._enterprise()
	check(city.buildings.size() == count_before + 1, "resident opens business using savings")
	check(city.buildings.back().owner == entrepreneur.id, "business ownership recorded")
	var shop = city.of_type("shop")[0]
	shop.cash = 0.0
	entrepreneur.work = shop.id
	entrepreneur.salary = 125.0
	entrepreneur.employed_minutes = 400
	city._payroll()
	check(entrepreneur.work == -1, "empty business account causes job loss")
	var social = Sim.new()
	social.new_city(23)
	for r in social.residents:
		r.pos = [0.0, 0.0]
		r.age = 30
		r.partner = -1
		r.family = []
		r.trait = "Общительный"
		for other in social.residents:
			if other.id != r.id:
				r.affinity[str(other.id)] = 40.0
	social._social_evening()
	check(social.residents.any(func(r): return r.partner >= 0), "repeated positive encounters create new families")
	for r in social.residents:
		if r.partner >= 0:
			check(social.residents[r.partner].partner == r.id, "partnership is reciprocal")
	for r in social.residents:
		r.trait = "Вспыльчивый"
		r.mood = 0.0
		r.affinity.clear()
	social._social_evening()
	check(social.residents.any(func(r): return not r.rivals.is_empty()), "negative encounters create conflicts")
	var moving = Sim.new()
	moving.new_city(31)
	var first_home = moving.residents[0].home
	moving.residents[0].goal = "Переехать в новый дом"
	moving.residents[0].goal_done = false
	moving._migration()
	check(moving.residents[0].home != first_home, "household chooses available new home")
	for id in [1, 2, 3]:
		check(moving.residents[id].home == moving.residents[0].home, "family moves together")
	for b in moving.buildings:
		var capacity = CityCatalog.TYPES[b.type].homes
		if capacity > 0:
			check(moving.residents.filter(func(r): return r.home == b.id).size() <= capacity, "migration respects housing capacity")
	# Long-run stability: 20 days, all systems enabled.
	var long_start = Time.get_ticks_msec()
	city.advance(20 * 1440)
	var long_ms = Time.get_ticks_msec() - long_start
	check(city.residents.size() == 120, "population remains intact in long run")
	check(is_finite(city.treasury), "long-run budget finite")
	check(city.events.size() <= 160 and city.ledger.size() <= 60, "history buffers bounded")
	for r in city.residents:
		check(is_finite(r.money) and r.money >= 0, "no invalid or negative household balances")
		check(r.mood >= 0 and r.mood <= 100, "needs remain bounded")
		check(r.home >= 0 and r.home < city.buildings.size(), "valid home after migrations")
		check(r.path.all(func(p): return city.road_lookup.has(Vector2i(p[0], p[1]))), "all routes stay on roads")
	check(Store.validate(city.serialize()) == "", "long-run city remains saveable")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.path_for("slot3") + suffix))
	print("SIMULATION: %d checks, %d failures; 20 days in %d ms; total %d ms" % [checks, failures, long_ms, Time.get_ticks_msec() - start])
	quit(1 if failures else 0)
