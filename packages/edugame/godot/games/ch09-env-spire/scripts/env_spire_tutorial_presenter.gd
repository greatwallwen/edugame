extends RefCounted


static func briefing_steps() -> Array:
	return [
		{"number": "01", "title": "读取意图", "detail": "确认伤害与故障动作", "accent": Color("#b75a3a")},
		{"number": "02", "title": "建立防护", "detail": "打出指定防御牌", "accent": Color("#517943")},
		{"number": "03", "title": "完成数据链", "detail": "采集 → 转换 → 输出", "accent": Color("#2f7f8d")},
		{"number": "04", "title": "进入正式流程", "detail": "构筑卡组并完成验收", "accent": Color("#725c91")}
	]


static func coach_text(step: int) -> String:
	return {
		1: "点击“连接训练设备”进入实操；随后按高亮目标逐步操作。",
		2: "点击敌人上方的意图徽章，确认本回合影响。",
		3: "使用滑动平均滤波，建立防护。",
		4: "防护已建立。结束回合，观察它抵消漂移。",
		5: "使用 MQ-2 采样，获取烟雾原始数据。",
		6: "使用 ADC 转换，将原始数据变为可信数据。",
		7: "使用 LED 报警，将可信烟雾数据输出为行动。",
		8: "训练完成。"
	}.get(step, "按高亮目标完成当前训练操作。")


static func expected_card_id(step: int) -> String:
	return {
		3: "sliding_average",
		5: "mq2_sample",
		6: "adc_convert",
		7: "led_alarm"
	}.get(step, "")
