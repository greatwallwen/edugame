extends SceneTree

const FPS := 30
const CAPTURE_SIZE := Vector2i(1280, 720)
const DEMO_SAVE_PATH := "user://ch09_demo_run_save.json"
const DEMO_SETTINGS_PATH := "user://ch09_demo_settings.cfg"
const DEMO_TUTORIAL_PATH := "user://ch09_demo_tutorial.cfg"
const DEMO_CODEX_PATH := "user://ch09_demo_codex.cfg"

var game
var failed := false
var title_back: ColorRect
var title_heading: Label
var title_subtitle: Label
var caption_panel: PanelContainer
var caption_heading: Label
var caption_body: Label
var recording_section := "startup"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(CAPTURE_SIZE)
	get_root().size = CAPTURE_SIZE
	var scene := load("res://scenes/main.tscn")
	if !_require(scene != null, "main scene should load"):
		await _finish()
		return

	game = scene.instantiate()
	game.run_save_path = DEMO_SAVE_PATH
	game.settings_path = DEMO_SETTINGS_PATH
	game.tutorial_record_path = DEMO_TUTORIAL_PATH
	game.codex_record_path = DEMO_CODEX_PATH
	get_root().add_child(game)
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.position = Vector2.ZERO
	game.size = Vector2(CAPTURE_SIZE)
	await _hold(0.2)
	_build_overlay()

	await _record_title()
	if failed:
		await _finish()
		return
	await _record_menu_and_settings()
	if failed:
		await _finish()
		return
	await _record_node_lab()
	if failed:
		await _finish()
		return
	await _record_tutorial()
	if failed:
		await _finish()
		return
	await _record_formal_run()
	if failed:
		await _finish()
		return
	await _record_event()
	if failed:
		await _finish()
		return
	await _record_elite_fault()
	if failed:
		await _finish()
		return
	await _record_boss_and_result()
	await _finish()


func _build_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	get_root().add_child(overlay)

	title_back = ColorRect.new()
	title_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_back.color = Color("#0b2025")
	title_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(title_back)

	var title_stack := VBoxContainer.new()
	title_stack.set_anchors_preset(Control.PRESET_CENTER)
	title_stack.position = Vector2(-430, -95)
	title_stack.size = Vector2(860, 190)
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 12)
	title_back.add_child(title_stack)

	title_heading = Label.new()
	title_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_heading.add_theme_font_size_override("font_size", 42)
	title_heading.add_theme_color_override("font_color", Color("#f1fbfa"))
	title_stack.add_child(title_heading)

	title_subtitle = Label.new()
	title_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_subtitle.add_theme_font_size_override("font_size", 22)
	title_subtitle.add_theme_color_override("font_color", Color("#9ed1d5"))
	title_stack.add_child(title_subtitle)

	caption_panel = PanelContainer.new()
	caption_panel.anchor_top = 1.0
	caption_panel.anchor_bottom = 1.0
	caption_panel.offset_left = 16
	caption_panel.offset_top = -76
	caption_panel.offset_right = 1010
	caption_panel.offset_bottom = -8
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption_style := StyleBoxFlat.new()
	caption_style.bg_color = Color(0.035, 0.10, 0.12, 0.94)
	caption_style.border_color = Color("#55a5ae")
	caption_style.set_border_width_all(1)
	caption_style.set_corner_radius_all(5)
	caption_style.content_margin_left = 14
	caption_style.content_margin_right = 14
	caption_style.content_margin_top = 6
	caption_style.content_margin_bottom = 6
	caption_panel.add_theme_stylebox_override("panel", caption_style)
	overlay.add_child(caption_panel)

	var caption_stack := VBoxContainer.new()
	caption_stack.add_theme_constant_override("separation", 1)
	caption_panel.add_child(caption_stack)

	caption_heading = Label.new()
	caption_heading.add_theme_font_size_override("font_size", 18)
	caption_heading.add_theme_color_override("font_color", Color("#eefafa"))
	caption_stack.add_child(caption_heading)

	caption_body = Label.new()
	caption_body.add_theme_font_size_override("font_size", 13)
	caption_body.add_theme_color_override("font_color", Color("#b8d5d8"))
	caption_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_stack.add_child(caption_body)

	var font := load("res://assets/fonts/NotoSansSC-VF.ttf") as Font
	if font != null:
		for label in [title_heading, title_subtitle, caption_heading, caption_body]:
			(label as Label).add_theme_font_override("font", font)
	caption_panel.hide()


