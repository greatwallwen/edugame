# 实训工作页（build_ch*_worksheet）—— by chapters/worksheets.py
"""
build_worksheet_page + build_ch3/ch4/ch5/ch6/ch7/ch9/ch10/ch11/ch12 worksheets.
"""
# -*- coding: utf-8 -*-
import textwrap, inspect

def _t(bid, md): return {"id": bid, "kind": "text", "markdown": inspect.cleandoc(md)}
def _code(bid, lang, code, fname=None):
    b = {"id": bid, "kind": "code", "language": lang, "code": textwrap.dedent(code)}
    if fname: b["filename"] = fname
    return b
def _fc(bid, prompt, cards):
    return {"id": bid, "kind": "interactive", "spec": {"kind": "flashcard", "prompt": prompt,
            "cards": [{"id": f"fc{i}", "front": f, "back": b} for i, (f, b) in enumerate(cards)]}}
def _match(bid, prompt, pairs):
    return {"id": bid, "kind": "interactive", "spec": {"kind": "matching", "prompt": prompt,
            "pairs": [{"left": l, "right": r} for l, r in pairs]}}
def _table(bid, cap, headers, rows):
    return {"id": bid, "kind": "table", "caption": cap, "headers": headers, "rows": rows}
def _sum(bid, pts, qs):
    return {"id": bid, "kind": "summary", "keyPoints": pts, "reviewQuestions": qs}
def _page(pid, title, blocks):
    return {"id": pid, "title": title, "template": "T-concept", "blocks": blocks}

# ═══════════════════════════════════════════════════════════
# 实训工作页工厂函数（政策范式：工作手册式教材）
# 对应教职成〔2026〕1号：工作手册式教材 + 技术规范卡片
# ═══════════════════════════════════════════════════════════

def build_worksheet_page(pid, task_title, context_md, objectives,
                          materials, steps, knowledge_cards, quiz_items, key_points):
    """
    生成标准化"实训工作页"（工作手册式）

    参数：
      pid            - 页面ID
      task_title     - 工作任务名称（如"任务3.2 LED流水灯控制实训"）
      context_md     - 任务情境描述（1-2行markdown）
      objectives     - 工作目标列表（list of str，对应技能点）
      materials      - 器材/资源清单 [[名称, 型号, 数量, 用途], ...]
      steps          - 工作步骤 [(标题, 描述, 代码/空串), ...]
      knowledge_cards- 知识卡片 [(正面问题, 背面答案), ...]
      quiz_items     - 质量检测题（暂不接 quizzes，直接文字，用fill_blank）
      key_points     - 能力达标关键点 [str, ...]
    """
    blocks = []
    bid = pid  # 块ID前缀

    # ① 任务情境（简短情境化引入）
    blocks.append(_t(f"{bid}-ctx", f"""\
        ## {task_title}

        > 🎯 **工作情境**：{context_md}

        ### 工作目标（技能达成指标）
        完成本次实训后，你能够：
        """ + "\n".join(f"        - {obj}" for obj in objectives)
    ))

    # ② 器材/资源清单（table block）
    if materials:
        blocks.append(_table(f"{bid}-mat", "器材与资源清单",
            ["器材名称", "型号规格", "数量", "用途说明"],
            materials
        ))

    # ③ 工作步骤（experiment block）
    exp_steps = []
    for i, (s_title, s_desc, s_code) in enumerate(steps):
        exp_steps.append({
            "order": i + 1,
            "title": s_title,
            "description": s_desc,
            "code": s_code,
            "checkpoint": (i == len(steps) - 1),  # 最后一步设为检查点
        })
    blocks.append({
        "id": f"{bid}-exp",
        "kind": "experiment",
        "title": "工作步骤",
        "steps": exp_steps,
        "expectedResult": "按步骤操作完成后，实验现象与工作目标一致",
        "troubleshooting": [
            "编译失败：检查头文件包含、函数名拼写、分号是否遗漏",
            "硬件无响应：检查接线、确认GPIO时钟已使能、用万用表测量关键点电压",
        ]
    })

    # ④ 知识卡片（技术规范卡片 — 按需查阅）
    if knowledge_cards:
        blocks.append(_fc(f"{bid}-kc", "📚 知识卡片（遇到问题时查阅）", knowledge_cards))

    # ⑤ 质量检测（自测）
    if quiz_items:
        # 用 flashcard 模拟质量检测（问题→标准答案）
        blocks.append(_fc(f"{bid}-qz", "✅ 质量检测（自测达标）", quiz_items))

    # ⑥ 能力达标确认（summary block）
    blocks.append(_sum(f"{bid}-sum", key_points,
        ["你能独立完成本任务吗？", "哪个步骤最容易出错？如何避免？"]
    ))

    return _page(pid, task_title, blocks)


# ═══════════════════════════════════════════════════════════
# 基于工作页范式的示例：第3章 LED实训工作页（标准格式）
# ═══════════════════════════════════════════════════════════

def build_ch3_worksheet():
    """第3章 GPIO实训工作页（工作手册式范式示例）"""

    ws = build_worksheet_page(
        pid="p3-ws-led",
        task_title="任务3.2 LED流水灯控制实训",
        context_md="某智能设备指示灯板需要实现流水灯效果，你作为嵌入式开发工程师，"
                   "需要用STM32F103完成3个LED的顺序点亮控制。",
        objectives=[
            "能正确配置GPIO引脚为推挽输出模式",
            "能调用 HAL_GPIO_WritePin/TogglePin 控制LED电平",
            "能编写流水灯循环逻辑并烧录验证",
            "能用示波器/万用表测量LED引脚电平变化",
        ],
        materials=[
            ["STM32F103C8T6开发板", "Blue Pill", "1块", "主控制器"],
            ["LED指示灯", "红色3mm", "3个", "显示输出效果"],
            ["限流电阻", "330Ω ¼W", "3个", "保护LED防烧毁"],
            ["跳线", "杜邦线母对母", "若干", "连接开发板与LED"],
            ["USB转TTL", "CH340G", "1个", "烧录程序"],
            ["STM32CubeIDE", "1.14+", "软件", "IDE + 编译器"],
        ],
        steps=[
            ("硬件连接", "将LED正极（长脚）通过330Ω电阻连接到PA5/PA6/PA7；LED负极接GND。"
                        "确认限流电阻已串联，防止烧毁LED（正向电流≤20mA）。",
             ""),
            ("CubeMX配置", "新建STM32F103C8T6工程 → Pinout视图 → 点击PA5/PA6/PA7 → 选择GPIO_Output "
                           "→ GPIO标签页 → 模式：Output Push Pull，速度：Low → 生成代码。",
             "// CubeMX自动生成 MX_GPIO_Init()\n// PA5/PA6/PA7 已配置为推挽输出"),
            ("编写流水灯代码", "在 main.c 的 USER CODE BEGIN WHILE 区域添加流水灯逻辑：",
             "uint16_t leds[] = {GPIO_PIN_5, GPIO_PIN_6, GPIO_PIN_7};\nwhile (1) {\n"
             "    for (int i = 0; i < 3; i++) {\n"
             "        // 全灭后点亮第i个\n"
             "        HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5|GPIO_PIN_6|GPIO_PIN_7, GPIO_PIN_RESET);\n"
             "        HAL_GPIO_WritePin(GPIOA, leds[i], GPIO_PIN_SET);\n"
             "        HAL_Delay(500);  // 500ms间隔\n"
             "    }\n}"),
            ("编译与烧录", "点击菜单 Project → Build All（快捷键Ctrl+B）→ 无错误 → "
                          "ST-Link连接（SWCLK/SWDIO/3.3V/GND）→ Run → Program。",
             ""),
            ("效果验证（关键检查点）", "观察3个LED依次点亮（PA5→PA6→PA7→PA5...）。"
                                       "用万用表测量PA5引脚：亮时约3.3V，灭时约0V。",
             ""),
        ],
        knowledge_cards=[
            ("GPIO推挽输出与开漏输出的区别？",
             "推挽：能输出高(3.3V)也能输出低(0V)，驱动能力强，LED驱动用此模式\n"
             "开漏：只能输出低，高电平靠外部上拉，常用于I2C/多机共线场景"),
            ("LED限流电阻如何计算？",
             "R = (Vcc - Vf) / If\n其中Vcc=3.3V，红色LED正向压降Vf≈2V，正向电流If=10mA\n"
             "R = (3.3-2.0)/0.01 = 130Ω，选330Ω留有余量，亮度够用"),
            ("HAL_Delay(500) 精度如何？",
             "基于SysTick定时器，1ms精度。注意：在中断中调用HAL_Delay会死锁"
             "（除非SysTick优先级为最高0），建议主循环中使用"),
            ("GPIO时钟为什么必须使能？",
             "__HAL_RCC_GPIOx_CLK_ENABLE() 必须在GPIO初始化前调用，"
             "否则GPIO寄存器无法访问（APB总线上的外设默认关闭以节能）"),
        ],
        quiz_items=[
            ("PA5引脚作为LED输出，电流方向是？", "电流从PA5流入限流电阻→LED→GND（灌电流模式）"),
            ("如何修改流水灯间隔为200ms？", "将 HAL_Delay(500) 改为 HAL_Delay(200)"),
            ("流水灯数组 leds[] 如何扩展到4个LED（PA8）？",
             "在数组中添加 GPIO_PIN_8，并确保PA8已在CubeMX中配置为GPIO_Output"),
        ],
        key_points=[
            "GPIO推挽输出模式 + HAL_GPIO_WritePin 控制LED是嵌入式最基础的操作",
            "限流电阻 = (Vcc-Vf)/If，防止LED过流烧毁",
            "CubeMX生成代码后，只能在 USER CODE BEGIN/END 之间写自己的代码",
            "流水灯核心逻辑：全灭→单亮→延时→循环，数组遍历实现",
        ]
    )
    return (ws,)


