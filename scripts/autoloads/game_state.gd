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