func _record_title() -> void:
	recording_section = "title"
	_show_title("第九章  环境监测工程", "全功能桌面验收 · 教程 / 开发者模式 / 正常流程")
	await _hold(3.0)


func _record_menu_and_settings() -> void:
	recording_section = "menu_and_settings"
	game._reset_run()
	game.current_layer = 2
	if !_require(game._save_run_now(), "demo resume fixture should save"):
		return
	game.show_start_menu()
	game._render_state()
	title_back.hide()
	_show_caption("正式版开始菜单", "教程、正式游戏、继续游戏、开发者测试、图鉴和设置均可直接进入。")
	await _hold(4.0)

	if !_require(game.select_start_menu_command("codex"), "demo codex should open"):
		return
	_show_caption("卡牌与故障图鉴", "图鉴记录已发现卡牌和已解决故障；未在正常流程中遇到的内容保持锁定。")
	await _hold(4.0)
	game.show_start_menu()

	if !_require(game.select_start_menu_command("settings"), "demo settings should open"):
		return
	_show_caption("持久化设置", "可调整音效、音量、动画速度和减弱闪光；Web 刷新后仍会保留。")
	await _hold(4.0)
	game._close_settings()
	if !_require(game.select_start_menu_command("resume"), "demo saved run should resume"):
		return
	_show_caption("断点续玩", "继续游戏恢复已解析路线、节点进度、牌组和完整战斗状态。")
	await _hold(4.0)
	game._open_run_menu()
	_show_caption("局内运行菜单", "可继续、调整设置、保存并返回、重新开始或放弃本局。")
	await _hold(3.0)
	game._close_run_menu()


func _record_node_lab() -> void:
	recording_section = "node_lab"
	_show_title("开发者测试模式", "独立体验节点并直接调整牌组、手牌和战斗数值")
	await _hold(3.0)
	title_back.hide()
	game.show_start_menu()
	if !_require(game.select_start_menu_command("node_lab"), "demo node lab should open"):
		return
	_show_caption("节点实验室目录", "普通故障、精英、Boss 六规则、题目、检查点、组件、整备和奖励都可单独启动。")
	await _hold(5.0)

	var scenario := {
		"id": "demo_adc_spike",
		"kind": "enemy",
		"contentId": "adc_spike",
		"tier": "ordinary",
		"seedId": 901
	}
	if !_require(game.start_lab_scenario(scenario, "starter"), "demo node lab scenario should start"):
		return
	_show_caption("单节点即时体验", "每次启动都会重置稳定度、牌组和组件，不会污染正式游戏存档。")
	await _hold(4.0)

	game.node_lab_overlay.show_debug_panel()
	_show_caption("开发者调试面板", "可指定卡牌加入手牌、逐张删除手牌或牌组卡，并手动设置玩家稳定度和故障剩余值。")
	await _hold(5.0)
	if !_require(game.lab_add_card_to_hand("logic_probe"), "demo node lab should add an exact card"):
		return
	if !_require(game.lab_set_stability(36), "demo node lab should set stability"):
		return
	if !_require(game.lab_set_fault_remaining(12), "demo node lab should set fault remaining"):
		return
	if !game.hand.is_empty():
		if !_require(game.lab_remove_hand_card(0), "demo node lab should remove a hand card"):
			return
	game.node_lab_overlay.refresh_debug_panel()
	_show_caption("调试值即时生效", "示例已加入指定诊断牌、删除一张手牌，并把稳定度设为 36、故障剩余设为 12。")
	await _hold(5.0)
	game.node_lab_overlay.hide_debug_panel()

	if !_require(game.restart_lab_scenario(), "demo node lab scenario should restart"):
		return
	_show_caption("重开当前节点", "一键恢复该节点的初始牌组、稳定度、组件和故障进度，便于重复验证。")
	await _hold(4.0)
	game.return_to_node_lab()
	_show_caption("返回节点目录", "调试完成后返回目录继续选择其他事件，不进入正式 12 节点流程。")
	await _hold(4.0)
	game.show_start_menu()