# ═══════════════════════════════════════════════════════════
# 第4章  定时器 — 实训工作页
# ═══════════════════════════════════════════════════════════

def build_ch4_worksheet():
    ws = build_worksheet_page(
        pid="p4-ws-timer",
        task_title="任务4.2 定时器中断精确计时实训",
        context_md="某生产线需要每500ms自动记录一次传感器数据，"
                   "你需要用STM32F103的TIM3实现精确的周期性中断，"
                   "并在中断回调中切换LED状态以验证定时精度。",
        objectives=[
            "能计算TIM定时器的PSC和ARR参数实现目标周期",
            "能在CubeMX中配置TIM3定时器并使能中断",
            "能在HAL_TIM_PeriodElapsedCallback中编写中断处理逻辑",
            "能用示波器验证定时周期精度（误差<1%）",
        ],
        materials=[
            ["STM32F103C8T6开发板", "Blue Pill", "1块", "主控制器"],
            ["LED指示灯", "任意颜色", "1个", "验证定时中断"],
            ["示波器/逻辑分析仪", "可选", "1台", "测量定时精度"],
            ["STM32CubeIDE", "1.14+", "软件", "配置与编译"],
        ],
        steps=[
            ("计算定时参数", "目标周期500ms，系统时钟72MHz，TIM3挂APB1（72MHz）。\n"
                            "公式：周期 = (PSC+1)×(ARR+1) / TIMclk\n"
                            "选 PSC=7199（÷7200），ARR=4999，周期=7200×5000/72000000=0.5s ✓",
             "// 参数计算验证\n// TIMclk = 72MHz\n// PSC = 7199  → 分频后 72MHz/(7199+1) = 10kHz\n// ARR = 4999  → 10kHz/(4999+1) = 2Hz = 500ms周期"),
            ("CubeMX配置TIM3", "Timers → TIM3 → Clock Source: Internal Clock\n"
                               "Parameter Settings: Prescaler=7199, Counter Period=4999\n"
                               "NVIC Settings: TIM3 global interrupt → Enable\n"
                               "生成代码。",
             "// CubeMX自动生成：MX_TIM3_Init()"),
            ("启动定时器中断", "在 main() 的 USER CODE BEGIN 2 中启动定时器：",
             "/* USER CODE BEGIN 2 */\nHAL_TIM_Base_Start_IT(&htim3);  // 启动TIM3中断模式\n/* USER CODE END 2 */"),
            ("编写中断回调", "在 main.c 或 tim.c 中实现回调函数（每500ms自动调用）：",
             "/* USER CODE BEGIN 4 */\nvoid HAL_TIM_PeriodElapsedCallback(TIM_HandleTypeDef *htim) {\n    if (htim->Instance == TIM3) {\n        HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5);  // 翻转LED\n        // 在此处添加传感器采样、数据记录等逻辑\n    }\n}\n/* USER CODE END 4 */"),
            ("效果验证（关键检查点）", "观察LED每500ms翻转一次（肉眼可见1Hz闪烁）。\n"
                                       "用示波器测量LED引脚：周期应为1000ms（500ms高+500ms低）。",
             ""),
        ],
        knowledge_cards=[
            ("PSC和ARR的关系公式？",
             "定时周期 = (PSC+1) × (ARR+1) / TIMclk\n"
             "APB1定时器TIMclk = 72MHz（即使APB1分频为36MHz，TIM时钟仍×2=72MHz）"),
            ("TIM3和TIM1的区别？",
             "TIM1是高级定时器（APB2，72MHz），有互补输出/死区控制，适合电机控制\n"
             "TIM3是通用定时器（APB1，72MHz），4路PWM捕获，适合一般定时/PWM"),
            ("HAL_TIM_Base_Start vs HAL_TIM_Base_Start_IT的区别？",
             "Start：轮询模式，需要自己检查标志位（耗CPU）\n"
             "Start_IT：中断模式，溢出时自动调用PeriodElapsedCallback（推荐）\n"
             "Start_DMA：DMA模式，适合高频触发"),
            ("定时器中断优先级怎么设置合理？",
             "建议：SysTick=0（最高），普通TIM=2~5，EXTI按键=3\n"
             "注意：比SysTick低的中断里可以调用HAL_Delay；比SysTick高则不能"),
        ],
        quiz_items=[
            ("TIM3 PSC=35999, ARR=1999时，定时周期是多少？",
             "周期 = (35999+1)×(1999+1)/72000000 = 36000×2000/72000000 = 1s"),
            ("如何在中断回调中区分TIM2和TIM3触发的中断？",
             "用 htim->Instance == TIM2 或 htim->Instance == TIM3 判断"),
            ("定时器精度受哪些因素影响？",
             "1.时钟源稳定性（内部RC约1%误差，外部晶振<50ppm）\n"
             "2.中断延迟（高优先级中断会延迟低优先级定时回调）"),
        ],
        key_points=[
            "定时周期 = (PSC+1)×(ARR+1)/TIMclk，PSC用于粗分频，ARR控制溢出点",
            "HAL_TIM_Base_Start_IT 启动后必须实现 HAL_TIM_PeriodElapsedCallback",
            "用 htim->Instance == TIMx 区分多个定时器的回调",
            "APB1上的定时器实际时钟 = 72MHz（非36MHz），这是常见的计算错误",
        ]
    )
    return (ws,)


# ═══════════════════════════════════════════════════════════
# 第5章  PWM — 实训工作页
# ═══════════════════════════════════════════════════════════

