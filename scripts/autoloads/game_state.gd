extends Node

# ─── Building type IDs ────────────────────────────────────────────────────────
const BUILDING_PUMP             = 0
const BUILDING_PURIFIER         = 1
const BUILDING_CONDENSER        = 2
const BUILDING_CARAVAN_STATION  = 3
const BUILDING_MINE             = 4

# ─── Building costs  {sand, scrap, diamonds} ──────────────────────────────────
const BUILDING_COSTS = {
	0: {"sand": 15, "scrap":  0, "diamonds": 0},  # PUMP
	1: {"sand": 10, "scrap": 10, "diamonds": 0},  # PURIFIER
	2: {"sand":  0, "scrap": 20, "diamonds": 1},  # CONDENSER
	3: {"sand":  0, "scrap": 40, "diamonds": 0},  # CARAVAN_STATION
	4: {"sand": 20, "scrap":  0, "diamonds": 0},  # MINE
}

# ─── Resources ────────────────────────────────────────────────────────────────
var water: float              = 200.0
var dirty_water: float        = 0.0
var water_production: float   = 0.0   # per turn
var water_consumption: float  = 0.0   # per turn
var water_net: float          = 0.0

var sand:     float = 30.0
var scrap:    float = 0.0
var diamonds: float = 0.0

# ─── Population ───────────────────────────────────────────────────────────────
var population: int     = 50
var happiness: float    = 100.0   # 0–100
var thirst: float       = 0.0     # 0–100, accumulates on shortage
var discontent: float   = 0.0     # 0–100, triggers riots

var is_rioting: bool          = false
var riot_turns_remaining: int = 0

# ─── Turn ─────────────────────────────────────────────────────────────────────
var current_turn: int         = 0
var auto_turn: bool           = false
var auto_turn_interval: float = 3.0

# ─── Laws ─────────────────────────────────────────────────────────────────────
var active_laws: Dictionary = {}

# ─── Map ──────────────────────────────────────────────────────────────────────
var hex_tiles: Dictionary    = {}   # Vector2i(q,r) → HexTile
var tile_workers: Dictionary = {}   # Vector2i(q,r) → int  (assigned workers)

# ─── Pending survivors ────────────────────────────────────────────────────────
var survivors_waiting: int = 0

# ─── Misc ─────────────────────────────────────────────────────────────────────
var selected_building_type: int = -1   # -1 = nothing selected
var sandstorm_active: bool      = false

# ─── Worker helpers ───────────────────────────────────────────────────────────

func get_assigned_workers() -> int:
	var total: int = 0
	for c in tile_workers:
		total += tile_workers[c]
	return total

func get_available_workers() -> int:
	return maxi(0, population - get_assigned_workers())

# ─── Деградация зданий ───────────────────────────────────────────────────────
var building_durability: Dictionary = {}  # Vector2i → float (0–100)

# ─── Прирост населения ────────────────────────────────────────────────────────
var growth_timer: int = 0

# ─── Испарение воды ───────────────────────────────────────────────────────────
const WATER_EVAP_RATE: float = 0.04     # 4% запаса в ход
var water_evaporation: float = 0.0

# ─── Подземные запасы воды ────────────────────────────────────────────────────
var tile_water_reserves: Dictionary = {}   # Vector2i → float (оставшиеся запасы)

func get_total_water_reserves() -> float:
	var total: float = 0.0
	for coords in tile_water_reserves:
		total += tile_water_reserves[coords]
	return total

# ─── Акты (3-актовая структура) ──────────────────────────────────────────────
var current_act: int = 1   # 1 = Основание, 2 = Расширение, 3 = Эндгейм

# ─── Исследования ─────────────────────────────────────────────────────────────
var unlocked_techs:      Array = []   # Array[int] — завершённые технологии
var active_research:     int   = -1   # ID технологии в работе, -1 = нет
var research_turns_left: int   = 0    # ходов до завершения текущего исследования

# ─── Мегапроекты ──────────────────────────────────────────────────────────────
var unlocked_megaprojects: Array = []   # Array[int] — доступные проекты
var megaproject_id:        int   = -1   # выбранный мегапроект (-1 = нет)
var megaproject_turns_left: int  = 0    # ходов до завершения строительства

# ─── Состояние игры ───────────────────────────────────────────────────────────
var is_game_over:   bool   = false
var is_victory:     bool   = false
var pending_choice: bool   = false      # ждём ответа игрока на событие

func get_score() -> int:
	return int(happiness * float(population) * float(current_turn) / 100.0)

# ─── Building affordability ───────────────────────────────────────────────────

func can_afford(b_type: int) -> bool:
	var cost: Dictionary = BUILDING_COSTS.get(b_type, {})
	return (sand     >= float(cost.get("sand",     0)) and
			scrap    >= float(cost.get("scrap",    0)) and
			diamonds >= float(cost.get("diamonds", 0)))

func spend_cost(b_type: int) -> void:
	var cost: Dictionary = BUILDING_COSTS.get(b_type, {})
	sand     = maxf(0.0, sand     - float(cost.get("sand",     0)))
	scrap    = maxf(0.0, scrap    - float(cost.get("scrap",    0)))
	diamonds = maxf(0.0, diamonds - float(cost.get("diamonds", 0)))
