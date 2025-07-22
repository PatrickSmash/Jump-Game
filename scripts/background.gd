@tool
extends ParallaxBackground
# This script is attached to a ParallaxBackground node.
# It allows you to tint (recolor) all background layers using a single variable in the editor.

# ==============================
# == EXPORTED VARIABLE ==
# ==============================

## Lets you change the background tint color in the editor (e.g., make it darker or lighter).
@export var tint: Color = Color.WHITE:  # Default is plain white (no tint)
	set = _set_tint  # When tint is changed, call the _set_tint() function

# ==============================
# == NODE REFERENCES ==
# ==============================

# Grabs the ParallaxLayer child nodes from the scene. These layers scroll at different speeds for a depth effect.
@onready var parallax_layers = [
	%ParallaxLayer,
	%ParallaxLayer2,
	%ParallaxLayer3,
]

# ==============================
# == SETTER FUNCTION ==
# ==============================

# Called whenever the `tint` color is changed in the editor or by code.
func _set_tint(new_tint: Color):
	tint = new_tint
	if is_node_ready():  # Ensures the scene is fully loaded before applying the tint
		for _layer in parallax_layers:
			_layer.modulate = tint  # Changes the layer's color using the modulate property

# ==============================
# == READY FUNCTION ==
# ==============================

func _ready():
	_set_tint(tint)  # Applies the tint as soon as the game starts (or when the scene loads)
