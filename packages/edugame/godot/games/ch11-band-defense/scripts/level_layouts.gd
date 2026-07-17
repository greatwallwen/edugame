extends RefCounted

const LEVEL_ONE_BACKGROUND := "res://assets/backgrounds/band-defense-map-level1-watch-debug-map-layer.png"
const LEVEL_ONE_HUD_BACKGROUND := "res://assets/backgrounds/band-defense-hud-level1-watch-debug-layer.png"
const LEVEL_TWO_BACKGROUND := "res://assets/backgrounds/band-defense-map-level2-watch-debug-map-layer.png"
const LEVEL_THREE_BACKGROUND := "res://assets/backgrounds/band-defense-map-level3-watch-debug-map-layer.png"


static func layout_for_level(level_number: int) -> Dictionary:
	if level_number == 3:
		return {
			"background": LEVEL_THREE_BACKGROUND,
			"hudBackground": LEVEL_ONE_HUD_BACKGROUND,
			"pathLayer": {
				"visible": true,
				"color": Color(0.18, 0.96, 1.0, 0.95),
				"width": 11.0,
				"coreCount": 3,
				"coreWidth": 2.4,
				"coreSpacing": 4.5,
				"connectorGlowWidth": 4.2,
				"cornerRadius": 26.0,
				"cornerSamples": 6,
				"glowWidth": 18.0,
				"glowAlpha": 0.22,
				"arrowSpacing": 92.0,
				"startPort": Vector2(68, 350),
				"endPort": Vector2(880, 350)
			},
			"path": [
				Vector2(68, 350),
				Vector2(124, 350),
				Vector2(178, 342),
				Vector2(256, 292),
				Vector2(256, 470),
				Vector2(454, 470),
				Vector2(454, 350),
				Vector2(506, 350),
				Vector2(578, 270),
				Vector2(656, 270),
				Vector2(712, 342),
				Vector2(712, 410),
				Vector2(792, 410),
				Vector2(838, 350),
				Vector2(880, 350)
			],
			"towerSlots": [
				{"pos": Vector2(212, 227), "tower": null},
				{"pos": Vector2(362, 398), "tower": null},
				{"pos": Vector2(476, 240), "tower": null},
				{"pos": Vector2(562, 432), "tower": null},
				{"pos": Vector2(644, 212), "tower": null},
				{"pos": Vector2(772, 288), "tower": null},
				{"pos": Vector2(826, 472), "tower": null}
			]
		}
	if level_number == 2:
		return {
			"background": LEVEL_TWO_BACKGROUND,
			"hudBackground": LEVEL_ONE_HUD_BACKGROUND,
			"pathLayer": {
				"visible": true,
				"color": Color(0.18, 0.96, 1.0, 0.95),
				"width": 11.0,
				"coreCount": 3,
				"coreWidth": 2.4,
				"coreSpacing": 4.5,
				"connectorGlowWidth": 4.2,
				"cornerRadius": 26.0,
				"cornerSamples": 6,
				"glowWidth": 18.0,
				"glowAlpha": 0.22,
				"arrowSpacing": 92.0,
				"startPort": Vector2(68, 334),
				"endPort": Vector2(880, 347)
			},
			"path": [
				Vector2(68, 334),
				Vector2(132, 334),
				Vector2(190, 332),
				Vector2(262, 278),
				Vector2(250, 440),
				Vector2(410, 440),
				Vector2(410, 278),
				Vector2(434, 210),
				Vector2(552, 210),
				Vector2(622, 286),
				Vector2(622, 372),
				Vector2(690, 426),
				Vector2(816, 426),
				Vector2(840, 347),
				Vector2(880, 347)
			],
			"towerSlots": [
				{"pos": Vector2(214, 207), "tower": null},
				{"pos": Vector2(476, 142), "tower": null},
				{"pos": Vector2(332, 354), "tower": null},
				{"pos": Vector2(550, 405), "tower": null},
				{"pos": Vector2(762, 257), "tower": null},
				{"pos": Vector2(806, 487), "tower": null}
			]
		}
	return {
		"background": LEVEL_ONE_BACKGROUND,
		"hudBackground": LEVEL_ONE_HUD_BACKGROUND,
		"pathLayer": {
			"visible": true,
			"color": Color(0.18, 0.96, 1.0, 0.95),
			"width": 11.0,
			"coreCount": 3,
			"coreWidth": 2.4,
			"coreSpacing": 4.5,
			"connectorGlowWidth": 4.2,
			"cornerRadius": 26.0,
			"cornerSamples": 6,
			"glowWidth": 18.0,
			"glowAlpha": 0.22,
			"arrowSpacing": 92.0,
			"startPort": Vector2(68, 321),
			"endPort": Vector2(878, 350)
		},
		"path": [
			Vector2(68, 321),
			Vector2(126, 321),
			Vector2(185, 260),
			Vector2(340, 260),
			Vector2(520, 260),
			Vector2(639, 322),
			Vector2(639, 385),
			Vector2(695, 440),
			Vector2(734, 440),
			Vector2(815, 350),
			Vector2(878, 350)
		],
		"towerSlots": [
			{"pos": Vector2(214, 207), "tower": null},
			{"pos": Vector2(470, 207), "tower": null},
			{"pos": Vector2(550, 405), "tower": null},
			{"pos": Vector2(762, 257), "tower": null}
		]
	}


static func intro_text_for_level(level_number: int) -> String:
	if level_number == 3:
		return "第 3 关：综合验收数据链路"
	if level_number == 2:
		return "第 2 关：手环夜跑数据异常"
	return "守住 IMU、计步、PPG、OLED 与低功耗链路"
