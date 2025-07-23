@tool
extends Camera2D

## This is the Chase Camera script - it creates a continuous chase scene
## The camera follows the player, and a death zone sweeps across the map
## This creates tension and forces the player to keep moving forward

# ============================================================================
# EXPORT VARIABLES - These appear in the Godot editor for customization
# ============================================================================

## How smoothly does the camera follow the player?
## Higher values = camera follows more closely, lower values = more lag
@export_range(1, 20, 0.5) var camera_follow_speed: float = 8.0

## Horizontal offset from the player (positive = camera is to the right of player)
@export_range(-200, 200, 10, "suffix:px") var camera_offset_x: float = 0.0

## Vertical offset from the player (positive = camera is below player)
@export_range(-200, 200, 10, "suffix:px") var camera_offset_y: float = 0.0

## How fast does the death zone (dragon) move to the right?
## This moves independently across the map, not following the player
@export_range(30, 1600, 5, "suffix:px/s") var death_zone_speed: float = 80.0

## Starting position of the death zone relative to the map
## Negative values start the death zone to the left of the map origin
@export_range(-2000, 0, 50, "suffix:px") var death_zone_start_x: float = -500.0

## Width of the death zone (how wide the dragon's kill area is)
@export_range(50, 600, 10, "suffix:px") var death_zone_width: float = 150.0

## Should we show a visual indicator of the death zone?
## Useful for debugging - turn off when you have the dragon animation
@export var show_death_zone_debug: bool = false

## Color of the death zone debug indicator
@export var death_zone_color: Color = Color.RED

## Opacity of the death zone debug indicator
@export_range(0.1, 1.0, 0.1) var death_zone_alpha: float = 0.3

## Should the chase start immediately, or wait for the player to move?
@export var start_immediately: bool = false

## Delay before chase starts (in seconds)
@export_range(0, 20, 0.1, "suffix:s") var start_delay: float = 2.0

## Reference to the dragon sprite node (drag your dragon scene/node here)
@onready var dragon_sprite: AnimatedSprite2D = get_node("../../Dragon/AnimatedSprite2D")

## Vertical offset for the dragon relative to the camera
@export_range(-500, 500, 10, "suffix:px") var dragon_y_offset: float = 0.0

# ============================================================================
# INTERNAL VARIABLES
# ============================================================================

## Reference to the player node
var player: CharacterBody2D

## Is the chase currently active?
var chase_active: bool = false

## Timer for the start delay
var start_timer: float = 0.0

## Current position of the death zone (left edge)
var death_zone_x: float = 0.0

## Node for drawing the death zone debug indicator
var death_zone_indicator: Node2D

## Starting position of the death zone
var death_zone_start_position: float

# ============================================================================
# GODOT LIFECYCLE FUNCTIONS
# ============================================================================

## Called when the node enters the scene tree
func _ready():
	# Don't run in the editor
	if Engine.is_editor_hint():
		set_process(false)
		return
	
	# Store starting positions
	death_zone_start_position = death_zone_start_x
	death_zone_x = death_zone_start_x
	
	# Find the player node (assuming this camera is a child of the player)
	player = get_parent() as CharacterBody2D
	
	if not player:
		push_error("Chase Camera: Could not find player node. Make sure camera is a child of the player.")
		return
	
	# Connect to global signals
	Global.game_ended.connect(_on_game_ended)
	Global.game_started.connect(_on_game_started)
	
	# Set up the death zone debug indicator
	if show_death_zone_debug:
		_create_death_zone_indicator()
	
	# Initialize dragon setup if it exists
	if dragon_sprite:
		setup_dragon()
	
	# Start the chase based on settings
	if start_immediately:
		_start_chase()
	else:
		start_timer = start_delay

## Called every frame
func _process(delta):
	if Engine.is_editor_hint():
		return
	
	# Handle start delay
	if not chase_active and start_timer > 0:
		start_timer -= delta
		if start_timer <= 0:
			_start_chase()
	
	# Always update camera to follow player
	_update_camera_follow(delta)
	
	# Move death zone if chase is active
	if chase_active:
		_update_death_zone_movement(delta)
		_check_player_position()
	
	# Update dragon position
	if dragon_sprite:
		_update_dragon_position()
	
	# Update death zone debug indicator
	if death_zone_indicator:
		_update_death_zone_indicator()

# ============================================================================
# CHASE MECHANICS
# ============================================================================

## Starts the chase sequence
func _start_chase():
	chase_active = true
	print("The dragon is coming! Keep moving right or you'll be caught!")
	
	# Start dragon animation when chase begins
	if dragon_sprite:
		dragon_sprite.visible = true
		dragon_sprite.play("Flying")

## Updates the camera to follow the player smoothly
func _update_camera_follow(delta):
	if not player:
		return
	
	# Calculate target position (player position + offset)
	var target_position = Vector2(
		player.global_position.x + camera_offset_x,
		player.global_position.y + camera_offset_y
	)
	
	# Smoothly move camera towards target position
	global_position = global_position.lerp(target_position, camera_follow_speed * delta)

## Updates the death zone's movement (this sweeps across the map independently)
func _update_death_zone_movement(delta):
	# Move the death zone to the right at its own speed
	# This is independent of player movement - it moves across the map
	death_zone_x += death_zone_speed * delta

