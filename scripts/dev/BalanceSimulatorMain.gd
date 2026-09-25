extends Node

const BalanceRunSimulatorScript := preload("res://scripts/dev/BalanceRunSimulator.gd")


func _ready() -> void:
	var config: Dictionary = BalanceRunSimulatorScript.parse_cmdline(BalanceRunSimulatorScript.default_config())
	var simulator = BalanceRunSimulatorScript.new()
	var result: Dictionary = simulator.run(config)
	get_tree().quit(0 if int(result.get("errors", 1)) == 0 else 1)
