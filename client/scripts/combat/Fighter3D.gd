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
## Played once (not looped) on the target when a punch actually lands on
## that region; resumes the fighter's normal idle/guard pose afterward.
@export var hit_reaction_high_animation := ""
@export var hit_reaction_mid_animation := ""
## Played once and held on its final frame when this fighter's health hits 0.
@export var ko_animation := ""

const VIEWPORT_SIZE := Vector2i(360, 460)
## Local-space (within this Control) screen position of the character's
## head/torso, measured by scanning a real rendered frame for the actual
## pixel bounding box — not guessed. Used both for the indicator dots below
## and by Combat.gd to anchor the "HIT!"/"BLOCKED!" text callouts to the
## real body position instead of a fixed offset from model.position.
const HEAD_LOCAL_CENTER := Vector2(177, 154)
const TORSO_LOCAL_CENTER := Vector2(177, 225)

var _anim_player: AnimationPlayer
var _head_indicator: Panel
var _torso_indicator: Panel
var _last_phase: int = Combat.PunchPhase.NONE
var _last_block: int = Combat.Region.NONE
## False until the first _update_animation call sets an initial pose —
## forces that first call to actually start idle rather than being skipped
## by the "nothing changed" guard (both _last_phase and _last_block start
## at their NONE defaults, indistinguishable from an unchanged rest state).
var _idle_started := false
## Bumped by every call that changes what's currently playing (a new punch,
## a new hit reaction, or an explicit block-state change). A pending
## transient-resume timer (see _play_transient_then_resume) captures the
## token at schedule time and only acts if it's still current — otherwise a
## stale timer from an interrupted clip would stomp whatever plays after it.
var _token: int = 0

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
	# Without this, sibling SubViewports share one World3D — with two
	# skinned characters animating simultaneously (player + dummy) this
	# caused visibly broken/frozen skinning in one of them under the GL
	# Compatibility renderer. Each fighter needs its own isolated 3D world.
	viewport.own_world_3d = true
	container.add_child(viewport)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	viewport.add_child(light)

	var camera := Camera3D.new()
	# Closer than the old z=4.6 (that was zoomed out to fit a straight-on
	# punch reach) — now that the character is rotated to a 3/4 stance
	# instead of facing the camera dead-on, the punch reaches mostly
	# sideways within frame rather than toward the lens.
	camera.position = Vector3(0, 1.3, 2.9)
	camera.fov = 52
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)

	var character: Node3D = character_scene.instantiate() if character_scene else _build_placeholder_capsule()
	viewport.add_child(character)
	# Default import forward faces the camera (+Z). Turn each fighter
	# partway toward the opponent's side of the screen (a 3/4 stance, not a
	# flat 90-degree profile) instead of both just facing the camera —
	# that's what made them look like they were facing away from each
	# other rather than fighting each other.
	character.rotation_degrees.y = 70.0 if facing_right else -70.0

	# The Mixamo "Beta" character ships two overlapping skinned meshes: the
	# real skin ("*_Surface") and a joint/rigging-cage visualization mesh
	# ("*_Joints") that isn't meant to be rendered — showing both looks like
	# two ghosted bodies stacked on top of each other.
	for mesh in character.find_children("*Joints*", "MeshInstance3D", true, false):
		mesh.visible = false

	_anim_player = character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	# Idle isn't playable yet here — Combat.gd donates the idle clip via
	# add_animation() right after this node enters the tree, which happens
	# after _build_scene() returns. _update_animation()'s _idle_started
	# check kicks off idle on its first real call instead, by which point
	# the donation has already happened.

	# These were measured directly against a real render (pixel bounding-box
	# scan of the character's actual head/torso rows within the 360x460
	## viewport), not guessed — the old fixed offsets (85,8)/(70,108) were
	# tuned for an earlier camera/viewport setup and drifted badly out of
	# sync with the character's real screen position after later changes.
	_head_indicator = _build_indicator(HEAD_LOCAL_CENTER - Vector2(25, 25))
	add_child(_head_indicator)
	_torso_indicator = _build_indicator(TORSO_LOCAL_CENTER - Vector2(25, 25))
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
	# A punch trigger takes over motion for its duration. Trigger only on the
	# NONE -> punch transition, not on every internal WINDUP/ACTIVE/RECOVERY
	# phase change within the same punch — a punch resolves in a fraction of
	# a second but the clip is ~1s long, so re-triggering per phase kept
	# restarting it back to frame 0 before it ever got to show real motion.
	# The clip is also longer than the punch's own tick lifecycle (WINDUP+
	# ACTIVE+RECOVERY totals well under 1s), so its return to idle/guard is
	# driven by its own length via _play_transient_then_resume, NOT by phase
	# returning to NONE — doing it on the phase transition cut every punch
	# off mid-swing and could also stomp a just-triggered hit reaction that
	# happened to land on the same tick this fighter's own punch finished.
	if _last_phase == Combat.PunchPhase.NONE and phase != Combat.PunchPhase.NONE:
		_play_transient_then_resume(punch_high_animation if region == Combat.Region.HIGH else punch_mid_animation)
	elif phase == Combat.PunchPhase.NONE:
		if not _idle_started or block != _last_block:
			# Block state just changed, or this is the very first pose this
			# fighter shows. A punch naturally finishing is handled by its
			# own resume timer above, not here.
			_set_block_pose(block)
			_idle_started = true
	_last_phase = phase
	_last_block = block

