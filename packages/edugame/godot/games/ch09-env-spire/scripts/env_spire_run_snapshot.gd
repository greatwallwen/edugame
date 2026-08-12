extends RefCounted


static func build(host) -> Dictionary:
	return {
		"state": host.state, "runMapId": host.run_map_id, "runMap": host.run_map, "runSeed": host.run_seed,
		"rngState": host.rng.state, "elapsedMs": maxi(Time.get_ticks_msec() - host.started_at, 0),
		"stability": host.stability, "maxStability": host.max_stability,
		"pendingServiceEnergyPenalty": host.pending_service_energy_penalty,
		"pendingServiceRerouteLock": host.pending_service_reroute_lock,
		"currentLayer": host.current_layer, "visitedNodes": host.visited_nodes,
		"checkpointsPassed": host.checkpoints_passed, "checkpointResults": host.checkpoint_results,
		"bossPhase": host.boss_phase, "bossGateIds": host.boss_gate_ids, "bossReviewUsed": host.boss_review_used,
		"preBossStability": host.pre_boss_stability, "deck": host.deck, "drawPile": host.draw_pile,
		"discardPile": host.discard_pile, "exhaustPile": host.exhaust_pile, "hand": host.hand,
		"retainedCards": host.retained_cards, "relics": host.relics, "powers": host.powers,
		"componentTracking": host.component_tracking, "processingPoints": host.processing_points,
		"nextTurnEnergy": host.next_turn_energy, "block": host.block, "rawData": host.raw_data,
		"trustedData": host.trusted_data, "retainData": host.retain_data, "diagnosis": host.diagnosis,
		"alarmMarkers": host.alarm_markers, "chainCount": host.chain_count, "lastStage": host.last_stage,
		"chainRewardsClaimed": host.chain_rewards_claimed, "cardsPlayedThisTurn": host.cards_played_this_turn,
		"rerouteAvailable": host.reroute_available, "rerouteMode": host.reroute_mode,
		"pendingCardSelection": host.pending_card_selection, "turnEffectUses": host.turn_effect_uses,
		"turnNumber": host.turn_number, "turnCardTypes": host.turn_card_types, "turnSources": host.turn_sources,
		"sourceCoverage": host.source_coverage, "outputTypes": host.output_types,
		"trustedSourcesSeen": host.trusted_sources_seen, "filtersPlayed": host.filters_played,
		"encounterEvidenceTags": host.encounter_evidence_tags, "phaseSourceCoverage": host.phase_source_coverage,
		"phaseTrustedSources": host.phase_trusted_sources, "phaseFiltersPlayed": host.phase_filters_played,
		"phaseCalibrationsPlayed": host.phase_calibrations_played, "phaseOutputTypes": host.phase_output_types,
		"phaseOutputUses": host.phase_output_uses, "persistentOutputTypes": host.persistent_output_types,
		"repairPenalty": host.repair_penalty, "i2cCostPenalty": host.i2c_cost_penalty,
		"pendingI2cCount": host.pending_i2c_count, "faultRuleState": host.fault_rule_state,
		"currentNode": host.current_node, "currentEncounter": host.current_encounter,
		"currentIntents": host.current_intents, "intentIndex": host.intent_index,
		"repairTarget": host.repair_target, "repairProgress": host.repair_progress,
		"currentEvent": host.current_event, "eventAnswerLocked": host.event_answer_locked,
		"eventResult": host.event_result, "revealedNodes": host.revealed_nodes,
		"eventSelectedAnswer": host.event_selected_answer, "eventOrderingAnswer": host.event_ordering_answer,
		"eventHistory": host.event_history, "rewardChoices": host.reward_choices,
		"componentChoices": host.component_choices,
		"messageLog": host.message_log, "debugReports": host.debug_reports, "knowledgeStats": host.knowledge_stats
	}


