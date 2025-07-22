@tool
class_name Coin
extends Area2D
# This script defines a collectible coin object in the game using Area2D for detection.
# Now uses AnimatedSprite2D for coin animation instead of static Sprite2D.

# ==============================
# == EXPORTED VARIABLES ==
# ==============================
## Allows the coin's sprite frames (animation) to be changed in the editor.
@export var sprite_frames: SpriteFrames:
	set = set_sprite_frames  # Calls custom setter when changed

## The name of the animation to play (e.g., "spin", "idle").
@export var animation_name: String = "default":
	set = set_animation_name

## Allows you to tint the coin a different color (e.g., red, gold, green).
@export var tint: Color = Color.WHITE:
	set = set_tint  # Custom setter to apply tint

# ==============================
# == NODE REFERENCES ==
# ==============================
# Shortcut to the AnimatedSprite2D node that displays the coin animation.
@onready var _animated_sprite: AnimatedSprite2D = get_node("Sprite2D")

# ==============================
# == SETTER FUNCTIONS ==
# ==============================
# Called when you set new sprite frames in the editor or in code
func set_sprite_frames(new_frames: SpriteFrames):
	sprite_frames = new_frames
	if not is_node_ready():
		await ready  # Wait until node is ready before changing the sprite
	
	if _animated_sprite and sprite_frames:
		_animated_sprite.sprite_frames = sprite_frames
		# Start playing the animation if we have frames
		if not animation_name.is_empty():
			_animated_sprite.play(animation_name)
	notify_property_list_changed()  # Notifies the editor that a property changed

# Called when you change the animation name in the editor or in code
func set_animation_name(new_name: String):
	animation_name = new_name
	if is_node_ready() and _animated_sprite and _animated_sprite.sprite_frames:
		_animated_sprite.play(animation_name)

# Called when you change the tint color in the editor or in code
func set_tint(new_tint: Color):
	tint = new_tint
	if is_node_ready():
		modulate = tint  # Changes the overall color of the coin sprite

# ==============================
# == READY FUNCTION ==
# ==============================
func _ready():
	set_tint(tint)  # Apply tint color when the scene starts
	
	# Start the coin animation
	if _animated_sprite and sprite_frames:
		_animated_sprite.sprite_frames = sprite_frames
		_animated_sprite.play(animation_name)

# ==============================
# == COLLISION FUNCTION ==
# ==============================
# This function is called when a body (like the player) enters the coin's area.
func _on_body_entered(_body):
	Global.collect_coin()  # Calls a global function to update the player's coin count
	queue_free()           # Removes the coin from the game scene (coin is "collected")