func _play_once(anim_name: String) -> void:
	if anim_name == "" or not _anim_player.has_animation(anim_name):
		return
	_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_NONE
	_anim_player.play(anim_name)

## Idle/guard poses loop continuously for as long as they're the active
## state (all three sourced clips are stance loops, not a single held pose).
func _set_block_pose(block: int) -> void:
	_token += 1  # invalidate any pending transient-resume timer
	if block == Combat.Region.HIGH:
		_play_looping(guard_high_animation)
	elif block == Combat.Region.MID:
		_play_looping(guard_mid_animation)
	else:
		_play_looping(idle_animation)

func _play_looping(anim_name: String) -> void:
	if anim_name == "" or not _anim_player.has_animation(anim_name):
		return
	_anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	_anim_player.play(anim_name)

## Plays a one-shot clip (a punch or a landed-hit reaction) and, once it's
## had time to finish, resumes whatever idle/guard pose this fighter should
## currently be in — UNLESS something newer (another punch, a hit reaction,
## an explicit block change) has already taken over by then, tracked via
## _token so a stale timer from an interrupted clip can't stomp it.
func _play_transient_then_resume(anim_name: String) -> void:
	if anim_name == "" or not _anim_player.has_animation(anim_name):
		return
	_play_once(anim_name)
	_token += 1
	var my_token := _token
	var length: float = _anim_player.get_animation(anim_name).length
	get_tree().create_timer(length).timeout.connect(func():
		if my_token == _token:
			_set_block_pose(_last_block)
	)

## Plays once on the tick a punch actually lands on this fighter, then
## resumes whatever pose (idle/guard) this fighter should currently be in.
## Independent of _update_animation's own phase/block tracking, since a hit
## reaction is driven by the OPPONENT's punch resolving, not this fighter's
## own state changing.
func play_hit_reaction(region: int) -> void:
	if not _anim_player:
		return
	var anim_name := hit_reaction_high_animation if region == Combat.Region.HIGH else hit_reaction_mid_animation
	_play_transient_then_resume(anim_name)

## Plays once and freezes on its final frame — called when this fighter's
## health hits 0. Not resumed from; the match is over.
func play_ko() -> void:
	if not _anim_player or ko_animation == "" or not _anim_player.has_animation(ko_animation):
		return
	_token += 1  # invalidate any pending transient-resume timer — KO is never resumed from
	_play_once(ko_animation)

## Mixamo only bakes one clip per download. To assemble a full move set from
## several separate downloads (each sharing the same "Beta" mesh/rig), donate
## a clip from another file into this fighter's own AnimationPlayer under a
## new name, rather than swapping the whole character each time.
func add_animation(new_name: String, donor_scene: PackedScene, donor_anim_name: String) -> void:
	if not _anim_player or not donor_scene:
		return
	var donor := donor_scene.instantiate()
	var donor_ap := donor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if donor_ap and donor_ap.has_animation(donor_anim_name):
		_anim_player.get_animation_library("").add_animation(new_name, donor_ap.get_animation(donor_anim_name))
	donor.queue_free()
