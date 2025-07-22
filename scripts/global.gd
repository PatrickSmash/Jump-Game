@tool
extends Node

## This is the Global script - it manages game-wide state and events
## Think of it as the "manager" that keeps track of important information
## that needs to be shared between different parts of the game

# ============================================================================
# SIGNALS - These are like announcements that tell other parts of the game when something happens
# ============================================================================

## Emitted when a coin is collected by the player
## Other scripts can "listen" to this signal to update UI, play sounds, etc.
signal coin_collected

## Emitted when a flag is raised (player reaches a checkpoint/goal)
## The flag parameter tells us which specific flag was raised
signal flag_raised(flag: Flag)

## Emitted when the game ends (either win or lose)
## The ending parameter tells us how the game ended
signal game_ended(ending: Endings)

## Emitted when the game starts (player first moves)
## This is different from _ready() - it happens when player actually starts playing
signal game_started

## Emitted by GameLogic when the world's gravitational force is changed
## This allows the player and other physics objects to adjust to new gravity
@warning_ignore("unused_signal")
signal gravity_changed(gravity: float)

## Emitted when a timer is added to the scene
## UI elements can listen to this to show timer displays
signal timer_added

# ============================================================================
# ENUMS - These are like categories or lists of possible values
# ============================================================================

## All the possible ways the game can end
## Using an enum makes code more readable than using numbers or strings
enum Endings { 
	WIN,  # Player successfully completed the level
	LOSE  # Player failed (ran out of time, fell off map, etc.)
}

# ============================================================================
# GAME STATE VARIABLES - These store important information about the current game
# ============================================================================
## Tracks how many lives the player has
var lives: int = 1

## Timer for finishing the level - tracks how much time is left
var timer: Timer

## Stores the number of coins collected by the player
## Starts at 0 when the game begins
var coins: int = 0

## Tracks whether the game has started yet
## The game doesn't "start" until the player presses their first input
var game_has_started: bool = false

# ============================================================================
# COIN COLLECTION SYSTEM
# ============================================================================

## Called when a coin is collected
## This increases the coin count and tells other parts of the game about it
func collect_coin():
	# Increase coin count by 1
	coins += 1
	
	# Announce to the rest of the game that a coin was collected
	# This might trigger UI updates, sound effects, etc.
	coin_collected.emit()
	
	# Start the game if this is the first action
	_start_game_if_needed()
	
## Called to end the game with a specific ending
## This is the method that dangerzone and other scripts will call
func end_game(ending: Endings):
	# Emit the game_ended signal with the specified ending
	game_ended.emit(ending)
	
	# Optional: Add any additional game-ending logic here
	# For example: pause the game, show game over screen, etc.
	print("Game ended with result: ", ending)

## Alternative method name that some scripts might look for
func game_over():
	# Just call end_game with LOSE ending
	end_game(Endings.LOSE)

## Another alternative method name
func lose_game():
	# Just call end_game with LOSE ending
	end_game(Endings.LOSE)

# ============================================================================
# FLAG SYSTEM
# ============================================================================

## Called when a flag is raised (player reaches a checkpoint/goal)
## This tells the rest of the game that a flag was interacted with
func raise_flag(flag: Flag):
	# Announce to the rest of the game that a flag was raised
	# The GameLogic script listens to this to check win conditions
	flag_raised.emit(flag)
	
	# Start the game if this is the first action
	_start_game_if_needed()

# ============================================================================
# TIMER SYSTEM
# ============================================================================

## Sets up a timer with the given time limit (in seconds)
## The timer will count down and end the game when it reaches 0
func setup_timer(time_limit: int):
	# Clean up any existing timer first
	# This prevents memory leaks and duplicate timers
	if timer:
		timer.queue_free()  # Safely remove the old timer
	
	# Create a new timer node
	timer = Timer.new()
	timer.one_shot = true  # Timer only runs once, doesn't repeat
	
	# Connect the timer's timeout signal to our function
	# When the timer reaches 0, _on_timer_timeout() will be called
	timer.timeout.connect(_on_timer_timeout)
	
	# Add the timer to our scene tree so it can run
	add_child(timer)
	
	# Set the timer duration and start it
	timer.start(time_limit)
	
	# IMPORTANT: Pause the timer immediately!
	# It won't start counting down until the player moves
	timer.paused = true
	
	# Tell other parts of the game that a timer was added
	# This might trigger UI elements to appear
	timer_added.emit()

## Called when the timer runs out
## This ends the game with a "lose" condition
func _on_timer_timeout():
	# End the game - player ran out of time
	game_ended.emit(Endings.LOSE)

# ============================================================================
# GAME STATE MANAGEMENT
# ============================================================================

## Resets all game state variables back to their starting values
## This is called when restarting the level
func reset_game_state():
	# Reset coin count back to 0
	coins = 0
	
	# Mark that the game hasn't started yet
	game_has_started = false
	
	# Clean up the timer completely
	if timer:
		timer.queue_free()  # Remove timer from memory
		timer = null        # Clear our reference to it

## Starts the game if it hasn't started yet
## This is called whenever the player performs their first action
func _start_game_if_needed():
	# Only start once - ignore subsequent calls
	if not game_has_started:
		game_has_started = true
		
		# Announce that the game has started
		# This will unpause the timer and might trigger other events
		game_started.emit()

# ============================================================================
# GODOT LIFECYCLE FUNCTIONS
# ============================================================================

## Called when this node is added to the scene tree
## This sets up our signal connections
func _ready():
	# Connect our signals to handler functions
	# This creates a "communication network" between different parts of the game
	
	# Listen for when the game ends
	game_ended.connect(_on_game_ended)
	
	# Listen for when the game starts
	game_started.connect(_on_game_start)

# ============================================================================
# SIGNAL HANDLERS - These functions are called when signals are emitted
# ============================================================================

## Called when the game ends (either win or lose)
## This pauses the timer so it stops counting down
func _on_game_ended(_ending: Endings):
	# Pause the timer if it exists and is still running
	# We don't want the timer to keep counting after the game ends
	if timer and not timer.is_stopped():
		timer.paused = true

## Called when the game starts (player makes their first move)
## This unpauses the timer so it starts counting down
func _on_game_start():
	# Start the timer if it has been set up
	# The timer was paused when created, now we unpause it
	if timer != null:
		timer.paused = false  # Timer starts counting down NOW