func _record_tutorial() -> void:
	recording_section = "tutorial"
	_show_title("新手操作教程", "从故障意图到工程链闭环，逐步完成一次引导战斗")
	await _hold(3.0)

	title_back.hide()
	game._start_tutorial_briefing()
	game._render_state()
	_show_caption("教程入口与流程目标", "先查看 12 节点流程说明，再通过实际操作认识故障意图、手牌、处理点和回合节奏。")
	await _hold(5.0)

	game._start_tutorial_encounter()
	if !_require(game.tutorial_step == game.TutorialStep.READ_INTENT, "tutorial should enter intent step"):
		return
	_show_caption("步骤 1 / 6：读取故障意图", "先确认故障本回合准备造成的影响，再决定防御、采集或推进工程链。")
	await _hold(4.0)

	if !_require(game.confirm_tutorial_intent(), "tutorial intent should confirm"):
		return
	_show_caption("步骤 2 / 6：使用防御牌", "滑动平均滤波提供防护，并演示乱序防御不会打断工程链。")
	await _hold(3.0)
	if !_queue_tutorial_card("sliding_average"):
		return
	if !(await _wait_for_card_queue()):
		return
	await _hold(0.8)

	_show_caption("步骤 3 / 6：结束回合", "无法继续出牌时结束回合，故障按预告执行，然后补充下一组教学手牌。")
	await _hold(3.0)
	if !_require(game.end_turn(), "tutorial turn should end"):
		return
	await _hold(0.8)

	_show_caption("步骤 4 / 6：采集", "MQ-2 采样取得烟雾原始数据，点亮工程链的采集阶段。")
	await _hold(3.0)
	if !_queue_tutorial_card("mq2_sample"):
		return
	if !(await _wait_for_card_queue()):
		return
	await _hold(0.8)

	_show_caption("步骤 5 / 6：转换", "ADC 消费烟雾原始数据，将模拟量转换为 MCU 可处理的可信数据。")
	await _hold(3.0)
	if !_queue_tutorial_card("adc_convert"):
		return
	if !(await _wait_for_card_queue()):
		return
	await _hold(0.8)

	_show_caption("步骤 6 / 6：输出", "LED 报警消费可信数据，完成“采集 → 转换 → 输出”的工程闭环。")
	await _hold(3.0)
	if !_queue_tutorial_card("led_alarm"):
		return
	if !(await _wait_for_card_queue()):
		return
	await _hold(0.8)

	if !_require(game.tutorial_step == game.TutorialStep.COMPLETE, "tutorial should complete"):
		return
	_show_caption("教程完成并进入正式流程", "后续 12 个节点会把传感器接口、滤波、调度与输出知识转化为卡牌规则。")
	await _hold(4.0)


func _record_formal_run() -> void:
	recording_section = "formal_run"
	game._start_clean_formal_run()
	_show_caption("12 节点单线路线", "战斗、问答、构筑、检查点和休整按固定节奏推进，Boss 前必有休整。")
	await _hold(5.0)

	if !_require(game.choose_node(0), "formal run should enter its first node"):
		return
	game.hand = [
		game._card_copy("mq2_sample"),
		game._card_copy("bh1750_read"),
		game._card_copy("adc_convert"),
		game._card_copy("led_alarm")
	]
	game.processing_points = 6
	game.motion_duration_scale = 1.35
	game._render_state()
	_show_caption("普通故障战", "观察故障规则与弱点，按工程阶段组织手牌，而不是单纯堆叠伤害。")
	await _hold(4.0)

	if !_queue_visible_card("mq2_sample", 0):
		return
	if !_queue_visible_card("bh1750_read", 1):
		return
	_show_caption("快速连续出牌", "两次点击都会被保留，卡牌动画依次播完后逐张结算，不吞掉后续操作。")
	if !(await _wait_for_card_queue()):
		return
	await _hold(1.2)

	if !_queue_visible_card("adc_convert", 0):
		return
	_show_caption("工程链：接口转换", "ADC 在采集牌结算后消费烟雾原始数据，得到可用于判断的可信数据。")
	if !(await _wait_for_card_queue()):
		return
	await _hold(1.2)

	if !_queue_visible_card("led_alarm", 0):
		return
	_show_caption("工程链：输出", "可信烟雾数据触发本地报警，连携提高修复效率。")
	if !(await _wait_for_card_queue()):
		return
	await _hold(1.6)

	if game.state == game.RunState.COMBAT:
		game.encounter_evidence_tags.clear()
		for raw_group in game.current_encounter.get("evidenceGroups", []) as Array:
			var group := raw_group as Array
			if !group.is_empty():
				game.encounter_evidence_tags[str(group[0])] = true
		game.repair_progress = game.repair_target
		game._finish_encounter()
		game._render_state()
	if !_require(game.state == game.RunState.REWARD, "completed demo combat should open rewards"):
		return
	_show_caption("构筑奖励", "每场故障后补充协同、补链或反制牌，逐步形成应对后续验收的卡组。")
	await _hold(5.0)

	var reward_id := ""
	if !game.reward_choices.is_empty():
		reward_id = str((game.reward_choices[0] as Dictionary).get("id", ""))
	if !_require(game.choose_reward(reward_id), "demo reward should resolve"):
		return
	game._render_state()
	await _hold(1.2)


