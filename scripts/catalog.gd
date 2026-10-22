class_name CityCatalog
extends RefCounted

const SIZE = 25
const POPULATION = 120
const FIRST_NAMES = ["Алексей", "Мария", "Денис", "Анна", "Илья", "София", "Марк", "Елена", "Тимур", "Алина", "Никита", "Вера", "Роман", "Ольга", "Артём", "Дарья", "Лев", "Нина", "Павел", "Ася"]
const LAST_NAMES = ["Волков", "Миронов", "Орлов", "Ким", "Соколов", "Лебедев", "Морозов", "Белов", "Зайцев", "Тихонов", "Смирнов", "Петров"]
const TRAITS = ["Общительный", "Амбициозный", "Бережливый", "Мечтатель", "Семьянин", "Вспыльчивый"]
const GOALS = ["Накопить 5 000 ₽", "Открыть своё дело", "Найти друзей", "Создать семью", "Переехать в новый дом"]
const TYPES = {
	"home": {"name": "Кирпичный дом", "cost": 22000, "homes": 18, "jobs": 0, "wage": 0, "upkeep": 35, "rent": 55, "color": "d99371", "category": "Жильё", "description": "18 мест. Новое жильё снижает давление на аренду."},
	"tower": {"name": "Светлый квартал", "cost": 42000, "homes": 30, "jobs": 0, "wage": 0, "upkeep": 65, "rent": 70, "color": "aac9c8", "category": "Жильё", "description": "30 мест. Просторные квартиры с террасой."},
	"shop": {"name": "Продукты у дома", "cost": 14000, "homes": 0, "jobs": 6, "wage": 125, "upkeep": 40, "rent": 0, "color": "e6c58c", "category": "Бизнес", "description": "6 рабочих мест. Продукты для жителей и выручка от покупок."},
	"cafe": {"name": "Кафе «Соседи»", "cost": 18000, "homes": 0, "jobs": 5, "wage": 140, "upkeep": 45, "rent": 0, "color": "e7a5a0", "category": "Бизнес", "description": "5 рабочих мест. Еда, знакомства и встречи после работы."},
	"office": {"name": "Бюро «Горизонт»", "cost": 48000, "homes": 0, "jobs": 22, "wage": 220, "upkeep": 120, "rent": 0, "color": "83b6c5", "category": "Бизнес", "description": "22 рабочих места. Зарабатывает на внешних заказах."},
	"workshop": {"name": "Городские мастерские", "cost": 34000, "homes": 0, "jobs": 16, "wage": 180, "upkeep": 90, "rent": 0, "color": "d5b374", "category": "Бизнес", "description": "16 рабочих мест. Производство и экспорт товаров."},
	"park": {"name": "Сквер", "cost": 7000, "homes": 0, "jobs": 0, "wage": 0, "upkeep": 30, "rent": 0, "color": "86b77f", "category": "Среда", "description": "Отдых, общение и настроение. Улучшает соседние улицы."},
	"clinic": {"name": "Поликлиника", "cost": 30000, "homes": 0, "jobs": 8, "wage": 185, "upkeep": 90, "rent": 0, "color": "d1e0cf", "category": "Город", "description": "8 бюджетных рабочих мест. Восстанавливает здоровье."},
	"school": {"name": "Школа № 17", "cost": 28000, "homes": 0, "jobs": 10, "wage": 165, "upkeep": 80, "rent": 0, "color": "d8b2a1", "category": "Город", "description": "10 бюджетных рабочих мест. Образование и развитие детей."},
	"road": {"name": "Улица и тротуар", "cost": 500, "homes": 0, "jobs": 0, "wage": 0, "upkeep": 2, "rent": 0, "color": "718b90", "category": "Среда", "description": "Соединяет дороги. Выберите свободную клетку у улицы."}
}

static func road_cell(x: int, y: int) -> bool:
	return x % 4 == 0 or y % 4 == 0

static func iso(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * 42.0, (p.x + p.y) * 21.0)

static func uniso(p: Vector2) -> Vector2:
	return Vector2((p.x / 42.0 + p.y / 21.0) * 0.5, (p.y / 21.0 - p.x / 42.0) * 0.5)

static func money(value: float) -> String:
	var number = str(absi(roundi(value)))
	var out = ""
	for i in number.length():
		if i > 0 and (number.length() - i) % 3 == 0:
			out += " "
		out += number[i]
	return ("−" if value < 0 else "") + out + " ₽"
