extends Control
class_name Fighter3D
## Renders one fighter as a real 3D character inside a SubViewport, composited
## into the existing 2D Combat scene — the HUD, buttons, and combat state
## machine (Fighter.gd) don't change at all, only what's drawn for the body.
##
## Until a real character is assigned, this draws a plain capsule stand-in so
## the animation-state wiring is testable today. To use a real character:
##   1. Set `character_scene` to an imported glTF/.glb PackedScene whose root
##      is a Node3D containing a Skeleton3D + AnimationPlayer (e.g. a Mixamo
##      character merged with Mixamo animations via Blender, exported as .glb
##      — see docs/PROGRESS.md decision log for the sourcing steps).
##   2. Fill in the animation name exports below to match whatever clip names
##      ended up in that file. A name that doesn't match an existing
##      animation is silently skipped rather than erroring, so this keeps
##      working with a partially-set-up character.
##
## Which region (HIGH/MID) is being telegraphed/guarded/hit/blocked is shown
## via two small colored indicator dots overlaid on the viewport, not by
## recoloring the character — a real mesh doesn't have a "head color" to set.

const Combat := preload("res://shared/CombatConstants.gd")
const Colors := preload("res://scripts/combat/CombatColors.gd")

@export var character_scene: PackedScene
@export var facing_right: bool = true
@export var idle_animation := "Idle"
@export var guard_high_animation := "Idle"
@export var guard_mid_animation := "Idle"
@export var punch_high_animation := "Idle"
@export var punch_mid_animation := "Idle"

const VIEWPORT_SIZE := Vector2i(220, 320)

var _anim_player: AnimationPlayer
var _head_indicator: Panel
var _torso_indicator: Panel
var _last_phase: int = Combat.PunchPhase.NONE

func _ready() -> void:
	custom_minimum_size = Vector2(VIEWPORT_SIZE)
	_build_scene()

func _build_scene() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = true
	container.add_child(viewport)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	viewport.add_child(light)

	var camera := Camera3D.new()
	var facing_offset := 1.0 if facing_right else -1.0
	camera.position = Vector3(0.3 * facing_offset, 1.4, 3.2)
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)

	var character: Node3D = character_scene.instantiate() if character_scene else _build_placeholder_capsule()
	viewport.add_child(character)
	if not facing_right:
		character.rotation_degrees.y = 180

	_anim_player = character.find_child("AnimationPlayer", true, false) as AnimationPlayer

	_head_indicator = _build_indicator(Vector2(85, 8))
	add_child(_head_indicator)
	_torso_indicator = _build_indicator(Vector2(70, 108))
	add_child(_torso_indicator)

func _build_placeholder_capsule() -> Node3D:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 1.8
	capsule.radius = 0.35
	mesh.mesh = capsule
	mesh.position = Vector3(0, 0.9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.6, 0.65)
	mesh.material_override = mat
	return mesh

func _build_indicator(pos: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = Vector2(50, 50)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		style.set("corner_radius_" + corner, 25)
	panel.add_theme_stylebox_override("panel", style)
	return panel

## Same signature FighterModel.gd (the 2D renderer) uses, so Combat.gd's
## calling code is identical regardless of which renderer is in play.
func set_state(head_color: Color, torso_color: Color, phase: int, region: int, block: int) -> void:
	_set_indicator(_head_indicator, head_color)
	_set_indicator(_torso_indicator, torso_color)
	_update_animation(phase, region, block)

func _set_indicator(panel: Panel, color: Color) -> void:
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if color.is_equal_approx(Colors.NEUTRAL):
		style.bg_color = Color(0, 0, 0, 0)
	else:
		style.bg_color = Color(color.r, color.g, color.b, 0.9)

func _update_animation(phase: int, region: int, block: int) -> void:
	if not _anim_player:
		return  # placeholder capsule has no animations — indicators alone carry the signal
	if phase != Combat.PunchPhase.NONE and phase != _last_phase:
		_play_if_exists(punch_high_animation if region == Combat.Region.HIGH else punch_mid_animation)
	elif phase == Combat.PunchPhase.NONE:
		var anim := idle_animation
		if block == Combat.Region.HIGH:
			anim = guard_high_animation
		elif block == Combat.Region.MID:
			anim = guard_mid_animation
		if _anim_player.current_animation != anim:
			_play_if_exists(anim)
	_last_phase = phase

func _play_if_exists(anim_name: String) -> void:
	if anim_name != "" and _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name)