func _record_event() -> void:
	recording_section = "event_and_components"
	game.current_node = {"type": "checkpoint_sensor"}
	game._start_checkpoint(true)
	game._render_state()
	_show_caption("教学检查点", "检查点要求玩家用当前牌组证明传感器接入或可信数据能力，通过与失败都会写入学习报告。")
	await _hold(4.0)

	game._open_component_choice()
	game._render_state()
	_show_caption("工程组件三选一", "组件提供每场一次或持续工程增益；选择结果进入本局并在新故障开始时重置战斗追踪。")
	await _hold(5.0)
	if !_require(!game.component_choices.is_empty(), "demo component choices should exist"):
		return
	var component_id := str((game.component_choices[0] as Dictionary).get("id", ""))
	if !_require(game.choose_component(component_id), "demo component should resolve"):
		return

	var event := (game.event_defs.get("basic_mq2_warmup", {}) as Dictionary).duplicate(true)
	if !_require(!event.is_empty(), "question event fixture should exist"):
		return
	game.current_node = {"type": "event", "contentId": "basic_mq2_warmup"}
	game._begin_question_event(event, true)
	game._render_state()
	_show_caption("随机问答事件", "问号节点把课程知识转成诊断、排序、代码追踪、参数和波形题。")
	await _hold(5.0)

	var expected = game.current_event.get("correctAnswer")
	var answer = expected.duplicate(true) if expected is Array or expected is Dictionary else expected
	if !_require(game.submit_event_answer(answer), "demo question should accept the correct answer"):
		return
	game._render_state()
	_show_caption("答题反馈", "正确答案立即给出工程解释和构筑奖励；错误答案会带来稳定度或牌组惩罚。")
	await _hold(5.0)

	if bool(game.event_result.get("rewardPending", false)):
		var indices: Array = game.event_result.get("availableRewardIndices", [])
		if !_require(!indices.is_empty(), "correct demo answer should offer an available reward"):
			return
		if !_require(game.choose_event_reward(int(indices[0])), "demo event reward should apply"):
			return
		if !game.pending_card_selection.is_empty():
			if !_require(game.choose_pending_card(0), "demo event selection should resolve"):
				return
	if bool(game.event_result.get("resolved", false)):
		if !_require(game.continue_event(), "demo event should continue to the map"):
			return
	game._render_state()
	await _hold(1.2)


func _record_elite_fault() -> void:
	recording_section = "elite_fault"
	game.current_node = {"type": "elite", "contentId": "display_bus_deadlock"}
	game._start_encounter("display_bus_deadlock", "elite")
	game.hand = [
		game._card_copy("lcd_display"),
		game._card_copy("task_yield"),
		game._card_copy("uart_log")
	]
	game.trusted_data = {"smoke": 0, "light": 1, "temp": 0, "humidity": 0}
	game.processing_points = 4
	game._render_state()
	_show_caption("新增精英故障：显示总线死锁", "显示输出若缺少缓冲、调度或诊断，会损失稳定度并加入阻塞延时。")
	await _hold(4.0)
	if !_queue_visible_card("lcd_display", 0):
		return
	if !(await _wait_for_card_queue()):
		return
	_show_caption("故障规则数据化结算", "同一套惩罚执行器处理伤害、负面牌和下回合处理点变化，并给出明确反制条件。")
	await _hold(4.0)


