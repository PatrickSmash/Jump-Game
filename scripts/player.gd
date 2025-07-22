@tool
class_name Player
extends CharacterBody2D

## This is the Player script - it controls the player character
## It handles movement, jumping, dashing, and all player interactions
## Think of it as the "controller" that translates player input into character actions

# ============================================================================
# EXPORT VARIABLES - These appear in the Godot editor for customization
# ============================================================================

## Use this to change the sprite frames of your character
## SpriteFrames contain all the animations (idle, walk, jump, etc.)
@export var sprite_frames: SpriteFrames = _initial_sprite_frames:
	set = _set_sprite_frames

## How fast does your character move horizontally?
## Higher values = faster movement
@export_range(0, 1000, 5, "suffix:px/s") var speed: float = 500.0:
	set = _set_speed

## How fast does your character accelerate?
## Higher values = character reaches max speed faster
@export_range(0, 5000, 1000, "suffix:px/s²") var acceleration: float = 5000.0

## How high does your character jump?
## More negative values = higher jumps
## Note: gravity affects how high you actually go
@export_range(-1000, 1000, 10, "suffix:px/s") var jump_velocity = -440.0

## How much should the character's jump be reduced if you let go of the jump
## key before the top of the jump?
## 0 = no reduction, 100 = jump stops completely
## This allows players to control jump height
@export_range(0, 100, 5, "suffix:%") var jump_cut_factor: float = 20

## How long after the character walks off a ledge can they still jump?
## This is "coyote time" - gives players a small grace period
## Named after Wile E. Coyote who could run off cliffs briefly
@export_range(0, 0.5, 1 / 60.0, "suffix:s") var coyote_time: float = 5.0 / 60.0

## If the character is about to land on the floor, how early can the player
## press the jump key to jump as soon as the character lands?
## This is "jump buffering" - makes controls feel more responsive
@export_range(0, 0.5, 1 / 60.0, "suffix:s") var jump_buffer: float = 5.0 / 60.0

# ============================================================================
# DASH MECHANIC VARIABLES
# ============================================================================

## How fast the character moves during a dash
@export_range(0, 2000, 10, "suffix:px/s") var dash_speed: float = 750.0

## How much to reduce diagonal dash speed (0.7 = 70% of normal dash speed)
## This prevents diagonal dashes from being faster than horizontal/vertical
@export_range(0.1, 1.0, 0.1, "suffix:x") var diagonal_dash_multiplier: float = 0.7

## How much to reduce upward dash speed (0.5 = 50% of normal dash speed)
@export_range(0.1, 1.0, 0.1, "suffix:x") var upward_dash_multiplier: float = 0.5

## How long the dash lasts
@export_range(0, 1, 0.01, "suffix:s") var dash_duration: float = 1.0

## How long to wait before the player can dash again
@export_range(0, 5, 0.1, "suffix:s") var dash_cooldown: float = 1.0

## Maximum number of dashes allowed before touching the floor
@export_range(1, 5, 1) var max_dash_count: int = 2

## How often to create duplicate sprites during dash (in seconds)
@export_range(0.01, 0.5, 0.01, "suffix:s") var duplicate_spawn_rate: float = 0.05

## How long each duplicate sprite lasts
@export_range(0.1, 2.0, 0.1, "suffix:s") var duplicate_lifetime: float = 0.5

## Initial opacity of duplicate sprites (0.0 = invisible, 1.0 = fully visible)
@export_range(0.0, 1.0, 0.1) var duplicate_initial_alpha: float = 0.5

## Is the character currently dashing?
var is_dashing: bool = false

## Time remaining in current dash
var dash_timer: float = 0.0

## Time remaining before dash is available again
var dash_cooldown_timer: float = 0.0

## Current number of dashes used since last touching the floor
var dash_count: int = 0

## Direction of the dash as a Vector2 (allows diagonal dashing)
## Examples: Vector2(-1, 0) = left, Vector2(1, -1) = up-right diagonal
var dash_direction: Vector2 = Vector2.ZERO