def build_ch5_worksheet():
    ws = build_worksheet_page(
        pid="p5-ws-pwm",
        task_title="任务5.2 PWM呼吸灯与舵机控制实训",
        context_md="智能台灯需要平滑调光功能，同时机器人关节需要精确角度控制。"
                   "你需要用TIM2-CH1输出PWM驱动LED呼吸灯，并用TIM3-CH2控制SG90舵机转到指定角度。",
        objectives=[
            "能理解PWM占空比与输出电压/亮度的关系",
            "能配置TIM2输出PWM并通过修改CCR实现亮度调节",
            "能用20ms周期PWM（500~2500μs脉宽）控制SG90舵机角度",
            "能编写呼吸灯渐变算法（0%→100%→0%循环）",
        ],
        materials=[
            ["STM32F103C8T6开发板", "Blue Pill", "1块", "主控制器"],
            ["LED（含限流电阻）", "红色3mm+330Ω", "1套", "PWM调光目标"],
            ["SG90舵机", "标准9g舵机", "1个", "角度控制演示"],
            ["示波器/逻辑分析仪", "可选", "1台", "测量PWM波形"],
        ],
        steps=[
            ("配置TIM2-CH1输出PWM（LED呼吸灯）",
             "CubeMX: TIM2 → Channel1: PWM Generation CH1\n"
             "PSC=71（÷72，得1MHz基准），ARR=999（1kHz PWM频率）\n"
             "Pulse（CCR1）=0（初始占空比0%）",
             "// CCR控制占空比：duty% = CCR/(ARR+1) * 100\n"
             "// CCR=0 → 0%, CCR=500 → 50%, CCR=1000 → 100%"),
            ("启动PWM并实现呼吸灯",
             "在USER CODE BEGIN 2启动PWM，在while循环中渐变CCR：",
             "HAL_TIM_PWM_Start(&htim2, TIM_CHANNEL_1);  // 启动PWM输出\n\n"
             "// while(1)中的呼吸灯逻辑\nfor (int duty = 0; duty <= 1000; duty += 5) {\n"
             "    __HAL_TIM_SET_COMPARE(&htim2, TIM_CHANNEL_1, duty);\n"
             "    HAL_Delay(5);  // 每步5ms，完整渐亮约1秒\n}\n"
             "for (int duty = 1000; duty >= 0; duty -= 5) {\n"
             "    __HAL_TIM_SET_COMPARE(&htim2, TIM_CHANNEL_1, duty);\n"
             "    HAL_Delay(5);  // 完整渐暗约1秒\n}"),
            ("配置TIM3-CH2控制SG90舵机",
             "SG90时序：周期20ms（50Hz），脉宽500μs=0°，1500μs=90°，2500μs=180°\n"
             "PSC=71，ARR=19999（20ms周期），CCR范围500~2500",
             "// 角度到CCR的换算\nuint16_t angle_to_ccr(uint8_t angle) {\n"
             "    // 0°→500, 180°→2500\n"
             "    return 500 + (uint16_t)(angle * 2000 / 180);\n}\n"
             "HAL_TIM_PWM_Start(&htim3, TIM_CHANNEL_2);\n"
             "__HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_2, angle_to_ccr(90)); // 转到90°"),
            ("舵机扫描验证（关键检查点）",
             "让舵机从0°→90°→180°→90°→0°循环扫描，观察舵机实际角度与程序设定一致。",
             "for (int angle = 0; angle <= 180; angle += 10) {\n"
             "    __HAL_TIM_SET_COMPARE(&htim3, TIM_CHANNEL_2, angle_to_ccr(angle));\n"
             "    HAL_Delay(100);\n}"),
        ],
        knowledge_cards=[
            ("PWM占空比如何计算？",
             "占空比(%) = CCR / (ARR+1) × 100\n"
             "例：ARR=999, CCR=300 → 占空比=300/1000×100=30%\n"
             "输出平均电压 = 3.3V × 30% = 0.99V（LED亮度约30%）"),
            ("SG90舵机为什么需要20ms周期？",
             "SG90使用位置型PWM控制，需要50Hz（20ms）的刷新率。\n"
             "脉宽决定角度：500μs=0°, 1500μs=90°, 2500μs=180°\n"
             "频率太高或太低会导致舵机抖动或不响应"),
            ("__HAL_TIM_SET_COMPARE 与重新初始化的区别？",
             "重新初始化（HAL_TIM_PWM_Init）会重置所有参数，会产生跳变\n"
             "__HAL_TIM_SET_COMPARE 只修改CCR寄存器，平滑无跳变，实时性好\n"
             "运行中调节占空比必须用后者"),
        ],
        quiz_items=[
            ("TIM2 ARR=999，如何设置CCR让LED亮度为75%？",
             "CCR = 999 × 75% = 749（实际用750即可）"),
            ("SG90转到135°时，CCR应设为多少（ARR=19999）？",
             "CCR = 500 + 135×2000/180 = 500 + 1500 = 2000"),
        ],
        key_points=[
            "PWM频率 = TIMclk/(PSC+1)/(ARR+1)，占空比=CCR/(ARR+1)",
            "运行中用 __HAL_TIM_SET_COMPARE 修改CCR，不要重新Init",
            "SG90：20ms周期，500~2500μs脉宽对应0~180°",
            "呼吸灯核心：用循环递增/递减CCR + HAL_Delay实现渐变",
        ]
    )
    return (ws,)


# ═══════════════════════════════════════════════════════════
# 第6章  UART — 实训工作页
# ═══════════════════════════════════════════════════════════

