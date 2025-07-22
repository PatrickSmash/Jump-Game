@tool
extends Area2D

## This script creates a danger zone that ends the game when the player enters it
## Examples: spikes, lava, poison water, electric barriers, etc.
## When the player touches this area, the game immediately goes to the lose ending

# ============================================================================
# SIGNALS - These are messages this script can send to other parts of the game
# ============================================================================

## This signal is emitted (sent out) when any body enters the danger zone
## Other scripts can "connect" to this signal to respond when it happens
signal dangerzone_entered

# ============================================================================
# EXPORT VARIABLES - These appear in the Godot editor for customization
# ============================================================================

## The collision shape that defines the danger zone area
## You can change this in the editor to make different shaped danger zones
## Examples: Rectangle for spike pits, Circle for poison pools
@export var shape: Shape2D:
	set(value):
		# This setter function runs whenever the shape is changed
		# We need to wait for the node to be ready before accessing child nodes
		if not is_node_ready():
			await ready
		# Update the actual collision shape in the scene
		%CollisionShape2D.shape = value
	get:
		# This getter function returns the current shape
		return %CollisionShape2D.shape

## Should this danger zone trigger the lose ending immediately?
## If false, it will try to reduce lives instead (old behavior)
@export var instant_lose: bool = true

# ============================================================================
# SIGNAL HANDLERS - These functions run when specific events happen
# ============================================================================

## This function is called when ANY body enters the danger zone
## In Godot, "bodies" are CharacterBody2D, RigidBody2D, etc.
## The _body parameter contains information about what entered the zone
func _on_body_entered(_body):
	# IMPORTANT: We use underscore before 'body' because we're not using it
	# This tells Godot (and other programmers) that we know the parameter exists
	# but we're choosing not to use it in this function
	
	# Send out a signal to let other parts of the game know something entered
	# Other scripts can connect to this signal to play sounds, show effects, etc.
	dangerzone_entered.emit()
	
	# Check if we should end the game immediately
	if instant_lose:
		# End the game with the lose ending
		if Global.has_method("end_game"):
			Global.end_game(Global.Endings.LOSE)
		elif Global.has_method("game_over"):
			Global.game_over()
		elif Global.has_method("lose_game"):
			Global.lose_game()
		else:
			# Try to set a game state variable if the methods don't exist
			if "game_state" in Global:
				Global.game_state = "lose"
			elif "is_game_over" in Global:
				Global.is_game_over = true
			else:
				print("ERROR: Cannot find a way to end the game in Global script!")
				print("Make sure Global has an end_game() method or game_over() method")
	else:
		# Old behavior - try to reduce lives instead
		_handle_lives_system()

## Handles the old lives-based system (only used if instant_lose is false)
func _handle_lives_system():
	# Check if Global has the lives property before accessing it
	if Global.has_method("take_damage"):
		Global.take_damage(1)
	elif Global.has_method("lose_life"):
		Global.lose_life()
	elif "lives" in Global:
		Global.lives -= 1
	elif "player_lives" in Global:
		Global.player_lives -= 1
	else:
		print("ERROR: Global script doesn't have a lives property or damage function!")
		print("Check your Global script to see how lives/health is handled")

# ============================================================================
# GODOT LIFECYCLE FUNCTIONS
# ============================================================================

## Called when the node enters the scene tree for the first time
func _ready():
	# Don't run this script in the editor - only when actually playing the game
	if Engine.is_editor_hint():
		return
	
	# Connect the body_entered signal to our function
	# Connect the dangerzone_entered signal to our trigger function
	dangerzone_entered.connect(_on_dangerzone_triggered)

## Function to handle when the dangerzone is triggered
## You can expand this to add visual effects, sounds, screen shake, etc.
func _on_dangerzone_triggered():
	print("Player entered danger zone - Game Over!")

# ============================================================================
# UTILITY FUNCTIONS - Helper functions for this script
# ============================================================================

## Call this function to temporarily disable the danger zone
## Useful for power-ups, invincibility frames, etc.
func disable_danger_zone():
	# Disable the collision detection
	%CollisionShape2D.disabled = true
	
	# Optional: Make it visually appear disabled
	modulate = Color(1, 1, 1, 0.5)  # Make it semi-transparent

## Call this function to re-enable the danger zone
func enable_danger_zone():
	# Re-enable the collision detection
	%CollisionShape2D.disabled = false
	
	# Optional: Make it visually appear normal again
	modulate = Color(1, 1, 1, 1)  # Make it fully opaque

## Check if the danger zone is currently active
func is_danger_zone_active() -> bool:
	return not %CollisionShape2D.disabled

## Toggle between instant lose and lives system
func set_instant_lose(value: bool):
	instant_lose = value

# ============================================================================
# BEGINNER NOTES AND TIPS
# ============================================================================

## HOW THE LOSE ENDING WORKS:
## This script now tries multiple ways to end the game:
## 1. Global.end_game(Global.Endings.LOSE) - Most common pattern
## 2. Global.game_over() - Alternative method name
## 3. Global.lose_game() - Another alternative
## 4. Set Global.game_state = "lose" - Direct state setting
## 5. Set Global.is_game_over = true - Simple boolean flag

## WHAT IS AN AREA2D?
## Area2D is a node that detects when other objects enter or exit its space
## It doesn't have physics (objects pass through it), but it can detect collisions
## Perfect for: pickups, triggers, danger zones, invisible barriers

## COMMON MISTAKES TO AVOID:
## 1. Not connecting the body_entered signal - your function won't be called
## 2. Not having the right method in Global to end the game
## 3. Forgetting to set up the CollisionShape2D child node
## 4. Not setting the collision_layer and collision_mask correctly

## HOW TO SET UP THIS DANGER ZONE:
## 1. Create an Area2D node in your scene
## 2. Add a CollisionShape2D as a child of the Area2D
## 3. Attach this script to the Area2D node
## 4. In the CollisionShape2D, set the Shape to a RectangleShape2D or CircleShape2D
## 5. Make sure your player has a CharacterBody2D (or other physics body)
## 6. Set the collision layers/masks so the player can be detected
## 7. Make sure your Global script has an end_game() method that accepts Global.Endings.LOSE

## COLLISION LAYERS AND MASKS:
## - Layer: What layer this object exists on
## - Mask: What layers this object can detect/collide with
## - For a danger zone, you want to DETECT the player layer
## - Set the Mask to include the player's layer number