## Timer for spawning duplicate sprites
var duplicate_spawn_timer: float = 0.0

## Array to store active duplicate sprites
var active_duplicates: Array[Node2D] = []

# ============================================================================
# FAST FALL MECHANIC VARIABLES
# ============================================================================

## How fast the character falls when holding down
@export_range(0, 2000, 10, "suffix:px/s") var down_speed: float = 1000.0

## Is the character currently fast-falling?
var is_down: bool = false

## Direction of the fast fall (currently unused but kept for consistency)
var down_direction: int = 0

# ============================================================================
# DOUBLE JUMP MECHANIC VARIABLES
# ============================================================================

## Can your character jump a second time while still in the air?
@export var double_jump: bool = false

## If true, the player can perform a double-jump
## This is set to true after the first jump, false after double-jump or landing
var double_jump_armed: bool = false

# ============================================================================
# JUMP TIMING VARIABLES
# ============================================================================

## If positive, the player is either on the ground, or left the ground
## less than this long ago (coyote time)
var coyote_timer: float = 0

## If positive, the player pressed jump this long ago (jump buffer)
var jump_buffer_timer: float = 0

# ============================================================================
# PHYSICS AND GAME STATE VARIABLES
# ============================================================================

## Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

## Store the character's starting position for respawning
var original_position: Vector2

## Whether the game is currently active (not paused/ended)
var game_is_active: bool = true

# ============================================================================
# NODE REFERENCES - These connect to child nodes in the scene
# ============================================================================

## Reference to the animated sprite that displays the character
@onready var _sprite: AnimatedSprite2D = %AnimatedSprite2D

## Store the initial sprite frames for resetting
@onready var _initial_sprite_frames: SpriteFrames = %AnimatedSprite2D.sprite_frames

## Particle effect for double jump
@onready var _double_jump_particles: CPUParticles2D = %DoubleJumpParticles

# ============================================================================
# SETTER FUNCTIONS - These are called when export variables change
# ============================================================================

## Called when sprite_frames is changed in the editor or code
func _set_sprite_frames(new_sprite_frames):
	sprite_frames = new_sprite_frames
	# Only update the sprite if the node is ready
	if sprite_frames and is_node_ready():
		_sprite.sprite_frames = sprite_frames

## Called when speed is changed in the editor or code
func _set_speed(new_speed):
	speed = new_speed
	# Wait for the node to be ready if it isn't already
	if not is_node_ready():
		await ready
	
	# Adjust animation speed based on movement speed
	# This makes the walk animation match the actual movement speed
	if speed == 0:
		_sprite.speed_scale = 0  # Stop animation if not moving
	else:
		# Scale animation speed relative to base speed of 500
		_sprite.speed_scale = speed / 500

# ============================================================================
# DUPLICATE EFFECT FUNCTIONS
# ============================================================================

## Creates a duplicate sprite at the player's current position
func _create_duplicate():
	# Create a new sprite node
	var duplicate_sprite = AnimatedSprite2D.new()
	
	# Copy all visual properties from the main sprite
	duplicate_sprite.sprite_frames = _sprite.sprite_frames
	duplicate_sprite.animation = _sprite.animation
	duplicate_sprite.frame = _sprite.frame
	duplicate_sprite.flip_h = _sprite.flip_h
	duplicate_sprite.flip_v = _sprite.flip_v
	duplicate_sprite.scale = _sprite.scale
	
	# Set position to match current player position
	duplicate_sprite.global_position = _sprite.global_position
	
	# Add some visual variety - slightly randomize the duplicate
	duplicate_sprite.modulate = Color(
		randf_range(0.8, 1.0),  # Slight red variation
		randf_range(0.8, 1.0),  # Slight green variation
		randf_range(0.9, 1.0),  # Slight blue variation
		duplicate_initial_alpha
	)
	
	# Add slight scale variation for more dynamic effect
	var scale_variation = randf_range(0.95, 1.05)
	duplicate_sprite.scale *= scale_variation
	
	# Add to the scene tree (as a child of the player's parent)
	get_parent().add_child(duplicate_sprite)
	
	# Store reference to clean up later
	active_duplicates.append(duplicate_sprite)
	
	# Start the fade-out tween
	_fade_out_duplicate(duplicate_sprite)