def build_ch6_worksheet():
    ws = build_worksheet_page(
        pid="p6-ws-uart",
        task_title="任务6.2 串口双向通信与命令解析实训",
        context_md="上位机（PC）需要通过串口向STM32发送控制命令（如'LED_ON'/'LED_OFF'），"
                   "STM32解析命令后执行并回传状态信息。"
                   "你需要实现中断接收+命令解析+应答的完整通信流程。",
        objectives=[
            "能配置UART1为115200-8N1模式并重定向printf",
            "能用中断模式接收串口数据（逐字节接收到缓冲区）",
            "能设计并实现简单的文本命令协议（以\\n结束）",
            "能用串口调试助手验证双向通信效果",
        ],
        materials=[
            ["STM32F103C8T6开发板", "Blue Pill", "1块", "主控制器"],
            ["USB转TTL模块", "CH340G/CP2102", "1个", "连接PC串口"],
            ["LED+限流电阻", "任意颜色+330Ω", "1套", "命令控制目标"],
            ["串口调试助手", "SSCOM/SecureCRT", "软件", "PC端收发验证"],
        ],
        steps=[
            ("CubeMX配置UART1",
             "Connectivity → USART1 → Mode: Asynchronous\n"
             "Baud Rate: 115200, Word Length: 8Bits, Parity: None, Stop Bits: 1\n"
             "NVIC: USART1 global interrupt → Enable",
             "// CubeMX生成 MX_USART1_UART_Init() 和 huart1 句柄"),
            ("重定向printf到串口",
             "在main.c的USER CODE BEGIN 0区域添加：",
             "/* USER CODE BEGIN 0 */\n#include <stdio.h>\n\n"
             "int _write(int file, char *ptr, int len) {\n"
             "    HAL_UART_Transmit(&huart1, (uint8_t*)ptr, len, HAL_MAX_DELAY);\n"
             "    return len;\n}\n/* USER CODE END 0 */\n\n"
             "// 之后即可使用 printf()\nprintf(\"STM32 Ready!\\r\\n\");"),
            ("实现中断接收缓冲区",
             "定义全局缓冲区和回调函数：",
             "/* USER CODE BEGIN 0 */\nuint8_t rx_tmp;           // 单字节接收缓冲\n"
             "char    rx_buf[64];       // 命令行缓冲\nuint8_t rx_idx = 0;       // 当前索引\n"
             "uint8_t cmd_ready = 0;   // 命令就绪标志\n/* USER CODE END 0 */\n\n"
             "// USER CODE BEGIN 2\nHAL_UART_Receive_IT(&huart1, &rx_tmp, 1);  // 启动接收\n// USER CODE END 2"),
            ("命令解析回调函数",
             "实现接收回调，积累字符直到收到'\\n'：",
             "void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart) {\n"
             "    if (huart->Instance == USART1) {\n"
             "        if (rx_tmp == '\\n' || rx_idx >= 63) {\n"
             "            rx_buf[rx_idx] = '\\0';\n"
             "            cmd_ready = 1;\n"
             "            rx_idx = 0;\n"
             "        } else if (rx_tmp != '\\r') {\n"
             "            rx_buf[rx_idx++] = rx_tmp;\n"
             "        }\n"
             "        HAL_UART_Receive_IT(&huart1, &rx_tmp, 1);  // 重启接收\n"
             "    }\n}\n\n"
             "// while(1)中解析命令\nif (cmd_ready) {\n"
             "    cmd_ready = 0;\n"
             "    if (strcmp(rx_buf, \"LED_ON\") == 0) {\n"
             "        HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_SET);\n"
             "        printf(\"OK: LED ON\\r\\n\");\n"
             "    } else if (strcmp(rx_buf, \"LED_OFF\") == 0) {\n"
             "        HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_RESET);\n"
             "        printf(\"OK: LED OFF\\r\\n\");\n"
             "    } else {\n"
             "        printf(\"ERR: Unknown cmd [%s]\\r\\n\", rx_buf);\n"
             "    }\n}"),
            ("串口助手验证（关键检查点）",
             "打开串口助手，波特率115200，发送'LED_ON\\n'应收到'OK: LED ON'\n"
             "发送'LED_OFF\\n'应收到'OK: LED OFF'\n"
             "发送'HELLO\\n'应收到'ERR: Unknown cmd [HELLO]'",
             ""),
        ],
        knowledge_cards=[
            ("为什么接收回调中要重新调用Receive_IT？",
             "HAL_UART_Receive_IT是一次性的，接收到指定字节后自动停止。\n"
             "必须在回调末尾重新调用，才能持续接收下一个字节。\n"
             "忘记重新调用是串口中断接收最常见的Bug。"),
            ("_write函数重写 vs __io_putchar重写，哪个更通用？",
             "_write(GCC/newlib标准)：适用于GCC编译器，HAL工程推荐\n"
             "__io_putchar(Keil MDK专用)：仅Keil环境有效\n"
             "STM32CubeIDE使用GCC，必须用_write方式"),
            ("如何防止命令缓冲区溢出？",
             "设置最大长度(64字节)，当rx_idx>=63时强制截断并置cmd_ready\n"
             "或者在接收到非法字符时清空缓冲区\n"
             "生产代码还需考虑临界区保护（中断与主循环共享数据）"),
        ],
        quiz_items=[
            ("为什么串口格式是'8N1'？各字母代表什么？",
             "8=8位数据位, N=None无奇偶校验, 1=1位停止位\n这是最常用的UART配置，双方必须设置相同"),
            ("在回调函数中调用printf会有什么问题？",
             "printf内部调用_write发送UART，是阻塞操作，在中断中调用会使中断执行时间过长，"
             "影响其他中断响应。应设标志位，在主循环中调用printf。"),
        ],
        key_points=[
            "中断接收的关键：回调末尾必须重新调用 HAL_UART_Receive_IT",
            "GCC环境printf重定向用 _write 函数，不是 __io_putchar",
            "命令解析模式：逐字节缓冲→收到\\n→处理→清空缓冲区",
            "中断回调中只设标志位，耗时操作放主循环（避免中断栈溢出）",
        ]
    )
    return (ws,)


# ═══════════════════════════════════════════════════════════
# 第7章  ADC — 实训工作页
# ═══════════════════════════════════════════════════════════

def build_ch7_worksheet():
    ws = build_worksheet_page(
        pid="p7-ws-adc",
        task_title="任务7.2 ADC光照强度采样与量化实训",
        context_md="智能路灯需要根据环境光强自动调节亮度。你需要用STM32F103的ADC1读取"
                   "光敏电阻（LDR）的模拟电压，将其转换为光照强度百分比，"
                   "并通过串口实时上报，同时根据光强驱动LED亮度（PWM）。",
        objectives=[
            "能配置ADC1单通道轮询采样",
            "能将12位ADC原始值转换为电压值和物理量",
            "能用DMA方式实现多通道连续采样",
            "能联动PWM输出实现光控调光效果",
        ],
        materials=[
            ["STM32F103C8T6开发板", "Blue Pill", "1块", "主控制器"],
            ["光敏电阻LDR", "GL5528", "1个", "光照传感器"],
            ["下拉电阻", "10kΩ", "1个", "分压电路"],
            ["LED+限流电阻", "白色+330Ω", "1套", "光控调光"],
        ],
        steps=[
            ("搭建LDR分压电路",
             "LDR与10kΩ电阻串联分压：3.3V → LDR → PA0（ADC输入）→ 10kΩ → GND\n"
             "亮光时LDR阻值小（约1kΩ），PA0电压约0.3V（偏低）\n"
             "暗时LDR阻值大（约100kΩ），PA0电压约3.0V（偏高）",
             "// 分压公式：V_PA0 = 3.3V × R_down / (R_LDR + R_down)\n"
             "// R_down = 10kΩ（固定），R_LDR随光强变化"),
            ("CubeMX配置ADC1",
             "Analog → ADC1 → IN0 → Single-ended\n"
             "Mode: Independent mode\n"
             "Continuous Conversion: Disabled（单次）\n"
             "Sampling Time: 239.5 Cycles（提高精度，适合高阻传感器）",
             "// CubeMX生成 MX_ADC1_Init()"),
            ("编写ADC采样与换算代码",
             "在while(1)中轮询采样，每100ms读一次：",
             "uint32_t adc_raw;\nfloat voltage, lux_pct;\n\n"
             "HAL_ADC_Start(&hadc1);\n"
             "if (HAL_ADC_PollForConversion(&hadc1, 10) == HAL_OK) {\n"
             "    adc_raw = HAL_ADC_GetValue(&hadc1);\n"
             "    voltage = adc_raw * 3.3f / 4095.0f;  // 12bit→电压\n"
             "    // 亮光→低电压，换算光照百分比（反相）\n"
             "    lux_pct = (1.0f - voltage / 3.3f) * 100.0f;\n"
             "    printf(\"ADC:%lu V:%.2f Lux:%.1f%%\\r\\n\", adc_raw, voltage, lux_pct);\n"
             "}\nHAL_ADC_Stop(&hadc1);\nHAL_Delay(100);"),
            ("联动PWM调光（关键检查点）",
             "将光照百分比映射到PWM占空比，实现自动调光：",
             "// lux_pct越高（越亮），LED也越亮\nuint32_t ccr = (uint32_t)(lux_pct * 10);  // ARR=999时\n"
             "__HAL_TIM_SET_COMPARE(&htim2, TIM_CHANNEL_1, ccr);\n"
             "// 测试：用手遮住LDR，观察LED亮度实时变化"),
        ],
        knowledge_cards=[
            ("ADC分辨率与精度的区别？",
             "分辨率=12bit，2^12=4096个量化级别，最小分辨电压=3.3V/4095≈0.8mV\n"
             "精度受参考电压稳定性、噪声、采样时间影响，实际精度通常比分辨率低2~3位"),
            ("采样时间为什么选239.5 Cycles？",
             "高阻传感器（LDR/NTC）需要更长的采样时间让ADC输入电容充分充电。\n"
             "采样时间太短→读数偏低；通常高阻源选最长采样时间239.5 Cycles"),
            ("ADC校准有什么用？",
             "HAL_ADCEx_Calibration_Start(&hadc1) 在init后调用，\n"
             "补偿内部电容失配，可提升约1~2位有效精度。生产代码建议每次上电执行一次"),
        ],
        quiz_items=[
            ("ADC读数为2048，参考电压3.3V，对应电压是多少？",
             "V = 2048/4095 × 3.3V ≈ 1.65V（约半量程）"),
            ("为什么LDR电路需要串联电阻，而不是直接接3.3V和GND？",
             "LDR是电阻型传感器，需要分压电路将阻值变化转换为电压变化，"
             "才能被ADC读取。直接接会导致短路或无法采样。"),
        ],
        key_points=[
            "12位ADC量化值范围0~4095，电压换算：V = raw × 3.3/4095",
            "高阻传感器（LDR/NTC）需选最长采样时间239.5 Cycles",
            "启动前调用 HAL_ADCEx_Calibration_Start 提升精度",
            "光控调光联动：ADC值→光强百分比→PWM的CCR",
        ]
    )
    return (ws,)


