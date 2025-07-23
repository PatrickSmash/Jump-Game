class_name Enemy
extends CharacterBody2D
# This script defines a 2D enemy character that moves, reacts to edges, gravity, and interacts with the player

# ==============================
# == CONFIGURABLE PROPERTIES ==
# ==============================

## How fast the enemy moves (can be changed in the Inspector)
@export_range(0, 1000, 10, "suffix:px/s") var speed: float = 100.0:
	set = _set_speed  # Custom setter function to also update animation speed

## If true, enemy will fall off platforms (like a Goomba); if false, turns around at edges
@export var fall_off_edge: bool = false

## If true, the player will lose a life when touching this enemy
@export var player_loses_life: bool = true

## If true, the player can jump on and defeat (squash) this enemy
@export var squashable: bool = true

## Direction enemy starts moving in: 0 = Left, 1 = Right
@export_enum("Left:0", "Right:1") var start_direction: int = 0

# ==============================
# == VARIABLES ==
# ==============================

# Pull gravity value from Godot's global physics settings
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Direction of movement: -1 = left, 1 = right
var direction: int

# ==============================
# == NODE REFERENCES ==
# ==============================

# @onready ensures nodes are loaded before being accessed
@onready var _sprite := %AnimatedSprite2D     # Enemy's animated sprite
@onready var _left_ray := %LeftRay            # RayCast2D on the left side (for edge or wall detection)
@onready var _right_ray := %RightRay          # RayCast2D on the right side

# ==============================
# == SETTER FUNCTION ==
# ==============================

# Called whenever speed is changed
func _set_speed(new_speed):
	speed = new_speed
	if not is_node_ready():
		await ready  # Wait until the node is ready
	# Adjust animation speed based on movement speed
	if speed == 0:
		_sprite.speed_scale = 0
	else:
		_sprite.speed_scale = speed / 100

# ==============================
# == READY FUNCTION ==
# ==============================

func _ready():
	# Listen for gravity changes from the global script
	Global.gravity_changed.connect(_on_gravity_changed)

	# Set initial movement direction based on start_direction
	direction = -1 if start_direction == 0 else 1

# ==============================
# == PHYSICS LOOP ==
# ==============================

func _physics_process(delta):
	# Apply gravity if enemy is not standing on the ground
	if not is_on_floor():
		velocity.y += gravity * delta

	# If enemy shouldn't fall off edges, check if it's at the edge
	if not fall_off_edge and (_left_ray.is_colliding() or _right_ray.is_colliding()):
		# Turn around if about to fall off
		if direction == -1 and not _left_ray.is_colliding():
			direction = 1  # Turn right
		elif direction == 1 and not _right_ray.is_colliding():
			direction = -1  # Turn left

	# Set horizontal velocity
	velocity.x = direction * speed

	# Flip sprite to face direction of movement
	_sprite.flip_h = velocity.x < 0

	# Move the enemy, using Godot’s built-in collision and sliding
	move_and_slide()

	# If enemy is on the floor but not moving (e.g. stuck), reverse direction
	if velocity.x == 0 and is_on_floor():
		direction *= -1

# ==============================
# == HANDLE GRAVITY CHANGE ==
# ==============================

# Update the gravity if it's changed in the game
func _on_gravity_changed(new_gravity):
	gravity = new_gravity

# ==============================
# == COLLISION LOGIC ==
# ==============================

# Called when a body (like the player) touches the enemy's hitbox
func _on_hitbox_body_entered(body):
	if body.is_in_group("players"):
		# If enemy is squashable AND player is falling from above
		if squashable and body.velocity.y > 0 and body.position.y < position.y:
			body.stomp()     # Call player's stomp method (makes them bounce)
			queue_free()     # Destroy this enemy
		elif player_loses_life:
			Global.lives -= 1  # Subtract a life from the player
