@tool
class_name Platform
extends Node2D

# Constants for the platform tile size and the shared tile texture
const TILE_WIDTH: int = 128
const SPRITE: Texture2D = preload("res://assets/tiles-a.png") # Preload the sprite sheet

# ========== EDITABLE PROPERTIES (VISIBLE IN THE EDITOR) ==========

# The number of tiles that make up the platform's width
@export_range(1, 20, 1, "suffix:tiles") var width: int = 3:
	set = _set_width # When changed, calls the _set_width function

# Determines whether the player can jump through the bottom of the platform
@export var one_way: bool = false:
	set = _set_one_way # When changed, calls the _set_one_way function

# The delay before the platform falls after being touched. 
# If negative, it won't fall. If 0, it falls immediately.
@export var fall_time: float = -1

# Timer used to delay platform falling
var fall_timer: Timer

# ========== REFERENCES TO CHILD NODES (GETS THEM BY NAME) ==========

@onready var _rigid_body := %RigidBody2D # Used to enable/disable physics for falling
@onready var _sprites := %Sprites # Holds the individual tile sprites
@onready var _collision_shape := %CollisionShape2D # Main collision shape for standing
@onready var _area_collision_shape := %AreaCollisionShape2D # Used to detect player proximity
@onready var _animation_player := %AnimationPlayer # Animates the platform (e.g., shake)

# ========== SETTER FUNCTIONS ==========

# Called when the width is changed
func _set_width(new_width):
	width = new_width
	if is_node_ready(): # Only recreate visuals if the node is fully ready
		_recreate_sprites()

# Called when the one_way property is changed
func _set_one_way(new_one_way):
	one_way = new_one_way
	if is_node_ready():
		_recreate_sprites()

# ========== SPRITE + COLLISION CREATION ==========

# Dynamically creates tile sprites and adjusts collision shapes based on width/one_way
func _recreate_sprites():
	for c in _sprites.get_children():
		c.queue_free() # Clear any existing tile sprites

	# Adjust the main collision shape for the platform
	_collision_shape.one_way_collision = one_way
	_collision_shape.shape.set_size(Vector2(width * TILE_WIDTH, TILE_WIDTH))

	# Adjust the area shape (used to detect if a player has touched it)
	_area_collision_shape.shape.set_size(
		Vector2(width * TILE_WIDTH, _area_collision_shape.shape.size[1])
	)

	var center: float = (width - 1) * TILE_WIDTH / 2.0

	# Create new tile sprites based on platform width
	for i in range(0, width):
		var new_sprite := Sprite2D.new()
		new_sprite.texture = SPRITE
		new_sprite.hframes = 12
		new_sprite.vframes = 3

		# Choose correct tile appearance based on position and one_way state
		if one_way:
			if i == 0:
				if width == 1:
					new_sprite.frame_coords = Vector2i(8, 0) # Single tile
				else:
					new_sprite.frame_coords = Vector2i(5, 0) # Left end
			elif i == width - 1:
				new_sprite.frame_coords = Vector2i(7, 0) # Right end
			else:
				new_sprite.frame_coords = Vector2i(6, 0) # Middle tile
		else:
			new_sprite.frame_coords = Vector2i(10, 1) # Solid tile for normal platform

		# Position each tile sprite along the platform
		new_sprite.position = Vector2(i * TILE_WIDTH - center, 0)
		_sprites.add_child(new_sprite)

# ========== GODOT LIFECYCLE ==========

# Called when the platform is added to the scene tree
func _ready():
	_recreate_sprites() # Build platform visuals and collision

	# Set up a timer for delayed falling platforms
	fall_timer = Timer.new()
	fall_timer.one_shot = true
	fall_timer.timeout.connect(_fall)
	add_child(fall_timer)

# ========== SIGNAL CALLBACKS ==========

# Called when any body (like the player) enters the platform's detection area
func _on_area_2d_body_entered(body):
	if not body.is_in_group("players"): # Ignore non-player bodies
		return

	if fall_time > 0:
		# Start countdown to fall and play shake animation
		fall_timer.start(fall_time)
		_animation_player.play("shake")
	elif fall_time == 0:
		# Fall immediately if delay is zero
		_rigid_body.call_deferred("set_freeze_enabled", false)

# Called when the fall timer ends
func _fall():
	# Unfreeze the rigid body to let the platform fall with gravity
	_rigid_body.freeze = false
	_animation_player.stop()

# Optional: Logs when something collides with the RigidBody2D directly
func _on_rigid_body_2d_body_entered(body):
	print("Body entered:", body.name)