# ═══════════════════════════════════════════════════════════
# 第9章  环境监测系统 — 实训工作页
# ═══════════════════════════════════════════════════════════

def build_ch9_worksheet():
    ws = build_worksheet_page(
        pid="p9-ws-env",
        task_title="任务9.2 多传感器环境监测系统实训",
        context_md="某智能仓储系统需要实时监测仓库的温湿度（HDC1080）、光照（BH1750）"
                   "和烟雾浓度（MQ-2），并通过串口上报数据，当烟雾超阈值时触发LED报警。"
                   "你需要完成三路传感器的驱动开发和数据融合上报。",
        objectives=[
            "能驱动I2C接口的BH1750和HDC1080传感器读取数据",
            "能读取MQ-2的ADC模拟值并换算为浓度百分比",
            "能设计JSON格式的数据上报协议",
            "能实现阈值报警逻辑（烟雾浓度>30%触发LED）",
        ],
        materials=[
            ["STM32F103C8T6开发板", "Blue Pill", "1块", "主控制器"],
            ["HDC1080温湿度传感器", "TI HDC1080", "1个", "温湿度采集"],
            ["BH1750光照传感器", "ROHM BH1750FVI", "1个", "光照采集"],
            ["MQ-2烟雾传感器", "汉威MQ-2", "1个", "气体浓度采集"],
            ["4.7kΩ上拉电阻", "用于I2C", "2个", "SDA/SCL上拉"],
        ],
        steps=[
            ("I2C硬件连接与CubeMX配置",
             "I2C1：SDA=PB7，SCL=PB6（需4.7kΩ上拉到3.3V）\n"
             "CubeMX: Connectivity → I2C1 → I2C → Fast Mode（400kHz）\n"
             "ADC: PA0 → MQ-2模拟输出，配置同第7章",
             "// I2C地址：BH1750=0x23<<1=0x46，HDC1080=0x40<<1=0x80"),
            ("驱动BH1750读取光照强度",
             "BH1750通过I2C发送测量命令，等待180ms后读取2字节结果：",
             "uint16_t BH1750_Read(void) {\n"
             "    uint8_t cmd = 0x10;  // H-Res模式\n"
             "    uint8_t data[2];\n"
             "    HAL_I2C_Master_Transmit(&hi2c1, 0x46, &cmd, 1, 100);\n"
             "    HAL_Delay(180);\n"
             "    HAL_I2C_Master_Receive(&hi2c1, 0x46, data, 2, 100);\n"
             "    return ((uint16_t)data[0]<<8|data[1]) / 1.2f;\n}"),
            ("驱动HDC1080读取温湿度",
             "HDC1080需发送寄存器地址，等待后读取2字节：",
             "float HDC1080_Temp(void) {\n"
             "    uint8_t reg=0x00; uint8_t d[2];\n"
             "    HAL_I2C_Master_Transmit(&hi2c1, 0x80, &reg, 1, 100);\n"
             "    HAL_Delay(7);\n"
             "    HAL_I2C_Master_Receive(&hi2c1, 0x80, d, 2, 100);\n"
             "    return ((d[0]<<8)|d[1])/65536.0f*165.0f-40.0f;\n}\n\n"
             "float HDC1080_Humi(void) {\n"
             "    uint8_t reg=0x01; uint8_t d[2];\n"
             "    HAL_I2C_Master_Transmit(&hi2c1, 0x80, &reg, 1, 100);\n"
             "    HAL_Delay(7);\n"
             "    HAL_I2C_Master_Receive(&hi2c1, 0x80, d, 2, 100);\n"
             "    return ((d[0]<<8)|d[1])/65536.0f*100.0f;\n}"),
            ("数据融合上报与报警逻辑（关键检查点）",
             "每2秒采集一次所有传感器数据，格式化为JSON上报：",
             "uint16_t lux   = BH1750_Read();\n"
             "float    temp  = HDC1080_Temp();\n"
             "float    humi  = HDC1080_Humi();\n"
             "uint32_t smoke_raw = ADC_Read_PA0();\n"
             "float    smoke_pct = smoke_raw * 100.0f / 4095.0f;\n\n"
             "printf('{\"lux\":%d,\"temp\":%.1f,\"humi\":%.1f,\"smoke\":%.1f}\\r\\n',\n"
             "       lux, temp, humi, smoke_pct);\n\n"
             "// 烟雾报警\nif (smoke_pct > 30.0f) {\n"
             "    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_SET);  // 报警LED\n"
             "    printf(\"ALERT: smoke=%.1f%%\\r\\n\", smoke_pct);\n"
             "} else {\n"
             "    HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_RESET);\n"
             "}"),
        ],
        knowledge_cards=[
            ("I2C 7位地址为什么要左移1位？",
             "I2C协议中，7位地址与1位R/W标志位组成8位地址字节。\n"
             "HAL_I2C函数要求传入8位地址（地址已含R/W位位置），\n"
             "因此需将7位地址左移1位：如BH1750地址0x23→传入0x46"),
            ("MQ-2传感器为什么需要预热5分钟？",
             "MQ-2是半导体气敏传感器，内置加热丝需要达到工作温度（约200°C）\n"
             "才能稳定检测气体。冷启动时读数不准，预热后稳定性<1%漂移/小时"),
            ("JSON格式上报有什么优势？",
             "可读性好，上位机解析方便（Python: json.loads(line)）\n"
             "支持多字段扩展，与云平台/物联网平台标准接口兼容\n"
             "缺点是数据量比二进制大，带宽占用高"),
        ],
        quiz_items=[
            ("BH1750返回raw=24000时，实际光照强度是多少lux？",
             "lux = 24000/1.2 = 20000 lux（相当于晴天室外光强）"),
            ("HDC1080温度寄存器读到0x6B00（原始值27392），实际温度是多少？",
             "T = 27392/65536 × 165 - 40 = 0.4179×165-40 = 68.96-40 = 28.96°C ≈ 29°C"),
        ],
        key_points=[
            "I2C HAL函数地址需左移1位（7位地址→8位参数）",
            "MQ-2需要预热5分钟，上电后不要立即使用数据",
            "多传感器融合：各自读取→统一格式化→JSON串口上报",
            "阈值报警：持续检测→超阈值执行报警→低于阈值解除",
        ]
    )
    return (ws,)


