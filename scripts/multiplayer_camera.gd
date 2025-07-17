class_name MultiplayerCamera
extends Camera2D
# This script is for a dynamic camera that smoothly follows all players and zooms out as needed
# to make sure everyone stays on screen. Useful for multiplayer or larger levels.

# ==============================
# == CONSTANTS ==
# ==============================

const FRAME_MARGIN: int = 128  # Extra space around the edge of the camera's view so players aren't right at the edge
const MIN_ZOOM: float = 1.0    # Closest the camera can zoom in (normal size)
const MAX_ZOOM: float = 0.4    # Furthest the camera can zoom out (everything looks smaller)

# ==============================
# == VARIABLES ==
# ==============================

var player_characters: Array[Player]  # List to store all player instances found in the scene

# Get the size of the screen (in pixels) when the game starts
@onready var viewport_size: Vector2 = get_viewport_rect().size

# ==============================
# == READY FUNCTION ==
# ==============================

func _ready():
	if not enabled or not is_current():
		set_process(false)  # Don't run the camera logic if it's not enabled or current
		return

	# Find all nodes in the "players" group and store them in the player_characters array
	for pc in get_tree().get_nodes_in_group("players"):
		player_characters.append(pc as Player)

# ==============================
# == CAMERA LOGIC ==
# ==============================

func _physics_process(delta: float):
	if not player_characters:
		return  # No players to follow

	# --- POSITION LOGIC ---
	var new_position: Vector2 = Vector2.ZERO

	# Add up all player positions
	for pc: Player in player_characters:
		new_position += pc.position

	# Find the average position (center point between all players)
	new_position /= player_characters.size()

	# Smooth camera movement (optional)
	if position_smoothing_enabled:
		position = lerp(position, new_position, position_smoothing_speed * delta)
	else:
		position = new_position

	# --- ZOOM (FRAMING) LOGIC ---
	# Create a rectangle (frame) that covers all player positions
	var frame = Rect2(position, Vector2.ONE)
	for pc: Player in player_characters:
		frame = frame.expand(pc.position)  # Expands the rectangle to include each player's position

	# Add extra space around the frame so players aren't too close to the edge
	frame = frame.grow_individual(FRAME_MARGIN, FRAME_MARGIN, FRAME_MARGIN, FRAME_MARGIN)

	# Decide how much to zoom the camera to fit the frame in the viewport
	var new_zoom: float
	if frame.size.x > frame.size.y * viewport_size.aspect():
		# If the width is the limiting factor
		new_zoom = clamp(viewport_size.x / frame.size.x, MAX_ZOOM, MIN_ZOOM)
	else:
		# If the height is the limiting factor
		new_zoom = clamp(viewport_size.y / frame.size.y, MAX_ZOOM, MIN_ZOOM)

	# Smooth zooming
	zoom = lerp(zoom, Vector2.ONE * new_zoom, 0.5)
