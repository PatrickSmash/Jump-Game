extends Control

@onready var game_title = $GameTitle
@onready var begin_button = $BeginButton
@onready var story_text = $StoryText
@onready var play_button = $PlayButton
@onready var menu_music = $MenuMusic
@onready var demon1 = $Sprite2D9
@onready var demon2 = $Sprite2D10

func _ready():
	# Show title screen first
	show_title_screen()
	
	# Connect button signals
	begin_button.pressed.connect(_on_begin_button_pressed)
	play_button.pressed.connect(_on_play_button_pressed)

func show_title_screen():
	# Show title elements
	game_title.visible = true
	begin_button.visible = true
	demon1.visible = true
	demon2.visible = true
	
	# Hide story elements
	story_text.visible = false
	play_button.visible = false
	
	# Start menu music if available
	if menu_music and not menu_music.playing:
		menu_music.play()

func _on_begin_button_pressed():
	# Hide title elements
	game_title.visible = false
	begin_button.visible = false
	demon1.visible = false
	demon2.visible = false
	
	# Show story elements
	story_text.visible = true
	play_button.visible = true
	
	# Keep menu music playing during story

func _on_play_button_pressed():
	# Stop menu music before transitioning
	if menu_music:
		menu_music.stop()
	
	# Transition to main game (music will start there)
	# Replace with your actual scene path
	get_tree().change_scene_to_file("res://main.tscn")