# ═══════════════════════════════════════════════════════════
# 第12章  追光控制系统 — 综合实训工作页
# ═══════════════════════════════════════════════════════════

def build_ch12_worksheet():
    ws = build_worksheet_page(
        pid="p12-ws-suntrack",
        task_title="任务12.3 追光控制系统联调实训（综合项目）",
        context_md="光伏发电板需要全天跟踪太阳方向以提高发电效率。你作为控制系统工程师，"
                   "需要完成四象限光敏传感器读取、PID控制器整定、双轴舵机驱动的完整联调，"
                   "使太阳能板实时对准光源（误差<10°）。",
        objectives=[
            "能读取四象限光敏传感器的ADC差值计算误差信号",
            "能整定PID三个参数使系统稳定快速响应",
            "能编写双轴联动控制循环（X轴/Y轴各一个PID）",
            "能记录系统响应曲线并评估控制性能（超调量/调节时间）",
        ],
        materials=[
            ["STM32F103C8T6开发板", "Blue Pill", "1块", "主控制器"],
            ["四象限光敏传感器", "4×光敏电阻阵列", "1套", "误差传感器"],
            ["SG90舵机", "标准9g舵机", "2个", "X轴和Y轴驱动"],
            ["太阳能板（模拟）", "5V小型光伏板", "1块", "被控对象"],
            ["强光手电筒", "用于模拟太阳光", "1个", "测试光源"],
        ],
        steps=[
            ("四象限传感器读取与差值计算",
             "四个光敏电阻分别连接PA0(左上)/PA1(右上)/PA2(左下)/PA3(右下)\n"
             "水平误差 = (右上+右下) - (左上+左下)，正值→光在右边\n"
             "垂直误差 = (左上+右上) - (左下+右下)，正值→光在上方",
             "uint16_t tl=ADC_Read(0), tr=ADC_Read(1), bl=ADC_Read(2), br=ADC_Read(3);\n"
             "int16_t err_x = (int16_t)((tr+br) - (tl+bl));  // 水平误差\n"
             "int16_t err_y = (int16_t)((tl+tr) - (bl+br));  // 垂直误差"),
            ("PID控制器初始化与参数整定",
             "初始参数：Kp=0.8, Ki=0.01, Kd=0.3（建议先仅用P控制验证方向正确）\n"
             "调参步骤：先调Kp（临界振荡法）→再加Ki消稳态误差→最后加Kd抑制超调",
             "PID_t pid_x, pid_y;\nPID_Init(&pid_x, 0.8f, 0.01f, 0.3f,\n"
             "         200,   // 积分限幅\n"
             "         -30, 30,  // 输出限幅（度/次）\n"
             "         30);  // 死区（ADC差值<30时不动作）\n"
             "PID_Init(&pid_y, 0.8f, 0.01f, 0.3f, 200, -20, 20, 30);"),
            ("双轴联动控制主循环",
             "每50ms执行一次PID计算和舵机更新（20Hz控制频率）：",
             "static float angle_x=90, angle_y=90;\nwhile(1) {\n"
             "    // 读传感器\n"
             "    int16_t ex = (int16_t)((ADC_Read(1)+ADC_Read(3))-(ADC_Read(0)+ADC_Read(2)));\n"
             "    int16_t ey = (int16_t)((ADC_Read(0)+ADC_Read(1))-(ADC_Read(2)+ADC_Read(3)));\n"
             "    // PID计算\n"
             "    float dx = PID_Compute(&pid_x, 0, ex);  // 目标误差=0\n"
             "    float dy = PID_Compute(&pid_y, 0, ey);\n"
             "    // 更新角度（限位保护）\n"
             "    angle_x = fmaxf(10, fminf(170, angle_x+dx));\n"
             "    angle_y = fmaxf(10, fminf(170, angle_y+dy));\n"
             "    Servo_SetAngle(SERVO_X, (uint8_t)angle_x);\n"
             "    Servo_SetAngle(SERVO_Y, (uint8_t)angle_y);\n"
             "    printf(\"{\\\"ex\\\":%d,\\\"ey\\\":%d,\\\"ax\\\":%.1f,\\\"ay\\\":%.1f}\\r\\n\",\n"
             "           ex, ey, angle_x, angle_y);\n"
             "    HAL_Delay(50);\n}"),
            ("系统性能评估（关键检查点）",
             "用手电筒在不同方向照射，观察：\n"
             "①舵机转向是否正确（光右移→X轴右转）\n"
             "②调节时间是否<3秒\n"
             "③稳定后四象限读数差值是否<30（死区内）\n"
             "记录串口数据，用Python/Excel绘制响应曲线评估超调量",
             "# Python上位机接收并绘图\nimport serial, json, matplotlib.pyplot as plt\n"
             "# ser = serial.Serial('COM3', 115200)\n# 读取数据并绘制angle_x/angle_y曲线"),
        ],
        knowledge_cards=[
            ("PID参数Kp/Ki/Kd各自控制什么？",
             "Kp（比例）：误差越大→响应越快，Kp过大→振荡\n"
             "Ki（积分）：消除稳态误差，代价是响应变慢，过大→积分饱和\n"
             "Kd（微分）：抑制超调和振荡，对噪声敏感，噪声大时要小"),
            ("为什么设置积分限幅和死区？",
             "积分限幅：防止积分饱和，当执行器已到极限时停止积分累加\n"
             "死区：传感器噪声范围内的误差不动作，避免舵机持续颤抖\n"
             "两者都是实际工程中必须添加的保护措施"),
            ("双轴控制为什么要各自独立PID？",
             "X轴（水平）和Y轴（垂直）的传感器特性、舵机响应可能不同\n"
             "独立PID允许对两个轴分别调参优化，简化整定过程\n"
             "如果两轴强耦合（互相影响），需要用解耦控制或多变量控制"),
        ],
        quiz_items=[
            ("死区设置过大有什么问题？",
             "死区过大导致稳态误差增大（光源方向与面板法线夹角增大），降低追光效率"),
            ("如果舵机转动方向反了，如何修改代码？",
             "将PID输出取反：angle_x -= dx（改为减法），或者将Kp改为负值"),
            ("如何判断Kp过大？",
             "观察现象：舵机持续来回振荡，无法稳定在光源方向。"
             "解决：将Kp减小到临界振荡时的50%，然后逐步加Ki/Kd"),
        ],
        key_points=[
            "四象限传感器：差值=误差信号，目标是差值趋近于0（四路相等）",
            "PID调参顺序：先Kp（临界振荡）→再Ki（消稳态）→最后Kd（抑超调）",
            "死区和积分限幅是工程实践必须添加的保护，不是可选项",
            "双轴独立PID：各轴分别调参，X轴水平 + Y轴垂直",
        ]
    )
    ws["game"] = {
        "modeId": "godot-game",
        "levelId": "ch12-solar-survivor-mvp",
        "title": "追光幸存者：太阳追踪挑战",
        "objective": "综合复习四象限光敏、舵机 PWM、PID、死区与限幅",
        "difficulty": 3,
        "starThresholds": [50, 75, 90],
        "timeLimit": 0,
        "data": {
            "gameId": "ch12-solar-survivor",
            "entryUrl": "/assets/godot/ch12-solar-survivor/index.html?v=26482a4deb89",
            "aspectRatio": "16 / 9",
            "durationSec": 180,
            "maxFaults": 5,
            "questionTimeSec": 15,
            "scoreScale": 100,
            "knowledgeSource": "external",
            "questionsUrl": "/assets/courses/stm32-course/knowledge/ch12-solar-survivor.questions.json?v=820de774c55a",
            "upgradesUrl": "/assets/courses/stm32-course/knowledge/ch12-solar-survivor.upgrades.json?v=1ec3ff2f2a4e",
            "bindingUrl": "/assets/courses/stm32-course/game-bindings/ch12-solar-survivor.binding.json?v=c5e7887728db",
        },
    }
    return (ws,)


