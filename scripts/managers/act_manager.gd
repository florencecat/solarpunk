class_name ActManager
extends Node

## Управляет трёхактовой структурой и мегапроектами.

const ACT_2_TURN: int = 21
const ACT_3_TURN: int = 61

# ─── Мегапроекты ─────────────────────────────────────────────────────────────
const MEGAPROJECTS: Dictionary = {
	0: {
		"name":         "Древо Жизни",
		"desc":         "Посадить и вырастить Древо в сердце оазиса — символ возрождения природы.",
		"cost_sand":    200, "cost_scrap": 100, "cost_diamonds": 50,
		"turns":        20,
		"requires_tech": 5,   # Зелёные технологии
		"victory_text": "Оазис расцвёл. Древо тянется к небу, даря тень и надежду всем жителям пустыни.",
	},
	1: {
		"name":         "Солнечный Шпиль",
		"desc":         "Башня фотовольтаики — маяк в пустыне. Источник чистой неиссякаемой энергии.",
		"cost_sand":    100, "cost_scrap": 200, "cost_diamonds": 50,
		"turns":        20,
		"requires_tech": 6,   # Солнечная энергетика
		"victory_text": "Шпиль сияет в пустыне. Энергия солнца теперь служит людям — навсегда.",
	},
	2: {
		"name":         "Великий Исход",
		"desc":         "Снарядить огромный ходячий-город и уйти к новой, зелёной земле.",
		"cost_sand":    50,  "cost_scrap": 150, "cost_diamonds": 30,
		"turns":        15,
		"requires_tech": 7,   # Дальняя навигация
		"victory_text": "Поселенцы уходят в горизонт. Позади — оазис. Впереди — мир, который ещё предстоит построить.",
	},
}

# ─────────────────────────────────────────────────────────────────────────────

func process_turn() -> void:
	_check_act_transition()
	_tick_megaproject()
	_check_victory()

# ─── Акты ────────────────────────────────────────────────────────────────────

func _check_act_transition() -> void:
	if GameState.current_act == 1 and GameState.current_turn >= ACT_2_TURN:
		GameState.current_act = 2
		EventBus.act_changed.emit(2)
		_log("Акт II: Расширение",
			"Поселение выстояло в начале. Пора расширяться — исследуйте технологии Акта II и укрепляйте оборону.",
			1)
	elif GameState.current_act == 2 and GameState.current_turn >= ACT_3_TURN:
		GameState.current_act = 3
		EventBus.act_changed.emit(3)
		_log("Акт III: Финал",
			"Время настало. Выберите Мегапроект и направьте все силы поселения на его завершение.",
			2)

# ─── Мегапроекты ─────────────────────────────────────────────────────────────

func start_megaproject(project_id: int) -> bool:
	if GameState.megaproject_id >= 0:
		_log("Мегапроект уже идёт", "Нельзя начать два проекта одновременно.", 1)
		return false
	if not project_id in GameState.unlocked_megaprojects:
		_log("Не разблокировано", "Сначала исследуйте нужную технологию.", 1)
		return false
	var mp: Dictionary = MEGAPROJECTS[project_id]
	if (GameState.sand     < float(mp.cost_sand)     or
		GameState.scrap    < float(mp.cost_scrap)    or
		GameState.diamonds < float(mp.cost_diamonds)):
		_log("Нет ресурсов",
			"Нужно: %d пес, %d мет, %d алм." % [mp.cost_sand, mp.cost_scrap, mp.cost_diamonds],
			1)
		return false
	GameState.sand     -= float(mp.cost_sand)
	GameState.scrap    -= float(mp.cost_scrap)
	GameState.diamonds -= float(mp.cost_diamonds)
	GameState.megaproject_id         = project_id
	GameState.megaproject_turns_left = int(mp.turns)
	EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)
	EventBus.megaproject_started.emit(project_id)
	_log("Мегапроект начат!",
		"«%s» — строительство займёт %d ходов." % [mp.name, mp.turns], 1)
	return true

func _tick_megaproject() -> void:
	if GameState.megaproject_id < 0:
		return
	GameState.megaproject_turns_left = maxi(0, GameState.megaproject_turns_left - 1)
	var total: int = int(MEGAPROJECTS[GameState.megaproject_id].turns)
	EventBus.megaproject_progress.emit(GameState.megaproject_turns_left, total)

func _check_victory() -> void:
	if GameState.is_victory or GameState.is_game_over:
		return
	if GameState.megaproject_id >= 0 and GameState.megaproject_turns_left <= 0:
		GameState.is_victory = true
		var mp: Dictionary = MEGAPROJECTS[GameState.megaproject_id]
		EventBus.victory.emit(GameState.megaproject_id, mp.victory_text)

# ─── Хелперы ─────────────────────────────────────────────────────────────────

func get_megaproject_data(project_id: int) -> Dictionary:
	return MEGAPROJECTS.get(project_id, {})

func _log(title: String, desc: String, sev: int) -> void:
	EventBus.game_event.emit({
		"turn": GameState.current_turn, "title": title,
		"description": desc, "severity": sev,
	})
