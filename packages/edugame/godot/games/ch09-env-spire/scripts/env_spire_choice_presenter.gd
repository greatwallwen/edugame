extends RefCounted


static func columns_for(scene_kind: String) -> int:
	return 3 if scene_kind == "component" else 2


static func card_mode_for(scene_kind: String) -> String:
	return "choice"


static func bench_status(stability: int, max_stability: int, deck_size: int, opening_energy_penalty: int = 0, reroute_locked: bool = false) -> String:
	var pending_text := ""
	if opening_energy_penalty < 0:
		pending_text += "  ·  下一场初始能量 %d" % opening_energy_penalty
	if reroute_locked:
		pending_text += "  ·  下一场首回合禁用重排"
	return "工程维护台  ·  稳定度 %d / %d  ·  牌组 %d%s" % [
		stability,
		max_stability,
		deck_size,
		pending_text
	]
