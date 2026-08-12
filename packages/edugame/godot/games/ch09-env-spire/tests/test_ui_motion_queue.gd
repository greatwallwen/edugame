extends SceneTree

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn")
	_assert(scene != null, "main scene should load")
	if scene == null:
		_finish()
		return
	var game = scene.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	_assert(game.has_method("queue_card_play"), "UI should expose queued card play")
	_assert(game.has_method("card_action_queue_snapshot"), "card action queue should expose test state")
	_assert(game.has_method("map_transition_snapshot"), "map route transition should expose test state")
	_assert(game.has_method("map_charge_snapshot"), "tower charge animation should expose test state")
	if !game.has_method("queue_card_play") or !game.has_method("card_action_queue_snapshot"):
		game.queue_free()
		await process_frame
		_finish()
		return

	game._reset_run()
	game._start_encounter("mq2_warmup", "ordinary")
	game.hand = [game._card_copy("mq2_sample"), game._card_copy("mq2_sample")]
	game.processing_points = 3
	game.motion_duration_scale = 0.35
	game._render_state()
	await process_frame
	var first_button := game.find_child("HandCard_mq2_sample_0", true, false) as Button
	var second_button := game.find_child("HandCard_mq2_sample_1", true, false) as Button
	_assert(first_button != null and second_button != null, "queue fixture should render both cards")
	if first_button != null and second_button != null:
		_assert(game.queue_card_play(0, first_button), "first rapid card click should enter the queue")
		_assert(game.queue_card_play(1, second_button), "second rapid card click should enter the queue")
		var queued := game.card_action_queue_snapshot() as Dictionary
		_assert(game.hand.size() == 2, "queued cards should not settle before their animations")
		_assert(int(queued.get("pending", 0)) == 2, "both accepted rapid clicks should remain represented")
		await create_timer(0.55).timeout
		var settled := game.card_action_queue_snapshot() as Dictionary
		_assert(game.hand.is_empty(), "both queued cards should settle after their animations")
		_assert(int(settled.get("pending", -1)) == 0, "card queue should drain without swallowing an action")
		_assert(int(settled.get("settled", 0)) == 2, "each accepted click should produce one settlement")

	game._reset_run()
	game.state = game.RunState.MAP
	game._render_state()
	await process_frame
	var map_step := game.find_child("MapStep01", true, false) as Control
	_assert(map_step != null, "map route transition fixture should expose the first signal station")
	if map_step != null:
		await game._enter_available_route_node()
		var map_snapshot := game.map_transition_snapshot() as Dictionary
		_assert(!bool(map_snapshot.get("active", true)), "map input lock should release after the progress animation")
		_assert(int(map_snapshot.get("lastTarget", 0)) == 1, "map progress animation should resolve the selected node exactly once")
		_assert(game.state != game.RunState.MAP, "map node should resolve only after its progress animation")

	game._reset_run()
	game.current_layer = 1
	game.state = game.RunState.MAP
	game._render_state()
	_assert(game.map_enter_button.disabled, "next-node input should lock as soon as a cleared floor is waiting to charge")
	await game._animate_map_charge_entry(1)
	var charge_snapshot := game.map_charge_snapshot() as Dictionary
	_assert(!bool(charge_snapshot.get("active", true)), "tower charge input lock should release after the cleared floor lights up")
	_assert(int(charge_snapshot.get("chargedLayer", 0)) == 1, "tower charge should retain the newly cleared floor")
	_assert(is_equal_approx(float(charge_snapshot.get("progress", 0.0)), 1.0 / 12.0), "tower circuitry should illuminate exactly one floor after the first clear")
	_assert(!game.map_enter_button.disabled, "next-node input should return after the tower charge settles")

	game._start_encounter("mq2_warmup", "ordinary")
	game.hand = [game._card_copy("mq2_sample")]
	game.processing_points = 3
	game.motion_duration_scale = 0.8
	game._render_state()
	await process_frame
	var paused_button := game.find_child("HandCard_mq2_sample_0", true, false) as Button
	_assert(paused_button != null, "pause fixture should render its card")
	if paused_button != null:
		_assert(game.queue_card_play(0, paused_button), "card should enter the queue before host pause")
		game._set_host_paused(true)
		await create_timer(0.45).timeout
		_assert(game.hand.size() == 1, "host pause should preserve an animating queued action")
		_assert(int(game.card_action_queue_snapshot().get("pending", 0)) == 1, "paused action should remain queued")
		game._set_host_paused(false)
		await create_timer(0.45).timeout
		_assert(game.hand.is_empty(), "queued action should settle after host resume")
		_assert(int(game.card_action_queue_snapshot().get("pending", -1)) == 0, "resumed queue should drain")

	game.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)


func _finish() -> void:
	if failures == 0:
		print("Ch09 UI motion queue tests passed")
	quit(1 if failures > 0 else 0)