# ═══════════════════════════════════════════════════════════
# 第10章  无人停车场系统 — 实训工作页
# ═══════════════════════════════════════════════════════════

def build_ch10_worksheet():
    ws = build_worksheet_page(
        pid="p10-ws-parking",
        task_title="任务10.2 无人停车场系统联调实训",
        context_md="某智能园区需要无人值守停车场系统：超声波测距判断车位是否占用，"
                   "NFC读卡识别身份，舵机控制道闸，数码管显示剩余车位数。"
                   "你需要完成各子系统的联调整合，用有限状态机管理系统逻辑。",
        objectives=[
            "能用HC-SR04超声波传感器判断车辆是否在位（阈值<20cm）",
            "能用MFRC522 SPI接口读取IC卡UID识别身份",
            "能用有限状态机管理'空闲→进场→停车→出场'状态转换",
            "能整合各子系统实现完整的入场、停车、离场流程",
        ],
        materials=[
            ["STM32F103C8T6开发板", "Blue Pill", "1块", "主控制器"],
            ["HC-SR04超声波模块", "4-pin型", "2个", "车辆检测（入口+出口）"],
            ["MFRC522 NFC读卡模块", "SPI接口", "1个", "身份识别"],
            ["SG90舵机", "标准9g", "1个", "道闸控制"],
            ["4位数码管模块", "共阴/共阳均可", "1个", "显示剩余车位"],
            ["LED指示灯", "红绿各1个", "2个", "状态指示"],
        ],
        steps=[
            ("超声波测距函数编写",
             "HC-SR04时序：TRIG发10μs高脉冲 → ECHO高电平持续时间×0.034/2=距离(cm)\\n"
             "用TIM输入捕获或轮询方式测量ECHO高电平时间：",
             "uint32_t HC_SR04_GetDist(GPIO_TypeDef *trig_port, uint16_t trig_pin,\\n"
             "                         GPIO_TypeDef *echo_port, uint16_t echo_pin) {\\n"
             "    // 发TRIG脉冲\\n"
             "    HAL_GPIO_WritePin(trig_port, trig_pin, GPIO_PIN_SET);\\n"
             "    HAL_Delay(1);  // >10μs\\n"
             "    HAL_GPIO_WritePin(trig_port, trig_pin, GPIO_PIN_RESET);\\n"
             "    // 等待ECHO上升沿\\n"
             "    uint32_t t1 = HAL_GetTick();\\n"
             "    while (!HAL_GPIO_ReadPin(echo_port, echo_pin)) if (HAL_GetTick()-t1>50) return 999;\\n"
             "    t1 = HAL_GetTick();\\n"
             "    while (HAL_GPIO_ReadPin(echo_port, echo_pin)) if (HAL_GetTick()-t1>50) return 999;\\n"
             "    return (HAL_GetTick() - t1) * 17;  // ms×17 ≈ cm\\n}"),
            ("MFRC522 NFC读卡初始化",
             "SPI2接口：SCK=PB13, MISO=PB14, MOSI=PB15, CS=PB12\\n"
             "MFRC522 RST接PA8，初始化后等待卡片靠近：",
             "// SPI初始化后调用MFRC522_Init()\\nMFRC522_Init();\\n"
             "// 主循环中检测卡片\\nif (MFRC522_Request(PICC_REQIDL, str) == MI_OK) {\\n"
             "    MFRC522_Anticoll(str);  // 获取卡UID\\n"
             "    printf(\\\"UID: %02X%02X%02X%02X\\\\r\\\\n\\\",str[0],str[1],str[2],str[3]);\\n}"),
            ("有限状态机设计",
             "系统状态：IDLE（空闲）→ ENTRY（进场检测）→ PARKED（已停车）→ EXIT（离场）\\n"
             "状态转换触发：NFC刷卡 + 超声波距离阈值组合判断：",
             "typedef enum { ST_IDLE, ST_ENTRY, ST_PARKED, ST_EXIT } ParkState;\\n"
             "ParkState state = ST_IDLE;\\n"
             "uint8_t total_slots = 10, used_slots = 0;\\n\\n"
             "// while(1)主循环\\nswitch (state) {\\n"
             "    case ST_IDLE:\\n"
             "        // 等待入口NFC刷卡\\n"
             "        if (nfc_detected) { state = ST_ENTRY; }\\n"
             "        break;\\n"
             "    case ST_ENTRY:\\n"
             "        // 开道闸 → 等待车辆进入（入口超声波>50cm）\\n"
             "        Servo_Open(); used_slots++;\\n"
             "        Display4Digit(total_slots - used_slots);\\n"
             "        state = ST_PARKED;\\n"
             "        break;\\n"
             "    case ST_PARKED:\\n"
             "        // 等待出口NFC刷卡（出场）\\n"
             "        if (exit_nfc_detected) { state = ST_EXIT; }\\n"
             "        break;\\n"
             "    case ST_EXIT:\\n"
             "        Servo_Open(); used_slots--;\\n"
             "        Display4Digit(total_slots - used_slots);\\n"
             "        state = ST_IDLE;\\n"
             "        break;\\n}"),
            ("联调验证（关键检查点）",
             "1. 将IC卡靠近MFRC522：道闸开启，数码管剩余车位-1\\n"
             "2. 将IC卡再次靠近出口读卡器：道闸开启，剩余车位+1\\n"
             "3. 用遮挡物模拟车辆：超声波读数变化应<20cm\\n"
             "4. 串口打印状态转换日志，验证FSM正确性",
             ""),
        ],
        knowledge_cards=[
            ("HC-SR04误差来源有哪些？",
             "1. 温度影响声速（常温15°C: 340m/s，每升1°C+0.6m/s）\\n"
             "2. 障碍物表面角度（斜面散射，有效角度±15°）\\n"
             "3. 轮询方式的定时精度（HAL_GetTick为1ms分辨率，建议用定时器捕获）"),
            ("SPI协议的4种模式是什么？",
             "由CPOL(时钟极性)和CPHA(时钟相位)决定：\\n"
             "Mode0: CPOL=0,CPHA=0（MFRC522使用此模式）\\n"
             "Mode1: CPOL=0,CPHA=1\\n"
             "Mode2: CPOL=1,CPHA=0\\n"
             "Mode3: CPOL=1,CPHA=1"),
            ("有限状态机设计的注意事项？",
             "1. 每个状态的进入/退出动作要清晰定义\\n"
             "2. 非法转换（如PARKED直接→IDLE）要有保护\\n"
             "3. 超时机制：状态停留时间过长自动回退\\n"
             "4. 调试时串口打印状态变化"),
        ],
        quiz_items=[
            ("超声波测距公式：距离 = ECHO高电平时间 × ?",
             "距离(m) = t(s) × 340/2，即半程时间×声速。\\n"
             "实际计算：若HAL_GetTick单位ms，距离(cm) = t(ms) × 0.034 × 100 / 2 = t × 1.7"),
            ("为什么NFC读卡后需要Anticoll（防冲突）？",
             "多张卡同时靠近时，Request会收到多张卡的应答，Anticoll用树形搜索选定唯一UID，防止冲突"),
        ],
        key_points=[
            "HC-SR04测距：TRIG发10μs脉冲→ECHO高电平持续时间→除以声速得距离",
            "FSM设计：明确状态集合、转换条件、进入/退出动作，状态不重叠",
            "SPI通信必须确认CPOL/CPHA设置与从设备一致（MFRC522用Mode0）",
            "联调顺序：先单独测各子模块→再集成→最后FSM逻辑验证",
        ]
    )
    return (ws,)


