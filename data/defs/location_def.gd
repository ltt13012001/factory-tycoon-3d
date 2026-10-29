## A place the business can grow into: a plot of land next to the first
## factory, a branch elsewhere in Vietnam, or a branch abroad. Factories
## there are run by their head (a factory manager or branch director) and
## are simulated as a whole, not machine by machine.
class_name LocationDef
extends Resource

## "local" (land next door), "domestic" (another province) or "abroad".
@export var region: String = "local"
@export var id: String = ""
@export var display_name: String = ""
@export var country: String = "Việt Nam"
@export_multiline var description: String = ""
## Sort order inside its region.
@export var order: int = 0
## Company stage (ExpansionManager.TIER_NAMES) needed before it can be chosen.
@export var min_tier: int = 0

@export_group("Costs")
## Survey fee (other provinces and abroad only; 0 skips the survey).
@export var survey_cost: int = 0
@export var survey_hours: int = 0
@export var land_cost: int = 0
@export var build_cost: int = 0
@export var build_hours: int = 12
## Daily rent, utilities and local staff of the whole site.
@export var upkeep_per_day: int = 6000

@export_group("Production")
@export var line_cost: int = 150000
## Profit per production line per day before bonuses.
@export var line_profit_per_day: int = 18000
@export var max_lines: int = 9
@export var head_wage_per_day: int = 12000