## Fades out and removes a duplicate sprite
@warning_ignore("shadowed_variable_base_class")
func _fade_out_duplicate(duplicate: Node2D):
	# Check if duplicate is still valid before creating tween
	if not duplicate or not is_instance_valid(duplicate):
		return
	
	# Create a tween to fade out the duplicate
	var tween = create_tween()
	tween.tween_property(duplicate, "modulate:a", 0.0, duplicate_lifetime)
	
	# Use a proper callback that doesn't capture the duplicate reference
	tween.tween_callback(_remove_duplicate_callback.bind(duplicate))

## Callback function for removing duplicates
@warning_ignore("shadowed_variable_base_class")
func _remove_duplicate_callback(arg):
	if is_instance_valid(arg) and arg is Node2D:
		_remove_duplicate(arg)

## Removes a duplicate sprite from the scene and array
@warning_ignore("shadowed_variable_base_class")
func _remove_duplicate(duplicate: Node2D):
	if duplicate and is_instance_valid(duplicate):
		# Remove from our tracking array
		active_duplicates.erase(duplicate)
		# Remove from scene
		duplicate.queue_free()

## Cleans up all active duplicates (called when dash ends or player resets)
func _cleanup_all_duplicates():
	@warning_ignore("shadowed_variable_base_class")
	for duplicate in active_duplicates:
		if duplicate and is_instance_valid(duplicate):
			duplicate.queue_free()
	active_duplicates.clear()

## Creates a temporary color flash effect on the sprite
func _create_dash_flash():
	# Store original modulate
	var original_modulate = _sprite.modulate
	
	# Flash bright white briefly
	_sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)
	
	# Create tween to return to normal
	var tween = create_tween()
	tween.tween_property(_sprite, "modulate", original_modulate, 0.1)

# ============================================================================
# GODOT LIFECYCLE FUNCTIONS
# ============================================================================

## Called when the node enters the scene tree for the first time
func _ready():
	# Don't run physics in the editor - only when actually playing
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
	else:
		# Connect to global signals to respond to game events
		Global.gravity_changed.connect(_on_gravity_changed)
		Global.game_ended.connect(_on_game_ended)

	# Store starting position for respawning
	original_position = position
	
	# Initialize export variables
	_set_speed(speed)
	_set_sprite_frames(sprite_frames)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

## Called when the world gravity changes
func _on_gravity_changed(new_gravity):
	gravity = new_gravity

## Called when the game ends (win or lose)
func _on_game_ended(_ending: Global.Endings):
	# Stop all movement and animation
	game_is_active = false
	velocity = Vector2.ZERO
	_sprite.play("idle")
	
	# Clean up any remaining duplicates
	_cleanup_all_duplicates()

# ============================================================================
# MOVEMENT FUNCTIONS
# ============================================================================

## Makes the character jump
## Handles both regular jumps and double jumps
func _jump():
	# Set upward velocity for the jump
	velocity.y = jump_velocity
	
	# Reset jump timers since we're now jumping
	coyote_timer = 0
	jump_buffer_timer = 0
	
	# Handle double jump logic
	if double_jump_armed:
		# This is a double jump
		double_jump_armed = false
		_double_jump_particles.emitting = true  # Show particle effect
	elif double_jump:
		# This is the first jump, enable double jump for next time
		double_jump_armed = true

## Makes the character jump after stomping on an enemy
## This is called by enemy scripts when the player lands on them
func stomp():
	# Disable double jump since we're getting a "free" jump
	double_jump_armed = false
	# Perform the jump
	_jump()

