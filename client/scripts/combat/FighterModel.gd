extends Node2D
class_name FighterModel
## Procedural placeholder fighter — head/torso/arms/legs drawn with Godot's
## primitive draw calls, no external art assets. Head = HIGH region, torso =
## MID region (colored by the caller to match Combat.gd's existing telegraph/
## guard/hit/block semantics); the arm pose additionally animates with the
## punch phase and block state so there's a visible pose, not just a color.

const Combat := preload("res://shared/CombatConstants.gd")

const HEAD_RADIUS := 40.0
const TORSO_SIZE := Vector2(120, 160)
const TORSO_TOP := Vector2(-60, 30)
const LIMB_COLOR := Color(0.55, 0.42, 0.3)
const ARM_WIDTH := 18.0

## true = this fighter's arms extend to the right (it's facing right).
@export var facing_right: bool = true

var head_color: Color = Color.WHITE
var torso_color: Color = Color.WHITE
var punch_phase: int = Combat.PunchPhase.NONE
var punch_region: int = Combat.Region.NONE
var block_region: int = Combat.Region.NONE

func set_state(head_c: Color, torso_c: Color, phase: int, region: int, block: int) -> void:
	head_color = head_c
	torso_color = torso_c
	punch_phase = phase
	punch_region = region
	block_region = block
	queue_redraw()

func _draw() -> void:
	var dir := 1.0 if facing_right else -1.0

	# Legs (static stance, purely cosmetic).
	draw_rect(Rect2(Vector2(-40, 190), Vector2(28, 90)), LIMB_COLOR)
	draw_rect(Rect2(Vector2(12, 190), Vector2(28, 90)), LIMB_COLOR)

	# Torso = MID region.
	draw_rect(Rect2(TORSO_TOP, TORSO_SIZE), torso_color)

	# Head = HIGH region.
	draw_circle(Vector2.ZERO, HEAD_RADIUS, head_color)

	# Guarding arms — raised near the head for HIGH, crossed over the torso for MID.
	if block_region == Combat.Region.HIGH:
		draw_rect(Rect2(Vector2(-65 * dir - 15, -15), Vector2(30, 70)), LIMB_COLOR)
		draw_rect(Rect2(Vector2(35 * dir - 15, -15), Vector2(30, 70)), LIMB_COLOR)
	elif block_region == Combat.Region.MID:
		draw_rect(Rect2(Vector2(-55, 55), Vector2(110, 28)), LIMB_COLOR)

	# Punching arm: reach animates by phase so windup/active/recovery read as
	# a pose (chambered back -> extended -> pulling back), not just a color.
	if punch_phase != Combat.PunchPhase.NONE:
		var reach := 0.0
		match punch_phase:
			Combat.PunchPhase.WINDUP: reach = -20.0
			Combat.PunchPhase.ACTIVE: reach = 95.0
			Combat.PunchPhase.RECOVERY: reach = 25.0
		var start_y := -5.0 if punch_region == Combat.Region.HIGH else 95.0
		var start := Vector2(25.0 * dir, start_y)
		var end := start + Vector2(reach * dir, 0.0)
		draw_line(start, end, LIMB_COLOR, ARM_WIDTH, true)
