class_name ResearchManager
extends Node

# ─── Дерево технологий ────────────────────────────────────────────────────────
# Ключ: int ID.  Поля:
#   act          — минимальный акт для доступа
#   cost_diamonds / cost_scrap — стоимость запуска
#   turns        — сколько ходов исследования
#   requires     — Array[int] предшествующих технологий
#   effect_key   — строковый ключ эффекта, применяемого в GameState
#   effect_value — числовое значение прибавки

const ALL_TECHS: Dictionary = {
	# ── Акт 1 ─────────────────────────────────────────────────────────────────
	0: {
		"name":          "Водоочистка",
		"desc":          "Улучшенные фильтры. Очистители работают на 25% эффективнее.",
		"act":           1,
		"cost_diamonds": 1, "cost_scrap": 30,
		"turns":         5,  "requires":  [],
		"effect_key":    "purifier_mult", "effect_value": 0.25,
	},
	1: {
		"name":          "Горнодобыча",
		"desc":          "Шахтёры добывают на 20% больше металлолома.",
		"act":           1,
		"cost_diamonds": 1, "cost_scrap": 20,
		"turns":         5,  "requires":  [],
		"effect_key":    "mine_mult",     "effect_value": 0.20,
	},
	2: {
		"name":          "Торговые пути",
		"desc":          "Расширенная сеть торговли. Шанс каравана вырастает на 5%.",
		"act":           1,
		"cost_diamonds": 2, "cost_scrap": 40,
		"turns":         7,  "requires":  [],
		"effect_key":    "caravan_bonus", "effect_value": 0.05,
	},
	# ── Акт 2 ─────────────────────────────────────────────────────────────────
	3: {
		"name":          "Атмосферная конденсация",
		"desc":          "Продвинутые конденсаторы собирают на 50% больше воды из воздуха.",
		"act":           2,
		"cost_diamonds": 3, "cost_scrap": 60,
		"turns":         10, "requires":  [0],
		"effect_key":    "condenser_mult", "effect_value": 0.50,
	},
	4: {
		"name":          "Коммунальный уклад",
		"desc":          "Совместный труд. Недовольство спадает в 1.5× быстрее.",
		"act":           2,
		"cost_diamonds": 2, "cost_scrap": 50,
		"turns":         8,  "requires":  [],
		"effect_key":    "discord_cool_mult", "effect_value": 0.50,
	},
	5: {
		"name":          "Зелёные технологии",
		"desc":          "Устойчивые методы хозяйства. Разблокирует мегапроект «Древо Жизни».",
		"act":           2,
		"cost_diamonds": 4, "cost_scrap": 80,
		"turns":         12, "requires":  [4],
		"effect_key":    "unlock_mp", "effect_value": 0.0,  # megaproject 0
	},
	# ── Акт 3 ─────────────────────────────────────────────────────────────────
	6: {
		"name":          "Солнечная энергетика",
		"desc":          "Фотовольтаика. Вся инфраструктура +15% выработки. Разблокирует «Солнечный Шпиль».",
		"act":           3,
		"cost_diamonds": 5, "cost_scrap": 100,
		"turns":         15, "requires":  [3],
		"effect_key":    "global_mult", "effect_value": 0.15,
	},
	7: {
		"name":          "Дальняя навигация",
		"desc":          "Карты, компасы, разведчики. Разблокирует мегапроект «Исход».",
		"act":           3,
		"cost_diamonds": 5, "cost_scrap": 80,
		"turns":         15, "requires":  [2],
		"effect_key":    "unlock_mp", "effect_value": 0.0,  # megaproject 2
	},
}

# Аддитивные бонусы, суммируются из всех завершённых технологий
# Читаются менеджерами напрямую из GameState
const BONUS_KEYS = [
	"purifier_mult", "mine_mult", "caravan_bonus",
	"condenser_mult", "discord_cool_mult", "global_mult",
]

# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Инициализируем бонусы в game_state
	if not GameState.has_meta("research_bonuses"):
		GameState.set_meta("research_bonuses", {
			"purifier_mult":     0.0,
			"mine_mult":         0.0,
			"caravan_bonus":     0.0,
			"condenser_mult":    0.0,
			"discord_cool_mult": 0.0,
			"global_mult":       0.0,
		})

func process_turn() -> void:
	if GameState.active_research < 0:
		return
	GameState.research_turns_left -= 1
	if GameState.research_turns_left <= 0:
		_complete(GameState.active_research)

# ─── Публичное API ────────────────────────────────────────────────────────────

func start_research(tech_id: int) -> bool:
	if GameState.active_research >= 0:
		_log("Уже идёт исследование", "Отмените текущее, прежде чем начать новое.", 1)
		return false
	if not can_research(tech_id):
		return false
	var tech: Dictionary = ALL_TECHS[tech_id]
	if GameState.diamonds < float(tech.cost_diamonds) or GameState.scrap < float(tech.cost_scrap):
		_log("Нет ресурсов",
			"Нужно %d алм. и %d лома." % [tech.cost_diamonds, tech.cost_scrap], 1)
		return false
	GameState.diamonds -= float(tech.cost_diamonds)
	GameState.scrap    -= float(tech.cost_scrap)
	GameState.active_research     = tech_id
	GameState.research_turns_left = int(tech.turns)
	EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)
	EventBus.research_started.emit(tech_id)
	_log("Исследование начато",
		"«%s» — завершится через %d ходов." % [tech.name, tech.turns], 0)
	return true

func cancel_research() -> void:
	if GameState.active_research < 0:
		return
	var tech: Dictionary = ALL_TECHS[GameState.active_research]
	# Возврат 50% ресурсов
	GameState.diamonds += float(tech.cost_diamonds) * 0.5
	GameState.scrap    += float(tech.cost_scrap)    * 0.5
	GameState.active_research     = -1
	GameState.research_turns_left = 0
	EventBus.resources_changed.emit(GameState.sand, GameState.scrap, GameState.diamonds)

func can_research(tech_id: int) -> bool:
	if not ALL_TECHS.has(tech_id):
		return false
	if tech_id in GameState.unlocked_techs:
		return false
	if tech_id == GameState.active_research:
		return false
	var tech: Dictionary = ALL_TECHS[tech_id]
	if int(tech.act) > GameState.current_act:
		return false
	for req: int in tech.requires:
		if not req in GameState.unlocked_techs:
			return false
	return true

func get_bonus(key: String) -> float:
	var b: Dictionary = GameState.get_meta("research_bonuses", {})
	return b.get(key, 0.0)

# ─── Внутренние ───────────────────────────────────────────────────────────────

func _complete(tech_id: int) -> void:
	GameState.unlocked_techs.append(tech_id)
	GameState.active_research     = -1
	GameState.research_turns_left = 0
	var tech: Dictionary = ALL_TECHS[tech_id]
	_apply_effect(tech_id, tech)
	EventBus.tech_researched.emit(tech_id)
	_log("Исследование завершено!",
		"«%s» — %s" % [tech.name, tech.desc], 1)

func _apply_effect(tech_id: int, tech: Dictionary) -> void:
	var key: String  = tech.effect_key
	var val: float   = float(tech.effect_value)
	var bonuses: Dictionary = GameState.get_meta("research_bonuses", {})

	if key == "unlock_mp":
		# tech 5 → mp 0 (Древо), tech 7 → mp 2 (Исход)
		var mp_id = 0 if tech_id == 5 else 2
		if not mp_id in GameState.unlocked_megaprojects:
			GameState.unlocked_megaprojects.append(mp_id)
	elif bonuses.has(key):
		bonuses[key] += val
		GameState.set_meta("research_bonuses", bonuses)

func _log(title: String, desc: String, sev: int) -> void:
	EventBus.game_event.emit({
		"turn": GameState.current_turn, "title": title,
		"description": desc, "severity": sev,
	})