func _record_boss_and_result() -> void:
	recording_section = "boss_and_result"
	game.current_layer = 11
	game.current_node = {"type": "service", "label": "节点 11 · Boss 前整备"}
	game.state = game.RunState.REST
	game.stability = 58
	game._render_state()
	_show_caption("Boss 前强制休整", "恢复稳定度、升级或精简卡组，为最终验收补齐缺失的工程阶段。")
	await _hold(5.0)
	if !_require(game.choose_service("maintenance"), "demo rest action should resolve"):
		return

	game.current_node = {"type": "boss", "contentId": "warehouse_acceptance"}
	game.boss_gate_ids.assign(["three_sources", "trusted_and_filter", "acceptance_output"])
	game._start_encounter("warehouse_acceptance", "boss")
	game._render_state()
	_show_caption("Boss 阶段 1：覆盖三个来源", "当前规则明确显示在条带与证据区，阶段援助会补入基础牌组缺少的关键牌。")
	await _hold(5.0)

	game.boss_phase = 1
	game._apply_boss_phase()
	game._render_state()
	_show_caption("Boss 阶段 2：两类可信数据 + 滤波", "规则按运行种子确定并写入存档，换阶段不会重置组件的一场一次效果。")
	await _hold(5.0)

	game.boss_phase = 2
	game._apply_boss_phase()
	game._render_state()
	_show_caption("Boss 阶段 3：验收输出 + 另一种输出", "六种可见规则组合共享同一验收接口，不依赖隐藏条件。")
	await _hold(5.0)

	game.current_layer = 12
	game.checkpoints_passed = 2
	game.stability = 65
	game.source_coverage = {"smoke": true, "light": true, "temp": true}
	game.trusted_sources_seen = {"smoke": true, "light": true}
	game.filters_played = 1
	game.knowledge_stats = {
		"tags": {
			"calibration": {"positive": 2, "errors": 0},
			"i2c": {"positive": 1, "errors": 1},
			"adc": {"positive": 1, "errors": 0}
		},
		"questionCorrect": 3, "questionTotal": 4,
		"weaknessRepair": 36, "totalRepair": 54,
		"reviewFaultIds": ["display_bus_deadlock"]
	}
	game.codex_progress = {"version": 1, "cards": [], "faults": ["display_bus_deadlock"]}
	if game.relics.is_empty() and !game.relic_defs.is_empty():
		game.relics.append(str(game.relic_defs.keys()[0]))
	game._finish_run(true)
	game._render_state()
	if !_require(game.state == game.RunState.RESULT and game.victory, "demo run should finish with victory"):
		return
	_show_caption("知识结算报告", "结算区分已掌握、继续加强和正在建立，并可直接跳转到本局推荐复习故障。")
	await _hold(5.0)

	caption_panel.hide()
	_show_title("演示结束", "第九章 · 环境监测工程")
	await _hold(3.0)


func _show_title(heading: String, subtitle: String) -> void:
	title_heading.text = heading
	title_subtitle.text = subtitle
	title_back.show()
	caption_panel.hide()


func _show_caption(heading: String, body: String) -> void:
	title_back.hide()
	caption_heading.text = heading
	caption_body.text = body
	caption_panel.show()


func _queue_visible_card(card_id: String, hand_index: int) -> bool:
	var button_name := "HandCard_%s_%d" % [card_id, hand_index]
	var button := game.find_child(button_name, true, false) as Button
	if !_require(button != null, "demo card button should exist: " + button_name):
		return false
	return _require(
		game.queue_card_play(hand_index, button),
		"demo card should enter the animation queue: " + card_id
	)


func _queue_tutorial_card(card_id: String) -> bool:
	var hand_index := -1
	for index in range(game.hand.size()):
		if str((game.hand[index] as Dictionary).get("id", "")) == card_id:
			hand_index = index
			break
	if !_require(hand_index >= 0, "tutorial card should exist in hand: " + card_id):
		return false
	var button := game.find_child("TutorialRequiredCard", true, false) as Button
	if !_require(button != null, "tutorial required-card button should be visible: " + card_id):
		return false
	return _require(
		game.queue_card_play(hand_index, button),
		"tutorial card should enter the animation queue: " + card_id
	)


func _wait_for_card_queue(timeout_seconds := 8.0) -> bool:
	var frame_limit := maxi(1, int(round(timeout_seconds * FPS)))
	for _frame_index in range(frame_limit):
		var queue_state := game.card_action_queue_snapshot() as Dictionary
		if int(queue_state.get("pending", 0)) == 0:
			return true
		await process_frame
	return _require(false, "demo card animation queue should drain in %s: %s" % [recording_section, JSON.stringify(game.card_action_queue_snapshot())])


func _hold(seconds: float) -> void:
	var frame_count := maxi(1, int(round(seconds * FPS)))
	for _frame_index in range(frame_count):
		await process_frame


func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	failed = true
	push_error(message)
	return false


func _finish() -> void:
	if game != null:
		game._delete_run_save()
		game.queue_free()
	await process_frame
	for path in [DEMO_SETTINGS_PATH, DEMO_TUTORIAL_PATH, DEMO_CODEX_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit(1 if failed else 0)