static func restore(host, data: Dictionary, default_map_id: String, default_max_stability: int, map_state: int) -> void:
	host._reset_card_action_queue()
	host.state = int(data.get("state", map_state))
	host.run_map_id = str(data.get("runMapId", default_map_id))
	host.run_map = (data.get("runMap", {}) as Dictionary).duplicate(true)
	host.run_seed = int(data.get("runSeed", 901))
	host.rng.state = int(data.get("rngState", host.run_seed))
	host.started_at = Time.get_ticks_msec() - int(data.get("elapsedMs", 0))
	host.stability = int(data.get("stability", default_max_stability))
	host.max_stability = int(data.get("maxStability", default_max_stability))
	host.pending_service_energy_penalty = int(data.get("pendingServiceEnergyPenalty", 0))
	host.pending_service_reroute_lock = bool(data.get("pendingServiceRerouteLock", false))
	host.current_layer = int(data.get("currentLayer", 0))
	host.checkpoints_passed = int(data.get("checkpointsPassed", 0))
	host.boss_phase = int(data.get("bossPhase", 0))
	host.boss_review_used = bool(data.get("bossReviewUsed", false))
	host.pre_boss_stability = int(data.get("preBossStability", default_max_stability))
	host.processing_points = int(data.get("processingPoints", 3))
	host.next_turn_energy = int(data.get("nextTurnEnergy", 0))
	host.block = int(data.get("block", 0))
	host.retain_data = bool(data.get("retainData", false))
	host.diagnosis = int(data.get("diagnosis", 0))
	host.alarm_markers = int(data.get("alarmMarkers", 0))
	host.chain_count = int(data.get("chainCount", 0))
	host.last_stage = str(data.get("lastStage", ""))
	host.cards_played_this_turn = int(data.get("cardsPlayedThisTurn", 0))
	host.reroute_available = bool(data.get("rerouteAvailable", false))
	host.reroute_mode = bool(data.get("rerouteMode", false))
	host.turn_number = int(data.get("turnNumber", 0))
	host.filters_played = int(data.get("filtersPlayed", 0))
	host.phase_filters_played = int(data.get("phaseFiltersPlayed", 0))
	host.phase_calibrations_played = int(data.get("phaseCalibrationsPlayed", 0))
	host.repair_penalty = int(data.get("repairPenalty", 0))
	host.i2c_cost_penalty = int(data.get("i2cCostPenalty", 0))
	host.pending_i2c_count = int(data.get("pendingI2cCount", 0))
	host.intent_index = int(data.get("intentIndex", 0))
	host.repair_target = int(data.get("repairTarget", 0))
	host.repair_progress = int(data.get("repairProgress", 0))
	host.event_answer_locked = bool(data.get("eventAnswerLocked", false))
	for pair in [
		["visitedNodes", host.visited_nodes], ["checkpointResults", host.checkpoint_results], ["deck", host.deck],
		["drawPile", host.draw_pile], ["discardPile", host.discard_pile], ["exhaustPile", host.exhaust_pile],
		["hand", host.hand], ["retainedCards", host.retained_cards], ["relics", host.relics],
		["currentIntents", host.current_intents], ["rewardChoices", host.reward_choices],
		["componentChoices", host.component_choices], ["messageLog", host.message_log],
		["debugReports", host.debug_reports]
	]:
		(pair[1] as Array).assign((data.get(str(pair[0]), []) as Array).duplicate(true))
	host.boss_gate_ids.assign(data.get("bossGateIds", []))
	host.event_ordering_answer.assign(data.get("eventOrderingAnswer", []))
	host.revealed_nodes.assign(data.get("revealedNodes", []))
	host.event_history.assign(data.get("eventHistory", []))
	for pair in [
		["powers", host.powers], ["componentTracking", host.component_tracking], ["rawData", host.raw_data],
		["trustedData", host.trusted_data], ["chainRewardsClaimed", host.chain_rewards_claimed],
		["pendingCardSelection", host.pending_card_selection], ["turnEffectUses", host.turn_effect_uses],
		["turnCardTypes", host.turn_card_types], ["turnSources", host.turn_sources],
		["sourceCoverage", host.source_coverage], ["outputTypes", host.output_types],
		["trustedSourcesSeen", host.trusted_sources_seen], ["encounterEvidenceTags", host.encounter_evidence_tags],
		["phaseSourceCoverage", host.phase_source_coverage], ["phaseTrustedSources", host.phase_trusted_sources],
		["phaseOutputTypes", host.phase_output_types], ["phaseOutputUses", host.phase_output_uses],
		["persistentOutputTypes", host.persistent_output_types], ["faultRuleState", host.fault_rule_state],
		["currentNode", host.current_node], ["currentEncounter", host.current_encounter],
		["currentEvent", host.current_event], ["eventResult", host.event_result],
		["knowledgeStats", host.knowledge_stats]
	]:
		(pair[1] as Dictionary).clear()
		(pair[1] as Dictionary).merge((data.get(str(pair[0]), {}) as Dictionary).duplicate(true), true)
	host.event_selected_answer = data.get("eventSelectedAnswer")
	host.completed = false
	host.victory = false
	host.score = 0
	host.last_save_hash = JSON.stringify(data).hash()
