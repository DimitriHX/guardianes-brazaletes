@tool
class_name Player
extends CharacterBody2D
## A player's character, which can walk, jump, and stomp on enemies.

#region Input actions (arrow keys)
## Godot's built-in actions, already mapped to the keyboard arrows by default:
## left arrow, right arrow and up arrow. No extra Input Map setup is needed.
const ACTION_LEFT = "ui_left"
const ACTION_RIGHT = "ui_right"
const ACTION_JUMP = "ui_up"
#endregion

#region Constants used by special abilities
## The player-character's maximum downwards speed while gliding.
## Making this number smaller allows the player to glide further.
## [br][br]
## Used by [method _glide].
const GLIDE_TERMINAL_VELOCITY = 100
#endregion

#region Exported parameters that the game designer can adjust in the Inspector tab for the Player
## Which player is this character? (Kept for compatibility with the rest of the game;
## it no longer changes the controls.)
@export var player: Global.Player = Global.Player.ONE

## How fast does your character move?
@export_range(0, 1000, 10, "suffix:px/s") var speed: float = 500.0

## How fast does your character accelerate?
@export_range(0, 5000, 1000, "suffix:px/s²") var acceleration: float = 5000.0

## How high does your character jump? Note that the gravity will
## be influenced by the [member GameLogic.gravity].
@export_range(0, 2000, 10, "suffix:px/s") var jump_velocity = 880.0

## How much should the character's jump be reduced if you let go of the jump
## key before the top of the jump? [code]0[/code] means “not at all”;
## [code]100[/code] means “upwards movement completely stops”.
@export_range(0, 100, 5, "suffix:%") var jump_cut_factor: float = 20

## How long after the character walks off a ledge can they still jump?
## This is often set to a small positive number to allow the player a little
## margin for error before they start falling.
@export_range(0, 0.5, 1 / 60.0, "suffix:s") var coyote_time: float = 5.0 / 60.0

## If the character is about to land on the floor, how early can the player
## the jump key to jump as soon as the character lands? This is often set to
## a small positive number to allow the player a little margin for error.
@export_range(0, 0.5, 1 / 60.0, "suffix:s") var jump_buffer: float = 5.0 / 60.0

## Can your character jump a second time while still in the air?
@export var double_jump: bool = false
#endregion

#region Internal variables
# If positive, the player is either on the ground, or left the ground less than this long ago
var coyote_timer: float = 0

# If positive, the player pressed jump this long ago
var jump_buffer_timer: float = 0

# Set to true when the player jumps from the floor, if double_jump is true (i.e. double-jumps are
# enabled). When this is true, the player can press the jump button to perform a double-jump. Reset
# to false when the player performs a double-jump, or lands on the floor.
var double_jump_armed: bool = false

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Stores the player's original position when the game begins. Used by reset() to send the player
# back to the start of the level after losing a life.
var original_position: Vector2
#endregion

#region References to other nodes and resources in the Player scene
# A plain, static Sprite2D (no animations). Its node must be named "Sprite2D" and have
# "Access as Unique Name" enabled.
@onready var _sprite: Sprite2D = %Sprite2D
@onready var _double_jump_particles: CPUParticles2D = %DoubleJumpParticles

@onready var _jump_sfx: AudioStreamPlayer = %JumpSFX
@onready var _glide_sfx: AudioStreamPlayer = %GlideSFX
#endregion


# Called when the node enters the scene tree for the first time.
func _ready():
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
	else:
		Global.gravity_changed.connect(_on_gravity_changed)
		Global.lives_changed.connect(_on_lives_changed)

	original_position = position


#region Signal handlers
# Handler for the Global.gravity_changed signal.
func _on_gravity_changed(new_gravity):
	gravity = new_gravity


# Handler for the Global.lives_changed signal, which is emitted when the player loses a life.
func _on_lives_changed():
	if Global.lives > 0:
		reset()


#endregion


# Propels the player-character upwards, as if jumping. Used by _physics_process in response to
# player input, and by stomp() when the player-character stomps on an enemy.
func _jump():
	velocity.y = -jump_velocity
	coyote_timer = 0
	jump_buffer_timer = 0
	if double_jump_armed:
		double_jump_armed = false
		_double_jump_particles.emitting = true
	elif double_jump:
		double_jump_armed = true
	_jump_sfx.play()


## Called from [class Enemy] when the player-character stomps on an enemy.
func stomp():
	double_jump_armed = false
	_jump()


## If the player-character is in the air, and the jump action is held, clamp the downwards
## velocity to a constant. Should be called from [code]_physics_process[/code] after applying
## gravity to the player-character.
func _glide() -> void:
	if not is_on_floor() and Input.is_action_pressed(ACTION_JUMP):
		if velocity.y > GLIDE_TERMINAL_VELOCITY:
			velocity.y = GLIDE_TERMINAL_VELOCITY

		# Only play the sound effect when the player-character is moving downwards, not while
		# jumping upwards
		if velocity.y > 0 and not _glide_sfx.playing:
			_glide_sfx.play()
	elif _glide_sfx.playing:
		_glide_sfx.stop()


# Called by Godot for every physics frame. Moves the player-character in response to player inputs,
# gravity, and the physics of the level.
func _physics_process(delta):
	# Don't move if there are no lives left.
	if Global.lives <= 0:
		return

	# Handle jump
	if is_on_floor():
		coyote_timer = (coyote_time + delta)
		double_jump_armed = false

	if Input.is_action_just_pressed(ACTION_JUMP):
		jump_buffer_timer = (jump_buffer + delta)

	if jump_buffer_timer > 0 and (double_jump_armed or coyote_timer > 0):
		_jump()

	# Reduce velocity if the player lets go of the jump key before the apex.
	# This allows controlling the height of the jump.
	if Input.is_action_just_released(ACTION_JUMP) and velocity.y < 0:
		velocity.y *= (1 - (jump_cut_factor / 100.00))

	# Add the gravity.
	if coyote_timer <= 0:
		velocity.y += gravity * delta

	# Get the input direction and handle the movement/deceleration.
	var direction = Input.get_axis(ACTION_LEFT, ACTION_RIGHT)
	if direction:
		velocity.x = move_toward(
			velocity.x,
			sign(direction) * speed,
			abs(direction) * acceleration * delta,
		)
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)

	# Remove the '#' below to enable the glide special ability
	#_glide()

	move_and_slide()

	coyote_timer -= delta
	jump_buffer_timer -= delta


## Restore the player to their initial position in the level. Called by _on_lives_changed.
func reset():
	position = original_position
	velocity = Vector2.ZERO
	coyote_timer = 0
	jump_buffer_timer = 0
	double_jump_armed = false