## Checks if the player is still safe from the death zone
func _check_player_position():
	if not player:
		return
	
	# Check if player is caught by the death zone
	# The death zone extends from death_zone_x to death_zone_x + death_zone_width
	if player.global_position.x < death_zone_x + death_zone_width and player.global_position.x > death_zone_x:
		_player_caught()

## Called when the player is caught by the death zone
func _player_caught():
	print("Player caught by the dragon!")
	
	# Stop the chase movement but keep dragon visible
	chase_active = false
	
	# Keep dragon visible and animated when player is caught
	if dragon_sprite:
		dragon_sprite.visible = true
		# Optional: play a different animation for catching the player
		# dragon_sprite.play("Attack") # uncomment if you have an attack animation
	
	# Trigger game over
	Global.end_game(Global.Endings.LOSE)

# ============================================================================
# DRAGON ANIMATION SYSTEM
# ============================================================================

## Updates the dragon's position to follow the death zone
func _update_dragon_position():
	if not dragon_sprite:
		return
	
	# Position the dragon at the death zone location (always update if dragon exists)
	# The dragon represents the left edge of the death zone
	dragon_sprite.global_position.x = death_zone_x
	dragon_sprite.global_position.y = global_position.y + dragon_y_offset
	
	# Only hide dragon if chase hasn't started yet
	if chase_active:
		dragon_sprite.visible = true

## Sets up the dragon sprite (call this after assigning dragon_sprite)
func setup_dragon():
	if not dragon_sprite:
		return
	
	# Initially hide the dragon
	dragon_sprite.visible = false
	
	# Start the flying animation (dragon_sprite is already the AnimatedSprite2D)
	if dragon_sprite.sprite_frames and dragon_sprite.sprite_frames.has_animation("Flying"):
		dragon_sprite.play("Flying")
	else:
		push_warning("Dragon sprite doesn't have 'Flying' animation")
	
	# Set the dragon's initial position
	dragon_sprite.global_position.x = death_zone_x
	dragon_sprite.global_position.y = global_position.y + dragon_y_offset

# ============================================================================
# DEATH ZONE DEBUG INDICATOR
# ============================================================================

## Creates a visual debug indicator for the death zone
func _create_death_zone_indicator():
	death_zone_indicator = Node2D.new()
	death_zone_indicator.name = "DeathZoneDebugIndicator"
	add_child(death_zone_indicator)
	
	# Override the draw function to show the death zone
	death_zone_indicator.draw.connect(_draw_death_zone_debug)

## Draws the death zone debug indicator
func _draw_death_zone_debug():
	if not show_death_zone_debug or not chase_active:
		return
	
	# Convert death zone world position to camera-relative coordinates
	var death_zone_camera_x = death_zone_x - global_position.x
	
	var viewport_size = get_viewport().get_visible_rect().size
	var half_height = viewport_size.y / 2
	
	# Calculate death zone rectangle in camera-relative coordinates
	var death_zone_rect = Rect2(
		death_zone_camera_x,  # Left edge of death zone
		-half_height,         # Top edge of screen
		death_zone_width,     # Width of death zone
		viewport_size.y       # Full height of screen
	)
	
	# Draw the death zone as a red overlay
	var color = death_zone_color
	color.a = death_zone_alpha
	death_zone_indicator.draw_rect(death_zone_rect, color)

## Updates the death zone debug indicator
func _update_death_zone_indicator():
	if death_zone_indicator:
		death_zone_indicator.queue_redraw()

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

## Called when the game starts
func _on_game_started():
	if not start_immediately:
		start_timer = start_delay

## Called when the game ends
func _on_game_ended(_ending: Global.Endings):
	chase_active = false
	# Stop dragon animation when game ends
	if dragon_sprite:
		dragon_sprite.visible = false
		dragon_sprite.stop()

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

## Resets the camera to its starting state
func reset():
	# Reset death zone position
	death_zone_x = death_zone_start_position
	chase_active = false
	@warning_ignore("incompatible_ternary")
	start_timer = start_delay if not start_immediately else 0
	
	# Reset dragon position and animation
	if dragon_sprite:
		dragon_sprite.visible = false
		dragon_sprite.stop()
		dragon_sprite.global_position.x = death_zone_x
		dragon_sprite.global_position.y = global_position.y + dragon_y_offset
	
	# Camera will automatically follow player, so no need to reset position
	
	if start_immediately:
		_start_chase()

## Gets the current camera follow speed (useful for other scripts)
func get_camera_follow_speed() -> float:
	return camera_follow_speed

## Gets the current death zone speed (useful for other scripts)
func get_death_zone_speed() -> float:
	if chase_active:
		return death_zone_speed
	else:
		return 0.0

## Gets the current position of the death zone (useful for other scripts)
func get_death_zone_position() -> float:
	if chase_active:
		return death_zone_x
	else:
		return -999999.0

## Gets the width of the death zone (useful for other scripts)
func get_death_zone_width() -> float:
	return death_zone_width

## Manually starts the chase (can be called from other scripts)
func start_chase_now():
	_start_chase()

## Pauses or resumes the chase
func set_chase_active(active: bool):
	chase_active = active
	if dragon_sprite:
		dragon_sprite.visible = active
		if active:
			dragon_sprite.play("Flying")
		else:
			dragon_sprite.stop()
