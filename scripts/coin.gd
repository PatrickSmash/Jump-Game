@tool
class_name Coin
extends Area2D
# This script defines a collectible coin object in the game using Area2D for detection.

# ==============================
# == EXPORTED VARIABLES ==
# ==============================

## Allows the coin's texture (image) to be changed in the editor.
@export var texture: Texture2D = _initial_texture:
	set = _set_texture  # Calls custom setter when changed

## Allows you to tint the coin a different color (e.g., red, gold, green).
@export var tint: Color = Color.WHITE:
	set = _set_tint  # Custom setter to apply tint

# ==============================
# == NODE REFERENCES ==
# ==============================

# Shortcut to the Sprite2D node that displays the coin image.
@onready var _sprite: Sprite2D = %Sprite2D

# Stores the original texture from the scene, used as a fallback.
@onready var _initial_texture: Texture2D = %Sprite2D.texture

# ==============================
# == SETTER FUNCTIONS ==
# ==============================

# Called when you set a new texture in the editor or in code
func _set_texture(new_texture: Texture2D):
	if not is_node_ready():
		await ready  # Wait until node is ready before changing the sprite
	texture = new_texture
	if texture != null:
		_sprite.texture = texture  # Use the new texture
	else:
		_sprite.texture = _initial_texture  # Fallback to original if none is provided
	notify_property_list_changed()  # Notifies the editor that a property changed

# Called when you change the tint color in the editor or in code
func _set_tint(new_tint: Color):
	tint = new_tint
	if is_node_ready():
		modulate = tint  # Changes the overall color of the coin sprite

# ==============================
# == READY FUNCTION ==
# ==============================

func _ready():
	_set_tint(tint)  # Apply tint color when the scene starts

# ==============================
# == COLLISION FUNCTION ==
# ==============================

# This function is called when a body (like the player) enters the coin's area.
func _on_body_entered(_body):
	Global.collect_coin()  # Calls a global function to update the player's coin count
	queue_free()           # Removes the coin from the game scene (coin is "collected")
