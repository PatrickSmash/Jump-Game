@tool
extends CanvasLayer
# This script runs on a CanvasLayer, which is ideal for UI because it stays fixed on screen

# Stores references to the win/lose labels based on the game result
@onready var ending_labels = {
	Global.Endings.WIN: %WinEnding,   # Label that shows when the player wins
	Global.Endings.LOSE: %LoseEnding, # Label that shows when the player loses
}

# Called every frame while the game is running
func _process(_delta):
	if Global.timer:
		# Update the time display on screen every frame with 1 decimal place
		%TimeLeft.text = "%.1f" % Global.timer.time_left

func _ready():
	# By default, we turn off _process and _physics_process
	set_process(false)
	set_physics_process(false)

	# Don't run this logic in the editor, only during the game
	if Engine.is_editor_hint():
		return

	# Connect global signals to local functions (these trigger events)
	Global.coin_collected.connect(_on_coin_collected)  # Called when a coin is collected
	Global.game_ended.connect(_on_game_ended)          # Called when the game ends
	Global.timer_added.connect(_on_timer_added)        # Called when a timer is added
	Input.joy_connection_changed.connect(_on_joy_connection_changed) # Called when a controller is connected/disconnected

	# Optional: hide the lives display if it exists (since we're not using lives)
	if has_node("%Lives"):
		%Lives.hide()

	# If the game is being played on a touchscreen device, skip the start screen
	if DisplayServer.is_touchscreen_available():
		%Start.hide()
		Global.game_started.emit() # Tell the game to begin automatically

# Called when a controller is connected or disconnected
func _on_joy_connection_changed(index: int, connected: bool):
	match index:
		0:
			if has_node("%PlayerOneJoypad"):
				%PlayerOneJoypad.visible = connected # Show/hide player 1 joystick UI
		1:
			if has_node("%PlayerTwoJoypad"):
				%PlayerTwoJoypad.visible = connected # Show/hide player 2 joystick UI

# Called when the player presses any key or touches the screen
func _unhandled_input(event):
	if (
		(
			event is InputEventKey                 # Keyboard input
			or event is InputEventJoypadButton    # Controller button
			or event is InputEventJoypadMotion    # Controller stick movement
			or event is InputEventScreenTouch     # Screen touch (mobile)
		)
		and %Start.is_visible_in_tree()           # Only respond if the Start label is visible
	):
		%Start.hide()         # Hide the Start screen
		Global.game_started.emit() # Tell the game to begin

# Called when a coin is collected
func _on_coin_collected():
	set_collected_coins(Global.coins) # Update the coins label

# Updates the coin counter label to show the correct number
func set_collected_coins(coins: int):
	%CollectedCoins.text = "Coins: " + str(coins)

# Called when a timer is added to the game (e.g., countdown starts)
func _on_timer_added():
	%TimeLeft.visible = true # Show the timer UI
	set_process(true)        # Start processing _process() every frame

# Called when the game ends (win or lose)
func _on_game_ended(ending: Global.Endings):
	ending_labels[ending].visible = true # Show the appropriate message (Win or Lose)
