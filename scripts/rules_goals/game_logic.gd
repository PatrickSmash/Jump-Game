@tool
class_name GameLogic
extends Node

## This is the GameLogic script - it controls the rules of the game
## It decides when the player wins or loses, manages the timer,
## and handles game restarts. Think of it as the "referee" of the game.

# ============================================================================
# EXPORT VARIABLES - These appear in the Godot editor and can be customized
# ============================================================================

@export_group("Win Condition")
## Should you win the game by collecting coins?
## If true, the player must collect a certain number of coins to win
@export var win_by_collecting_coins: bool = false

# HACK: the step needs to be 0.9 for displaying a slider in the editor
## How many coins to collect for winning?
## If zero, all the coins in the level must be collected.
## Note: if you set this higher than the actual number of coins,
## the game won't be winnable!
@export_range(0, 100, 0.9, "or_greater") var coins_to_win: int = 0

## Should you win the game by reaching a flag?
## If both coin collection and flag reaching are enabled,
## the player must collect enough coins AND reach a flag to win
@export var win_by_reaching_flag: bool = false

## Win by reaching a specific flag. If null, the player can win
## by reaching any flag placed in the scene.
@export var flag_to_win: Flag = null

# ============================================================================
# GAME CHALLENGE SETTINGS
# ============================================================================

@export_group("Challenges")
## You lose if this time runs out (in seconds)
## If zero (default), there won't be a time limit to win
## This creates urgency and makes the game more challenging
@export_range(0, 60, 0.9, "or_greater", "suffix:s") var time_limit: int = 10

# ============================================================================
# WORLD PHYSICS SETTINGS
# ============================================================================

@export_group("World Properties")
# Keep default the same as ProjectSettings.get_setting("physics/2d/default_gravity")
## This is the gravity of the world, in pixels per second squared
## Higher values make objects fall faster
## Negative values make objects fall upward!
@export_range(-2000.0, 2000.0, 0.1, "suffix:px/s²") var gravity: float = 980.0

# ============================================================================
# INTERNAL VARIABLES - These are used by the script but not shown in editor
# ============================================================================

## Prevents multiple restart attempts at the same time
## Without this, pressing restart rapidly could cause problems
var restart_delay := false

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

## Recursively finds all coin objects in the scene tree
## This is used to count total coins when coins_to_win is set to 0
## 
## How it works:
## - Starts with a parent node (usually the main scene)
## - Checks if the current node is a Coin
## - If it is, adds it to the accumulator array
## - Then checks all children of this node recursively
## - Returns an array containing all coin objects found
func get_all_coins(node, accumulator = []):
	# Check if this node is a coin
	if node is Coin:
		accumulator.append(node)
	
	# Check all children of this node
	for child in node.get_children():
		get_all_coins(child, accumulator)  # Recursive call

# ============================================================================
# GODOT LIFECYCLE FUNCTIONS
# ============================================================================

## Called when this node is added to the scene tree
## This sets up all the game rules and connections
func _ready():
	# Don't run this code in the editor - only when actually playing
	if Engine.is_editor_hint():
		return
	
	# Wait for the parent node to be fully ready
	# This ensures all other nodes are loaded before we start
	await get_parent().ready
	
	# ========================================
	# SET UP WORLD PHYSICS
	# ========================================
	
	# Set the gravity strength at runtime
	# This affects all physics objects in the scene
	PhysicsServer2D.area_set_param(
		get_viewport().find_world_2d().space, 
		PhysicsServer2D.AREA_PARAM_GRAVITY, 
		gravity
	)
	
	# Tell other objects about the gravity change
	# The player script listens to this to adjust its physics
	Global.gravity_changed.emit(gravity)
	
	# ========================================
	# SET UP WIN CONDITIONS
	# ========================================
	
	# If winning by collecting coins is enabled...
	if win_by_collecting_coins:
		# Listen for when coins are collected
		Global.coin_collected.connect(_on_coin_collected)
		
		# If coins_to_win is 0, count all coins in the level
		if coins_to_win == 0:
			var coins = []
			get_all_coins(get_parent(), coins)  # Find all coins
			coins_to_win = coins.size()         # Set target to total count
	
	# If winning by reaching a flag is enabled...
	if win_by_reaching_flag:
		# Listen for when flags are raised
		Global.flag_raised.connect(_on_flag_raised)
	
	# ========================================
	# SET UP TIMER (if time limit is set)
	# ========================================
	
	# Only create a timer if a time limit was specified
	if time_limit > 0:
		# Create and set up the timer through the Global script
		# The timer will be paused until the player moves
		Global.setup_timer(time_limit)

# ============================================================================
# SIGNAL HANDLERS - These respond to game events
# ============================================================================

## Called whenever a coin is collected
## Checks if the player has now met the win conditions
func _on_coin_collected():
	# Check if collecting this coin means the player wins
	if check_win_conditions(flag_to_win):
		# Player wins! End the game successfully
		Global.game_ended.emit(Global.Endings.WIN)

## Called whenever a flag is raised
## Checks if raising this flag means the player wins
func _on_flag_raised(flag: Flag):
	# Determine which flag to check for win conditions
	# If we have a specific flag requirement, use that
	# Otherwise, any flag will do
	var flag_to_check = flag_to_win if flag_to_win else flag
	
	# Check if raising this flag means the player wins
	if check_win_conditions(flag_to_check):
		# Player wins! End the game successfully
		Global.game_ended.emit(Global.Endings.WIN)
	elif flag_to_win == null or flag == flag_to_win:
		# If the player hasn't met all win conditions yet,
		# put the flag back down so they can try again
		flag.flag_position = Flag.FlagPosition.DOWN

# ============================================================================
# GAME LOGIC FUNCTIONS
# ============================================================================

## Checks if the player has met all the conditions needed to win
## Returns true if the player should win, false otherwise
func check_win_conditions(flag: Flag) -> bool:
	# If neither win condition is enabled, player can't win
	if not win_by_collecting_coins and not win_by_reaching_flag:
		return false
	
	# If coin collection is required, check if player has enough coins
	if win_by_collecting_coins and Global.coins < coins_to_win:
		return false  # Not enough coins collected yet
	
	# If flag reaching is required, check if a flag parameter was provided
	if win_by_reaching_flag and flag == null:
		return false  # No flag was provided
	
	# If flag reaching is required, check if the flag is actually raised
	if win_by_reaching_flag and flag.flag_position == Flag.FlagPosition.DOWN:
		return false  # Flag is not raised
	
	# If we get here, all win conditions have been met!
	return true

## Restarts the entire game by reloading the current scene
## This brings everything back to its starting state
func restart_game():
	# Reset all global game state before reloading
	# This clears coin counts, timers, etc.
	Global.reset_game_state()
	
	# Reload the current scene, which restarts everything
	# This is like pressing "restart level" in a game
	get_tree().reload_current_scene()

# ============================================================================
# INPUT HANDLING
# ============================================================================

## Called when the player presses a key that isn't handled elsewhere
## This is where we handle the restart key
func _unhandled_input(event):
	# Check if the restart key was pressed AND we're not already restarting
	if event.is_action_pressed("reset_game") and not restart_delay:
		# Set restart delay to prevent multiple restarts
		restart_delay = true
		
		# Actually restart the game
		restart_game()
