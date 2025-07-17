@tool
class_name Flag
extends Area2D
# This makes the Flag a reusable node in the editor (with a custom name)
# It inherits from Area2D, meaning it can detect when objects enter it (like the player)

# Define an enum for flag states: either UP or DOWN
enum FlagPosition {
	DOWN,  # Flag is lowered
	UP,    # Flag is raised
}

## SpriteFrames lets you set different animations or frames for the flag
@export var sprite_frames: SpriteFrames = _initial_sprite_frames:
	set = _set_sprite_frames  # When changed, call this setter to update visuals

## Stores whether the flag starts UP or DOWN
@export var flag_position: FlagPosition = FlagPosition.DOWN:
	set = _set_flag_position  # When changed, play the correct animation

# Use @onready to wait until the node is fully loaded before getting its children
@onready var _sprite: AnimatedSprite2D = %AnimatedSprite2D  # The flag’s animated sprite
@onready var _initial_sprite_frames: SpriteFrames = %AnimatedSprite2D.sprite_frames

# This function is called when the sprite_frames variable is updated
func _set_sprite_frames(new_sprite_frames):
	sprite_frames = new_sprite_frames
	# Only update the sprite if the node is ready and frames are valid
	if sprite_frames and is_node_ready():
		_sprite.sprite_frames = sprite_frames

# This function changes the flag’s position and plays the matching animation
func _set_flag_position(new_flag_position):
	flag_position = new_flag_position
	# If the node isn’t ready, skip animation logic
	if not is_node_ready():
		pass
	elif flag_position == FlagPosition.DOWN:
		_sprite.play("down")  # Play the "down" animation
	else:
		_sprite.play("up")    # Play the "up" animation

# Called when the node enters the scene (once it's added to the game)
func _ready():
	# Make sure the flag starts with the correct visuals
	_set_sprite_frames(sprite_frames)
	_set_flag_position(flag_position)

# This function is automatically called when something touches the flag’s area
func _on_body_entered(_body):
	# Only raise the flag if it's currently down
	if flag_position == FlagPosition.DOWN:
		flag_position = FlagPosition.UP
		Global.raise_flag(self)  # Call a global function to handle the flag being raised
