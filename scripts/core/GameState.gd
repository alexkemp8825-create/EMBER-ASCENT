extends Node

const VERSION := "0.1.0-phase-3"

var current_screen: String = "main_menu"
var game_version: String = VERSION
var debug_mode: bool = true


func set_current_screen(screen_name: String) -> void:
	current_screen = screen_name


func reset() -> void:
	current_screen = "main_menu"
	game_version = VERSION
	debug_mode = true
