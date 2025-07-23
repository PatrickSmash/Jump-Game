# This tells Godot that this script can be used in the editor (for @export variables)
@tool
# This creates a custom class called "Coin" that other scripts can reference
class_name Coin
# Our coin inherits from Area2D, which can detect when other bodies enter/exit it
extends Area2D

# EXPORTED VARIABLES - These show up in the Godot inspector and can be customized per coin

# The sprite frames resource that contains our coin animation frames
@export var sprite_frames: SpriteFrames:
	set = set_sprite_frames  # When this changes, call set_sprite_frames function

# The name of the animation to play (like "spin", "idle", etc.)
@export var animation_name: String = "default":
	set = set_animation_name  # When this changes, call set_animation_name function

# The color tint to apply to the coin (Color.WHITE = no tint, normal colors)
@export var tint: Color = Color.WHITE:
	set = set_tint  # When this changes, call set_tint function

# NODE REFERENCES - These get the child nodes when the scene is ready

# Gets the AnimatedSprite2D child node that displays our coin animation
@onready var animated_sprite: AnimatedSprite2D = $Sprite2D

# STATE VARIABLES - These track the current state of our coin

# Prevents the coin from being collected multiple times
var collected := false

# SETTER FUNCTIONS - These are called automatically when exported variables change

# Called whenever sprite_frames is changed in the inspector or code
func set_sprite_frames(new_frames: SpriteFrames):
	sprite_frames = new_frames  # Store the new frames
	
	# If the node isn't ready yet, wait for it to be ready
	if not is_node_ready():
		await ready
	
	# If we have both the sprite node and frames, apply them
	if animated_sprite and sprite_frames:
		animated_sprite.sprite_frames = sprite_frames
		# If we have an animation name, start playing it
		if not animation_name.is_empty():
			animated_sprite.play(animation_name)

# Called whenever animation_name is changed in the inspector or code
func set_animation_name(new_name: String):
	animation_name = new_name  # Store the new animation name
	
	# Only play if everything is ready and we have sprite frames loaded
	if is_node_ready() and animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.play(animation_name)

# Called whenever tint is changed in the inspector or code
func set_tint(new_tint: Color):
	tint = new_tint  # Store the new tint color
	
	# Only apply the tint if the node is ready
	if is_node_ready():
		modulate = tint  # modulate changes the color/transparency of the entire node

# GODOT LIFECYCLE FUNCTIONS

# Called once when the node enters the scene tree and is ready
func _ready():
	# Apply the current tint color
	set_tint(tint)
	
	# Set up the animation if we have the necessary components
	if animated_sprite and sprite_frames:
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.play(animation_name)
	
	# Connect the body_entered signal to our function (if not already connected)
	# body_entered is fired when another physics body enters our Area2D
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

# SIGNAL HANDLER FUNCTIONS

# Called when any physics body (like the player) enters our coin's area
# The _body parameter contains the node that entered (we don't use it here)
func _on_body_entered(_body: Node):
	# If we've already been collected, do nothing (prevents double-collection)
	if collected:
		return
	
	# Mark this coin as collected so it can't be collected again
	collected = true
	
	# Tell the Global script (likely a singleton/autoload) that a coin was collected
	# This probably updates the player's coin count, score, etc.
	Global.collect_coin()
	
	# Remove this coin from the scene completely
	# queue_free() safely deletes the node at the end of the current frame
	queue_free()