## Triggers the game start when the player first moves
## This is called whenever the player performs any action
func _trigger_game_start():
	# Tell the Global script that the game has started
	# This will start the timer and any other game systems
	Global._start_game_if_needed()

# ============================================================================
# MAIN PHYSICS LOOP
# ============================================================================

## Called every physics frame (usually 60 times per second)
## This is where all the movement logic happens
func _physics_process(delta):
	# Don't move if the game is not active (paused or ended)
	if not game_is_active:
		return
	
	# ========================================
	# HANDLE TIMERS
	# ========================================
	
	# Count down dash cooldown timer
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	# Count down dash duration timer
	if dash_timer > 0:
		dash_timer -= delta
	else:
		# Dash is over
		if is_dashing:
			is_dashing = false
			# Reset duplicate spawn timer when dash ends
			duplicate_spawn_timer = 0.0

	# ========================================
	# HANDLE DASH DUPLICATE EFFECTS
	# ========================================
	
	# If we're dashing, handle duplicate creation
	if is_dashing:
		duplicate_spawn_timer -= delta
		if duplicate_spawn_timer <= 0:
			_create_duplicate()
			duplicate_spawn_timer = duplicate_spawn_rate

	# ========================================
	# HANDLE DASH INPUT
	# ========================================
	
	# Check if player wants to dash and is allowed to
	if not is_dashing and dash_cooldown_timer <= 0 and dash_count < max_dash_count and Input.is_action_just_pressed("player_1_dash"):
		# Get the direction the player is pressing (both horizontal and vertical)
		# Check individual action presses instead of using get_axis for more direct control
		var input_dir_x = 0
		var input_dir_y = 0
		
		# Check horizontal input
		if Input.is_action_pressed("player_1_left"):
			input_dir_x = -1
		elif Input.is_action_pressed("player_1_right"):
			input_dir_x = 1
			
		# Check vertical input (assuming you have up/down actions)
		if Input.is_action_pressed("player_1_jump"):
			input_dir_y = -1  # Negative Y is up in Godot
		elif Input.is_action_pressed("player_1_down"):
			input_dir_y = 1   # Positive Y is down in Godot
		
		# Create a direction vector from the input
		var input_direction = Vector2(input_dir_x, input_dir_y)
		
		# Only dash if player is pressing any direction
		if input_direction != Vector2.ZERO:
			# Normalize the direction to ensure consistent dash speed in all directions
			# This makes diagonal dashes the same speed as horizontal/vertical dashes
			dash_direction = input_direction.normalized()
			
			# Start the dash
			is_dashing = true
			dash_timer = dash_duration
			dash_cooldown_timer = dash_cooldown
			dash_count += 1  # Increment dash count
			
			# Reset duplicate spawn timer to start creating duplicates immediately
			duplicate_spawn_timer = 0.0
			
			# Create enhanced visual effects
			_create_dash_flash()
			
			# Start the game on first input
			_trigger_game_start()
			
	# ========================================
	# HANDLE FAST FALL INPUT
	# ========================================
	
	# Check if player wants to fall faster
	if Input.is_action_just_pressed("player_1_down") and not is_on_floor():
		is_down = true
		# Start the game on first input
		_trigger_game_start()
		
	# Stop fast falling when we hit the ground
	if is_on_floor():
		is_down = false
			
	# ========================================
	# HANDLE JUMP INPUT AND LOGIC
	# ========================================
	
	# Reset coyote time and dash count when on the ground
	if is_on_floor():
		coyote_timer = (coyote_time + delta)  # Add delta to account for this frame
		double_jump_armed = false  # Reset double jump when landing
		dash_count = 0  # Reset dash count when touching the floor

	# Check if player pressed jump
	if Input.is_action_just_pressed("player_1_jump"):
		jump_buffer_timer = (jump_buffer + delta)  # Add delta to account for this frame
		# Start the game on first input
		_trigger_game_start()

	# Perform jump if conditions are met
	if jump_buffer_timer > 0 and (double_jump_armed or coyote_timer > 0):
		_jump()

	# Handle variable jump height (cutting jump short)
	if Input.is_action_just_released("player_1_jump") and velocity.y < 0:
		# Reduce upward velocity when jump key is released
		velocity.y *= (1 - (jump_cut_factor / 100.00))

	# ========================================
	# HANDLE GRAVITY AND VERTICAL MOVEMENT
	# ========================================
	
	# Apply fast fall or normal gravity (but not during dash)
	if is_dashing:
		# During dash, don't apply gravity - let the dash control all movement
		pass
	elif is_down:
		# Fast fall - set velocity directly to down_speed
		velocity.y = down_speed
	elif coyote_timer <= 0:
		# Normal gravity - only apply if not in coyote time
		velocity.y += gravity * delta

	# ========================================
	# HANDLE HORIZONTAL MOVEMENT
	# ========================================
	
	# Handle dash movement vs normal movement
	if is_dashing:
		# During dash, move at dash speed in the dash direction
		var current_dash_speed = dash_speed
		
		# Check if this is a diagonal dash (both x and y components are non-zero)
		if abs(dash_direction.x) > 0 and abs(dash_direction.y) > 0:
			# This is a diagonal dash - reduce the speed
			current_dash_speed *= diagonal_dash_multiplier
		# Check if this is a purely upward dash (only y component, negative for up)
		elif dash_direction.x == 0 and dash_direction.y < 0:
			# This is an upward dash - reduce the speed significantly
			current_dash_speed *= upward_dash_multiplier
		
		# Apply the dash movement
		velocity.x = dash_direction.x * current_dash_speed
		velocity.y = dash_direction.y * current_dash_speed
	else:
		# Normal movement - get input direction
		var direction = Input.get_axis("player_1_left", "player_1_right")
		
		# Start the game on first input
		if direction != 0:
			_trigger_game_start()
		
		if direction:
			# Move toward target speed
			velocity.x = move_toward(
				velocity.x,                           # Current velocity
				sign(direction) * speed,              # Target velocity
				abs(direction) * acceleration * delta # Acceleration step
			)
		else:
			# No input - slow down to stop
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)

	# ========================================
	# HANDLE ANIMATIONS
	# ========================================
	
	# Choose appropriate animation based on movement state
	if velocity == Vector2.ZERO:
		# Not moving - idle animation
		_sprite.play("idle")
	else:
		# Moving - choose animation based on whether we're in the air
		if not is_on_floor():
			# In the air - use jump animations
			if velocity.y > 0:
				_sprite.play("jump_down")  # Falling
			else:
				_sprite.play("jump_up")    # Rising
		else:
			# On ground and moving - walk animation
			_sprite.play("walk")
		
		# Flip sprite to face movement direction
		_sprite.flip_h = velocity.x < 0  # True if moving left

	# ========================================
	# APPLY MOVEMENT
	# ========================================
	
	# Actually move the character based on calculated velocity
	# This handles collision detection and sliding along walls
	move_and_slide()

	# ========================================
	# UPDATE TIMERS
	# ========================================
	
	# Count down jump-related timers
	coyote_timer -= delta
	jump_buffer_timer -= delta

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

## Resets the player character to its starting state
## This is called when the game restarts
func reset():
	# Move back to starting position
	position = original_position
	
	# Stop all movement
	velocity = Vector2.ZERO
	
	# Reset jump timers
	coyote_timer = 0
	jump_buffer_timer = 0
	
	# Reset dash state
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	dash_count = 0  # Reset dash count
	duplicate_spawn_timer = 0.0
	
	# Clean up any remaining duplicates
	_cleanup_all_duplicates()
	
	# Make sure the game is active
	game_is_active = true