# ═══════════════════════════════════════════════════════════
# 第11章  运动手环 — 实训工作页
# ═══════════════════════════════════════════════════════════

def build_ch11_worksheet():
    ws = build_worksheet_page(
        pid="p11-ws-band",
        task_title="任务11.2 运动手环系统实训",
        context_md="某健康监测手环需要实现步数计数、运动强度分级、低功耗运行三大核心功能。"
                   "你需要用LSM6DS3陀螺仪加速度计检测运动，实现计步算法，"
                   "并通过Sleep模式降低功耗。",
        objectives=[
            "能通过I2C接口读取LSM6DS3的三轴加速度数据",
            "能实现基于阈值的简单计步算法（峰值检测法）",
            "能用STM32低功耗模式（Sleep/Stop）降低系统功耗",
            "能根据步频计算运动强度并通过LED/OLED显示",
        ],
        materials=[
            ["STM32F103C8T6开发板", "Blue Pill", "1块", "主控制器"],
            ["LSM6DS3 IMU模块", "I2C接口", "1个", "三轴加速度+陀螺仪"],
            ["OLED显示屏", "SSD1306 0.96寸", "1个", "显示步数/状态"],
            ["LED指示灯", "红/绿/蓝各1", "3个", "运动状态指示"],
            ["LiPo电池", "3.7V 1000mAh", "1块", "供电（模拟手环）"],
        ],
        steps=[
            ("LSM6DS3初始化与数据读取",
             "I2C地址：SDO接GND时0x6A<<1=0xD4，接VCC时0x6B<<1=0xD6\\n"
             "初始化：写入CTRL1_XL寄存器（0x10）配置加速度计范围和ODR：",
             "// 配置加速度计：104Hz ODR，±2g量程\\nuint8_t cfg = 0x40;  // ODR=104Hz, FS=±2g\\n"
             "HAL_I2C_Mem_Write(&hi2c1, 0xD4, 0x10, 1, &cfg, 1, 100);\\n\\n"
             "// 读取XYZ加速度（各2字节，小端）\\nuint8_t raw[6];\\n"
             "HAL_I2C_Mem_Read(&hi2c1, 0xD4, 0x28, 1, raw, 6, 100);\\n"
             "int16_t ax = (int16_t)((raw[1]<<8)|raw[0]);  // 原始值\\n"
             "float ax_g = ax * 0.000061f;  // ±2g量程 LSB=0.061mg"),
            ("计步算法（峰值检测法）",
             "计步原理：计算合加速度幅值 |a| = sqrt(ax²+ay²+az²)\\n"
             "当|a|超过上阈值后再下降到下阈值时，计一步：",
             "#define STEP_HIGH 1.3f  // 上阈值（g）\\n"
             "#define STEP_LOW  0.9f  // 下阈值（g）\\n\\n"
             "static uint32_t step_count = 0;\\n"
             "static uint8_t above_high = 0;\\n\\n"
             "float acc_mag = sqrtf(ax_g*ax_g + ay_g*ay_g + az_g*az_g);\\n"
             "if (!above_high && acc_mag > STEP_HIGH) {\\n"
             "    above_high = 1;\\n"
             "} else if (above_high && acc_mag < STEP_LOW) {\\n"
             "    above_high = 0;\\n"
             "    step_count++;  // 计一步\\n"
             "    printf(\\\"Steps: %lu\\\\r\\\\n\\\", step_count);\\n}"),
            ("运动强度分级与显示",
             "根据每分钟步数（步频）判断运动强度：",
             "uint32_t steps_per_min = step_count - steps_last_min;\\n"
             "steps_last_min = step_count;\\n\\n"
             "if (steps_per_min < 60) {\\n"
             "    HAL_GPIO_WritePin(LED_PORT, LED_GREEN, GPIO_PIN_SET);  // 静止\\n"
             "    printf(\\\"Mode: 静止 (%lu步/min)\\\\r\\\\n\\\", steps_per_min);\\n"
             "} else if (steps_per_min < 120) {\\n"
             "    HAL_GPIO_WritePin(LED_PORT, LED_BLUE, GPIO_PIN_SET);   // 行走\\n"
             "    printf(\\\"Mode: 行走 (%lu步/min)\\\\r\\\\n\\\", steps_per_min);\\n"
             "} else {\\n"
             "    HAL_GPIO_WritePin(LED_PORT, LED_RED, GPIO_PIN_SET);    // 跑步\\n"
             "    printf(\\\"Mode: 跑步 (%lu步/min)\\\\r\\\\n\\\", steps_per_min);\\n}"),
            ("低功耗Sleep模式（关键检查点）",
             "在等待传感器数据时进入Sleep模式，有中断时自动唤醒：",
             "// 配置LSM6DS3数据就绪中断（INT1引脚）\\n"
             "// 主循环：\\nwhile (1) {\\n"
             "    if (data_ready_flag) {\\n"
             "        data_ready_flag = 0;\\n"
             "        LSM6DS3_ReadAccel(&ax_g, &ay_g, &az_g);\\n"
             "        StepDetect(ax_g, ay_g, az_g);\\n"
             "    }\\n"
             "    HAL_PWR_EnterSLEEPMode(PWR_MAINREGULATOR_ON, PWR_SLEEPENTRY_WFI);\\n"
             "    // WFI: Wait For Interrupt，任何中断唤醒\\n}"),
        ],
        knowledge_cards=[
            ("MEMS加速度计的量程和灵敏度如何选择？",
             "量程±2g：灵敏度高（0.061mg/LSB），适合计步（人体加速度<2g）\\n"
             "量程±16g：量程大，适合检测冲击碰撞\\n"
             "步数计算用±2g或±4g，运动冲击检测用±8g或±16g"),
            ("Sleep模式和Stop模式的区别？",
             "Sleep模式：CPU停止，外设继续运行，任意中断唤醒，唤醒时间<1μs\\n"
             "Stop模式：CPU+大部分外设停止，只有RTC/外部中断可唤醒，功耗更低\\n"
             "手环等设备常用Stop+RTC定时唤醒的组合"),
            ("计步算法还有哪些更准确的方法？",
             "峰值检测（本实训）：简单，但对缓慢行走和快速抖动误判\\n"
             "动态阈值法：阈值随运动强度自适应，准确率提升\\n"
             "STFT频域法：分析加速度频谱，步频峰值即步数，最准确\\n"
             "商用芯片（如Bosch BSX）内置计步算法，误差<2%"),
        ],
        quiz_items=[
            ("LSM6DS3 ±2g量程下，1LSB对应多少g的加速度？",
             "灵敏度 = 2×2g / 2^16 = 4/65536 ≈ 0.000061g = 0.061mg/LSB"),
            ("为什么计步算法要用两个阈值（迟滞比较）而不是一个？",
             "单阈值会在加速度在阈值附近抖动时产生多次触发（抖动计步误差）。\\n"
             "双阈值迟滞：必须先超过上阈值，再下降过下阈值才计1步，消除抖动误判"),
        ],
        key_points=[
            "LSM6DS3：I2C地址由SDO引脚决定，CTRL1_XL配置ODR和量程",
            "计步峰值检测：合加速度>上阈值→设标志；后续<下阈值→计步+清标志",
            "Sleep模式WFI：所有中断都能唤醒，适合有数据就绪中断的传感器",
            "运动强度分级基于步频（步/分钟），静止<60/行走60~120/跑步>120",
        ]
    )
    return (ws,)
