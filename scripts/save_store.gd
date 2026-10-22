class_name SaveStore
extends RefCounted
const VERSION = 1
const SLOTS = ["autosave", "slot1", "slot2", "slot3"]

static func path_for(slot: String) -> String:
	return "user://block17_%s.json" % slot

static func save_city(sim: CitySimulation, slot: String, extra: Dictionary = {}) -> Error:
	if slot not in SLOTS:
		return ERR_INVALID_PARAMETER
	var data = {"simulation": sim.serialize(), "extra": extra}
	var payload = JSON.stringify(data)
	var envelope = JSON.stringify({"format": "BLOCK17", "version": VERSION, "checksum": payload.sha256_text(), "payload": payload})
	var path = path_for(slot)
	var f = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(envelope)
	f.flush()
	f.close()
	if _read(path + ".tmp").has("error"):
		return ERR_FILE_CORRUPT
	var absolute = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute + ".bak")
		var backup = DirAccess.rename_absolute(absolute, absolute + ".bak")
		if backup != OK:
			return backup
	return DirAccess.rename_absolute(absolute + ".tmp", absolute)

static func load_city(slot: String) -> Dictionary:
	if slot not in SLOTS:
		return {"error": "Неизвестный слот"}
	var path = path_for(slot)
	var result = _read(path)
	if result.has("error") and FileAccess.file_exists(path + ".bak"):
		var recovered = _read(path + ".bak")
		if not recovered.has("error"):
			recovered["recovered"] = true
			return recovered
	return result

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "Сохранение пока не создано"}
	if FileAccess.get_file_as_bytes(path).size() > 16000000:
		return {"error": "Файл сохранения слишком большой"}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"error": "Сохранение повреждено"}
	var raw = parser.data
	if not raw is Dictionary or raw.get("format") != "BLOCK17" or raw.get("version") != VERSION:
		return {"error": "Формат сохранения не поддерживается"}
	if not raw.get("payload") is String or raw.get("checksum") != raw.payload.sha256_text():
		return {"error": "Сохранение повреждено"}
	if parser.parse(raw.payload) != OK:
		return {"error": "Данные города повреждены"}
	var data = parser.data
	if not data is Dictionary or not data.get("simulation") is Dictionary:
		return {"error": "Не найдены данные города"}
	var reason = validate(data.simulation)
	if reason != "":
		return {"error": reason}
	return data

static func validate(d: Dictionary) -> String:
	for key in ["version", "day", "minute", "treasury", "tax_rate", "daily_income", "daily_expense", "last_income", "last_expense", "total_purchases", "rng_seed", "rng_state", "residents", "buildings", "roads", "events", "ledger", "streets"]:
		if not d.has(key):
			return "В сохранении отсутствует поле: " + key
	if d.version != VERSION or d.day < 1 or d.minute < 0 or d.minute >= 1440:
		return "Некорректное игровое время"
	for key in ["residents", "buildings", "roads", "events", "ledger", "streets"]:
		if not d[key] is Array:
			return "Некорректная структура города"
	if d.residents.size() < 1 or d.residents.size() > 400 or d.buildings.size() < 1 or d.buildings.size() > 100 or d.streets.size() != 6:
		return "Некорректный размер города"
	for i in d.buildings.size():
		var b = d.buildings[i]
		if not b is Dictionary:
			return "Некорректное здание"
		for key in ["id", "type", "x", "y", "cash", "profit", "sales", "owner", "closed", "loss_days", "built_day"]:
			if not b.has(key):
				return "Неполные данные здания"
		if b.id != i or not CityCatalog.TYPES.has(b.type) or b.type == "road" or b.x < 0 or b.y < 2 or b.x >= 24 or b.y >= 24:
			return "Некорректная ссылка на здание"
	for i in d.residents.size():
		var r = d.residents[i]
		if not r is Dictionary:
			return "Некорректный житель"
		for key in ["id", "name", "age", "female", "trait", "appearance", "home", "work", "profession", "salary", "money", "expenses", "income", "rent", "mood", "food", "energy", "social", "health", "goal", "goal_done", "partner", "family", "friends", "rivals", "affinity", "history", "pos", "path", "destination", "activity", "wait_until", "broke_days", "employed_minutes"]:
			if not r.has(key):
				return "Неполные данные жителя"
		if r.id != i or r.home < 0 or r.home >= d.buildings.size() or r.work >= d.buildings.size() or r.destination < 0 or r.destination >= d.buildings.size():
			return "Некорректная ссылка жителя"
		if not r.pos is Array or r.pos.size() != 2 or not r.path is Array or not r.appearance is Dictionary:
			return "Некорректная позиция жителя"
		for key in ["skin", "hair", "shirt"]:
			if not r.appearance.has(key):
				return "Неполная внешность жителя"
		for key in ["family", "friends", "rivals"]:
			if not r[key] is Array:
				return "Некорректные отношения"
			for id in r[key]:
				if id < 0 or id >= d.residents.size():
					return "Отношения с неизвестным жителем"
	for p in d.roads:
		if not p is Array or p.size() != 2 or p[0] < 0 or p[1] < 0 or p[0] >= CityCatalog.SIZE or p[1] >= CityCatalog.SIZE:
			return "Некорректная дорога"
	return ""

static func metadata(slot: String) -> Dictionary:
	var data = load_city(slot)
	if data.has("error"):
		return data
	return {"day": int(data.simulation.day), "minute": int(data.simulation.minute), "population": data.simulation.residents.size(), "budget": data.simulation.treasury}
