extends Node

const RunSimulatorScript := preload("res://scripts/sim/RunSimulator.gd")
const Database := preload("res://scripts/rewards/RunUpgradeDatabase.gd")


func _ready() -> void:
	var runs_per_policy := 2000
	var output_path := "/tmp/ember_sim_results.json"
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		if str(args[index]) == "--runs" and index + 1 < args.size():
			runs_per_policy = int(args[index + 1])
			index += 2
			continue
		if str(args[index]) == "--out" and index + 1 < args.size():
			output_path = str(args[index + 1])
			index += 2
			continue
		index += 1

	var simulator := RunSimulatorScript.new()
	var payload := {
		"runs_per_policy": runs_per_policy,
		"policies": {},
	}
	for policy in [RunSimulatorScript.POLICY_RANDOM, RunSimulatorScript.POLICY_GREEDY, RunSimulatorScript.POLICY_SMART]:
		print("simulating %s x %d" % [policy, runs_per_policy])
		var batch: Dictionary = simulator.simulate_policy(policy, runs_per_policy)
		payload["policies"][policy] = simulator.summarize(batch)
		_print_policy(payload["policies"][policy])

	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % output_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	print("wrote %s" % output_path)
	get_tree().quit(0)


func _print_policy(summary: Dictionary) -> void:
	print("POLICY %s runs=%d win_rate=%.3f mean_combats=%.2f offers=%d" % [
		summary.get("policy", ""),
		int(summary.get("runs", 0)),
		float(summary.get("win_rate", 0.0)),
		float(summary.get("mean_combats", 0.0)),
		int(summary.get("offer_events", 0)),
	])
	var upgrades: Dictionary = summary.get("upgrades", {})
	for upgrade_id in Database.all_ids():
		var row: Dictionary = upgrades.get(upgrade_id, {})
		var offers := int(row.get("offers", 0))
		var picks := int(row.get("picks", 0))
		var owned := int(row.get("owned_runs", 0))
		var owned_wins := int(row.get("owned_wins", 0))
		print("  %s offers=%d picks=%d pwo=%.3f owned_win=%.3f" % [
			upgrade_id,
			offers,
			picks,
			float(picks) / float(maxi(1, offers)),
			float(owned_wins) / float(maxi(1, owned)),
		])
