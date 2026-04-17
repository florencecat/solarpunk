extends Node

# ─── Building type IDs ────────────────────────────────────────────────────────
const BUILDING_PUMP             = 0
const BUILDING_PURIFIER         = 1
const BUILDING_CONDENSER        = 2
const BUILDING_CARAVAN_STATION  = 3

# ─── Resources ────────────────────────────────────────────────────────────────
var water: float              = 200.0
var dirty_water: float        = 0.0
var water_production: float   = 0.0   # per turn
var water_consumption: float  = 0.0   # per turn
var water_net: float          = 0.0

# ─── Population ───────────────────────────────────────────────────────────────
var population: int     = 50
var happiness: float    = 100.0   # 0–100
var thirst: float       = 0.0     # 0–100, accumulates on shortage
var discontent: float   = 0.0     # 0–100, triggers riots

var is_rioting: bool         = false
var riot_turns_remaining: int = 0

# ─── Turn ─────────────────────────────────────────────────────────────────────
var current_turn: int       = 0
var auto_turn: bool         = false
var auto_turn_interval: float = 3.0

# ─── Laws ─────────────────────────────────────────────────────────────────────
# Keys match LawsManager.LAW_* constants
var active_laws: Dictionary = {}

# ─── Map ──────────────────────────────────────────────────────────────────────
var hex_tiles: Dictionary = {}   # Vector2i(q,r) → HexTile

# ─── Pending survivors ────────────────────────────────────────────────────────
var survivors_waiting: int = 0

# ─── Misc ─────────────────────────────────────────────────────────────────────
var selected_building_type: int = -1   # -1 = nothing selected
var sandstorm_active: bool = false
