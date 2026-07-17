# -*- coding: utf-8 -*-
"""
inject_narration_p3_key_int.py — M11 子-A · P3 key-int 播报脚本注入

设计目标
--------
把 P3 key-int 页 6 个 SPEAKABLE block 的播报脚本一次性注入到 manifest.json
（与 chapters/ch02_ch03.py 里的同一份数据共用），让该节播报总时长 ≥ 15 分钟
（4 字/秒 × 60 × 15 = 3600 中文字基线）。

数据 = 真相
-----------
``P3_KEY_INT_NARRATION`` 是单一事实源 (single source of truth)：
  - apply_to_pages(pages)  → 注入 chapters/ch02_ch03.py build_p3_pages() 返回值
  - apply_to_manifest(m)   → 注入 manifest.json 已生成的产物
两条路径走同一份字典，避免双写漂移。

幂等：重跑只会覆盖目标 block 的 commentary / metadata.teacher，不会重复追加。

约束遵守
--------
- 不改 manifest.ts / PageRenderer / finale 等组件
- 不改 17 final invariant 两个文件
- 仅追加新文件 + 在 chapters 文件末尾 import 调用
- SPEAKABLE 字段对齐 apps/player/src/playback/blockToSpeech.ts 的提取规则：
  * text/code/experiment/mermaid → commentary.stepScripts (优先) / commentary.script
  * animation                    → metadata.teacher.stepScripts / metadata.teacher.script
  * digital-human                → script
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Any


# ─────────────────────────────────────────────────────────────────────────────
# 1. 播报脚本数据（单一事实源）
#    每条 stepScripts 控制在 120~220 中文字之间，对应 Manim 5~8 秒一镜的节奏
# ─────────────────────────────────────────────────────────────────────────────

# text block：按键电路 + 消抖 + 中断 + 优先级（6 段递进）
_TEXT_STEP_SCRIPTS = [
    "我们先从最朴素的物理图景说起。按键就是两片金属触点，没按时彼此分开，按下时合到一起。"
    "电路里把按键一端接 GND，另一端接到 MCU 引脚，再让这根引脚配置成内部上拉输入。"
    "上拉的本质是芯片内部一个 10 千欧左右的电阻把引脚悄悄拉到 3.3 伏。"
    "于是没按时引脚通过这个上拉电阻读到稳定的高电平 1；按下时引脚被开关直接拽到地，读到低电平 0。"
    "这种「按下变低」的接法叫负逻辑，是嵌入式里最常见的按键电路。",

    "为什么必须配上拉？因为如果引脚悬空，它会成为一根天线，受周围电磁干扰胡乱跳变，"
    "你今天读到 0、明天读到 1，调试时根本无法复现。上拉电阻给引脚一个明确的默认值——"
    "「我现在就是高」——按键合上时这个明确值会被 GND 强行覆盖，于是出现确定的下降沿。"
    "整个按键检测的可靠性，就建立在这一根 10 千欧上拉电阻提供的「确定性」之上。",

    "但物理世界还有一个绕不过去的脏活：抖动。机械触点在闭合或断开的瞬间，"
    "会因为弹片回弹、表面氧化、机械振动产生 5 到 20 毫秒的高频跳变。"
    "你以为按了一次，引脚电平实际上会在 0 和 1 之间反复横跳几十次。"
    "如果直接 ReadPin 就动作，一次按下会被识别成多次，LED 会闪烁、计数会暴涨。"
    "新手第一次写按键代码十有八九栽在这里。",

    "软件消抖是嵌入式入门必学的「闭着眼也能写」的套路：第一次检测到低电平后等 20 毫秒，"
    "再读一次，仍是低电平才确认按下。逻辑上就是 ReadPin == RESET、HAL_Delay(20)、"
    "再 ReadPin == RESET，两次确认才执行业务。20 毫秒这个数字是经验值——"
    "比抖动周期长，比人按键的反应慢，正好把抖动滤掉又不会让用户觉得迟钝。",

    "轮询消抖能 work，但代价是 CPU 必须不停地查引脚。"
    "高级方案叫外部中断 EXTI——把「按键是否按下」这件事交给硬件去盯。"
    "CubeMX 里把 PA0 的 GPIO Mode 改成 GPIO_EXTI0，触发条件选 Falling Edge 下降沿，"
    "对应按键按下那一刻的电平变化。再去 NVIC 标签页打勾使能 EXTI0 中断、设个优先级。"
    "Generate Code 后 HAL 会自动给你生成中断向量、IRQHandler 框架，剩下的只要写一个回调。",

    "回调函数叫 HAL_GPIO_EXTI_Callback，参数 uint16_t GPIO_Pin 告诉你哪一根引脚触发了中断。"
    "里面判断 GPIO_Pin == GPIO_PIN_0 就是 PA0 那一路按下了，于是去翻转 PC13 上的 LED。"
    "最后说一句中断优先级。STM32 用 4 位 NVIC 优先级，前几位是抢占、后几位是子优先级，"
    "数字越小优先级越高——这是新手最容易记反的点。SysTick 默认 0 是最高，"
    "用户中断一般设 5 到 10，记住「不同设备给不同优先级，避免互相抢、互相阻塞」就够用。",
]


# animation block：4 个分镜 + 总览 → 5 段长解说，对齐 Manim 5~7 秒/镜
# anim_scenes 顺序：① 上拉输入 ② 抖动消抖 ③ EXTI 流程 ④ 中断 vs 轮询
_ANIM_TEACHER_SCRIPT = (
    "下面这段动画把按键和外部中断从硬件到软件串成一个完整故事。"
    "我们会依次走过四个画面：上拉输入电路、机械抖动现象、EXTI 中断的硬件流转，"
    "以及最后中断和轮询两种方案的 CPU 占用对比。看完这一段，你脑子里"
    "就能拥有一张「按一次按键，到底发生了什么」的全景地图。"
)

_ANIM_STEP_SCRIPTS = [
    # 镜头 1：上拉输入电路
    "第一幕是按键电路。屏幕上看到 MCU 引脚 PA0、内部 10 千欧上拉电阻、按键开关、GND 四个元素。"
    "未按下时电流走的路径是：3.3 伏 → 上拉电阻 → 引脚，引脚被「拉」到高电位读 1；"
    "按下时开关闭合，引脚被直接「短路」到 GND 读 0。"
    "动画里你能看到电流方向的红色箭头切换——这一切换正是 GPIO 数字输入要捕捉的「事件」。"
    "记住三个关键词：上拉、负逻辑、确定的下降沿。",

    # 镜头 2：抖动与消抖
    "第二幕放大了按下瞬间的真实波形。理想里是一刀切的下降沿，现实里是密密麻麻的小毛刺，"
    "持续 5 到 20 毫秒。这是机械触点弹跳和氧化层导通的副产物，"
    "再贵的按键都跑不掉，只是程度差异。"
    "动画接着叠了一条软件消抖的处理曲线——蓝色采样点先在低电平采到一次，"
    "停 20 毫秒等抖动平息，再采一次确认还是低，才把信号判定为「真按下」。"
    "你可以把这一段当成给信号「过筛子」，把 20 毫秒以内的瞬态噪声全部滤掉。",

    # 镜头 3：EXTI 中断硬件流转
    "第三幕是这一节的灵魂——外部中断 EXTI 的硬件流转。"
    "屏幕上从下到上一共五块：GPIO 引脚、EXTI 控制器、NVIC、CPU 内核、用户回调。"
    "按下那一刻 PA0 出现下降沿，EXTI 控制器先做边沿匹配——只有跟 CubeMX 配的"
    "Falling Edge 一致才放行；放行后向 NVIC 提交一个中断请求；NVIC 按抢占优先级"
    "决定要不要打断 CPU；决定打断后，CPU 自动跳到 EXTI0_IRQHandler 这个入口；"
    "HAL 库在 IRQHandler 里清中断标志、再分发到用户重定义的 Callback。"
    "整条链路一气呵成，不需要主循环参与。",

    # 镜头 4：中断 vs 轮询 CPU 占用对比
    "第四幕把中断和轮询放在同一张时间轴上对比。"
    "上半屏是轮询：CPU 一直在「按了没？按了没？」打孔式查询，黄色占用条几乎填满整条时间轴，"
    "即便用户半小时不按按键，CPU 也休息不了。"
    "下半屏是中断：黄色占用条只在按键真的发生时短短闪一下，其余时间 CPU 是灰色的休眠状态——"
    "这意味着更长的电池续航、更低的发热、更多的算力可以拿去做别的事。"
    "对低功耗产品来说，这两条曲线之间的差距，就是「能不能上市」的差距。",

    # 收束：把 4 镜串起来
    "把这四幕串起来：硬件的不确定性（抖动）需要软件用消抖去削平，"
    "软件的「忙等待」（轮询）又通过把控制权交给硬件中断（EXTI + NVIC）来释放 CPU。"
    "嵌入式工程师做的事情，就是在硬件和软件这两层之间反复折叠，让系统既稳又省。"
    "把这四幕反复看几遍，你会发现一条隐藏的主线——硬件提供「事件捕获能力」，"
    "软件提供「事件响应策略」，二者都不可偏废：纯软件方案稳但耗 CPU，"
    "纯硬件方案省但需要正确配置 NVIC 和回调；只有两条腿一起走，"
    "才能做出既能批量量产、又能在低功耗场景下真正长时间运行的产品。"
    "下面进入流程图和代码环节，把动画里看到的逻辑落到具体的 CubeMX 配置和 C 语言写法上，"
    "你会看到这一节学到的所有概念都在代码层一一对应——这就是嵌入式课程从「看懂」到「写得出」的关键一跃。",
]


# mermaid 流程图：原有 9 段 stepScripts 已较扎实（181 字），仅"head/tail"小润色
# 不替换原 stepScripts，但补一段总章 script 让没点开节点也能听到完整解释
_MERMAID_SCRIPT = (
    "这张流程图把外部中断从硬件下降沿到用户回调再回到主循环的全过程串起来。"
    "九个节点对应九个时刻：按下、下降沿、EXTI 检测、NVIC 路由、IRQHandler 进入、"
    "Callback 调用、业务执行、ISR 返回、主循环恢复。下面我们逐节点过一遍，"
    "把每一步对应的硬件动作和软件接口都讲清楚，你可以对照代码同步看。"
)

_MERMAID_STEP_SCRIPTS = [
    "第一步，按键被按下。物理上是触点闭合，电气上是 PA0 引脚和 GND 之间被开关接通。"
    "在用户感知里就是「咔哒」一下，这一下是整条中断链路的起点。",

    "第二步，PA0 上出现下降沿。前一时刻引脚通过上拉电阻读 3.3 伏，这一时刻被 GND 短路到 0 伏，"
    "电压在几微秒里完成跳变，硬件层面把这个跳变记成一个「下降沿事件」，挂在 EXTI 输入端。",

    "第三步，EXTI 控制器做边沿过滤。EXTI 内部为每条线都登记了「上升沿、下降沿、双沿」三种使能位，"
    "只有跟 CubeMX 里勾选的 Falling Edge 一致才会触发；其他方向的边沿被直接吃掉，不打扰 CPU。",

    "第四步，NVIC 接到 EXTI 的中断请求。NVIC 是 Cortex-M 内核里的「中断仲裁器」，"
    "它会拿当前 CPU 正在跑的中断和这个新请求比抢占优先级——数字小的赢——"
    "赢了的请求才会被允许打断 CPU 主线程。",

    "第五步，CPU 跳进 EXTI0_IRQHandler。这是一个由启动文件登记到中断向量表里的固定入口，"
    "HAL 库在这里替你做了两件事：清中断挂起标志，避免中断重复进入；"
    "调用统一的 HAL_GPIO_EXTI_IRQHandler 分发函数。",

    "第六步，HAL 库调用 HAL_GPIO_EXTI_Callback。这个函数原型在 HAL 里是 __weak 弱符号，"
    "你只要在自己的源文件里定义同名函数，链接器会优先选你的版本——"
    "这就是 HAL 「Callback 钩子」机制，让用户代码不用动 IRQHandler。",

    "第七步，回调里执行真正的业务逻辑。本节的例子就是判断 GPIO_Pin == GPIO_PIN_0，"
    "然后 HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13) 翻转板载 LED。"
    "记住一条铁律——回调是 ISR 上下文，里面禁止 HAL_Delay、禁止长循环、禁止打印一大坨日志。",

    "第八步，回调返回，IRQHandler 也跟着返回。CPU 自动恢复中断前压栈的现场——"
    "PC、xPSR、R0~R3 等寄存器一并出栈——主线程继续从被打断的那条指令往下跑，"
    "感觉上就像中断从来没发生过。",

    "第九步，CPU 回到 main 函数的 while(1) 主循环。整个中断闭环到此完成，"
    "等待下一次按键的下降沿。如果你愿意，把流程图从上往下再看一遍——"
    "硬件触发 → 控制器过滤 → 仲裁器路由 → CPU 处理 → 返回主循环——这就是嵌入式中断的标准节拍。",
]

# code block：轮询 + 中断两段代码 → 4 段长解说（开篇 + 轮询 + 消抖 + 中断铁律）
_CODE_STEP_SCRIPTS = [
    "这段代码把按键的两种典型写法放在同一个 .c 文件里对照。"
    "上半部分 key_poll_task 是轮询 + 软件消抖的最朴素版本；"
    "下半部分 HAL_GPIO_EXTI_Callback 是配合 CubeMX 生成的中断回调。"
    "两套写法实现同一个功能——按键翻转 PC13 上的 LED——但代价完全不同。"
    "建议在板子上把两种都跑一遍，亲手感受它们对 CPU 的占用差异。",

    "先看 key_poll_task。第 7 行 HAL_GPIO_ReadPin 读 PA0，按下时返回 GPIO_PIN_RESET 也就是 0。"
    "PA0 在 CubeMX 里配的是 GPIO Mode = Input、Pull-up = Enabled，所以未按时由内部上拉读 1，"
    "按下时被开关拉到 GND 读 0。这一行检测到的是「电平低」，还不是「真按下」——"
    "因为机械抖动会让电平在按下瞬间反复跳变，所以下一行立刻进入消抖逻辑。",

    "第 8 到 12 行是软件消抖的标准三步：HAL_Delay(20) 让 CPU 等 20 毫秒，"
    "等抖动平息；再 ReadPin 二次确认仍是 RESET，才认按键有效；"
    "认有效后用 while 循环忙等按键释放——读到 SET 才退出——避免一次按下被识别成多次。"
    "注意第 16 行的 HAL_GPIO_TogglePin 翻转 PC13，这种「轮询 + Delay + 阻塞等释放」是教学版"
    "实际项目里不会这么写，因为 Delay 的 20 毫秒里 CPU 啥也干不了。",

    "下半部分是中断写法。第 19 行的注释说明 CubeMX 配置：PA0 → GPIO_EXTI0、Falling Edge、NVIC 使能。"
    "Generate Code 后 HAL 自动生成 IRQHandler，你只需要重写第 19 行的 HAL_GPIO_EXTI_Callback。"
    "里面判断 GPIO_Pin == GPIO_PIN_0 就是 PA0 触发的，然后翻转 LED。"
    "请把第 21 行的注释当成 ISR 编程铁律刻在心里——「★ 此处不能调用 HAL_Delay」——"
    "原因是 HAL_Delay 依赖 SysTick 中断递增的 uwTick 计数器，"
    "而 SysTick 中断如果优先级比当前 ISR 低，根本进不来，于是 Delay 永远等不到自己，系统死锁。"
    "实战里在 ISR 里只做最短的事：置 flag、读寄存器、翻转 GPIO，剩下的扔给主循环或 RTOS 任务。",

    "再补一条新手最常踩的坑——「我没消抖，按一次按键 LED 闪好多次，是不是中断有 bug？」"
    "不是 bug，是抖动每一次跳变都触发了 EXTI 中断，回调里翻 LED 当然就翻好多次。"
    "中断版的消抖有两种主流写法：第一种在回调里用 HAL_GetTick 比较时间戳，"
    "距离上次触发不到 50 毫秒就 return；第二种在中断里只置一个 flag，"
    "主循环检测 flag + 延时 + 二次确认，把消抖延迟移出 ISR。"
    "前者代码短适合简单按键，后者更工程化，配合 RTOS 时几乎是标配。"
    "把这两种都写一遍，你就真的把按键 + 中断这件事吃透了。",
]


# experiment block：4 步实验 → 6 段长解说（开篇 + 4 步详解 + 排错收束）
_EXP_STEP_SCRIPTS = [
    "实验目标：在 STM32F103 板子上同时验证「轮询 + 消抖」和「外部中断」两种按键检测方案，"
    "用同一个 PC13 LED 做现象指示。整套实验分四个检查点，建议你跟着视频一步步做，"
    "每完成一步先点页面上的 Checkpoint 打勾再往下走——这样出问题时可以精准回退到上一个能 work 的状态。",

    "第 1 步：搭建按键电路。最小连接是 PA0 → 按键 → GND。"
    "如果板子上已经有自带 KEY 按键（比如野火、正点原子的常见板），"
    "看一下原理图确认这颗按键接的就是 PA0；不是 PA0 的话改 CubeMX 的引脚号即可。"
    "重点：CubeMX 里 PA0 必须配成 Input + Pull-up，不能选 No pull-up——"
    "否则按键松开时引脚悬空，会读到不确定的电平，调试时会出现「明明没按 LED 也乱闪」的诡异现象。",

    "第 2 步：先跑轮询版本。在 while(1) 里调 key_poll_task，按一下板子上的按键，"
    "PC13 LED 翻转一次。观察两个细节：第一，连按很快时 LED 会跟丢——因为 while 里在阻塞等待按键释放；"
    "第二，整个程序响应非常稳，但 CPU 一直在跑那个 ReadPin 循环，"
    "如果在 main 里加个 printf 打印计数器，会发现计数速率因为消抖延时被严重拖慢。"
    "这两点正是后面要用中断替换它的原因。",

    "第 3 步：用 CubeMX 切到中断模式。把 PA0 的 GPIO Mode 改成 GPIO_EXTI0、"
    "Pull-up 保持、Trigger detection 选 External Interrupt Mode with Falling edge trigger detection；"
    "再去 NVIC Settings 标签页打勾 EXTI line0 interrupt，优先级先用默认 0。"
    "Project → Generate Code 后会发现 HAL 自动给你的 main.c 生成了 MX_GPIO_Init，"
    "里面调了 HAL_NVIC_SetPriority 和 HAL_NVIC_EnableIRQ——这两步是中断使能的关键。",

    "第 4 步：实现 HAL_GPIO_EXTI_Callback 回调，里面判断 GPIO_Pin == GPIO_PIN_0 翻转 PC13。"
    "下载到板子上之后再按按键，你会看到 LED 翻转的「跟手感」明显比轮询版好——"
    "因为中断在硬件里抢断 CPU，几乎没有延迟。同时把主循环里的轮询代码注释掉，"
    "让 main 跑一个空的 while(1)，CPU 就真的进入「闲置」状态——这就是中断方案的最大价值。",

    "排错收束：如果按下没反应，按这个顺序排查——"
    "一查 NVIC 是否打勾使能、二查 GPIO Mode 是不是 EXTI 不是普通 Input、"
    "三查 Trigger 沿和你按下方向是否一致（按下到地是 Falling）、"
    "四查 main 里有没有 while(1) 卡死或者优先级冲突让中断永远没机会进来。"
    "全部跑通后回到页面顶部，把这一节的关键概念再过一遍：上拉、负逻辑、消抖、EXTI、NVIC、Callback、ISR 铁律——"
    "这就是按键 + 外部中断这个看似简单的话题里真正的硬核内容。",
]


# digital-human：扩成 3 段（站位寄语 + 关键收束 + 对接下一节）
_DH_SCRIPT = (
    "按键是人机交互的起点，中断是嵌入式系统的灵魂——掌握这两者，"
    "你的 STM32 程序就从「只会跑空循环的玩具」进化到「能响应外部世界的产品」。"
    "回顾这一节的脉络：硬件层我们靠上拉电阻保证电平的确定性，靠软件消抖过滤机械抖动；"
    "软件层我们用 EXTI + NVIC 把控制权交给硬件，让 CPU 在没事时安心休眠。"
    "最关键的两条铁律请刻进肌肉记忆——一是 NVIC 里数字越小优先级越高，"
    "二是 ISR 里禁止 HAL_Delay 和长循环。把这两条记牢，"
    "你以后写所有外设的中断代码都能少走 80% 的弯路。"
    "下一节我们会进入定时器，用同样的 EXTI + Callback 思路去理解 PWM、输入捕获和编码器接口，"
    "你会发现 STM32 的整个外设体系，都是这一节学到的「事件 + 中断 + 回调」模型在不同硬件上的复用。"
)


# ─────────────────────────────────────────────────────────────────────────────
# 2. 聚合：按 block id 索引的播报数据字典（apply_to_pages / apply_to_manifest 复用）
# ─────────────────────────────────────────────────────────────────────────────
P3_KEY_INT_NARRATION: dict[str, dict[str, Any]] = {
    "p3-key-int-text": {
        "kind": "text",
        "commentary": {
            "stepScripts": _TEXT_STEP_SCRIPTS,
            # script 留作 fallback，控制 ≤1200 字（CommentarySchema 上限）
            "script": (
                "本节讲按键扫描和外部中断。先看按键电路：一端接 GND、另一端接 MCU 引脚配内部上拉，"
                "未按读 1、按下读 0，是负逻辑。机械抖动 5~20ms，软件消抖三步——"
                "检测低电平 → 延时 20ms → 二次确认。轮询浪费 CPU，外部中断 EXTI 让硬件捕获事件："
                "CubeMX 配 GPIO_EXTI、Falling Edge、NVIC 使能、实现 Callback 回调。"
                "中断优先级用 4 位 NVIC，数字越小优先级越高，不同外设要分配不同优先级。"
            ),
        },
    },
    "p3-key-int-anim": {
        "kind": "animation",
        "metadata.teacher": {
            "script": _ANIM_TEACHER_SCRIPT,
            "stepScripts": _ANIM_STEP_SCRIPTS,
            "voice": "Cherry",
            "autoPlay": False,
            "sceneId": "p3-key-int-animation-scene",
        },
    },
    "p3-key-int-flow": {
        "kind": "mermaid",
        # 不覆盖原 stepScripts（已扎实），仅在 script 缺失/过短时增强
        "commentary": {
            "stepScripts": _MERMAID_STEP_SCRIPTS,
            "script": _MERMAID_SCRIPT,
        },
    },
    "p3-key-code": {
        "kind": "code",
        "commentary": {
            "stepScripts": _CODE_STEP_SCRIPTS,
            # script 摘要：≤1200 字，仅作 fallback
            "script": (
                "代码把按键的两种典型写法放在同一文件：上半部分 key_poll_task 是轮询+消抖，"
                "下半部分 HAL_GPIO_EXTI_Callback 是中断回调。轮询版用 ReadPin 检测低电平、"
                "Delay 20ms 后二次确认、while 等释放。中断版靠 CubeMX 配 EXTI + NVIC + Falling Edge，"
                "Generate Code 后只需重写 Callback。ISR 编程铁律：禁止 HAL_Delay，禁止长循环，"
                "禁止打印一大坨日志——否则会因 SysTick 优先级低于当前 ISR 而死锁。"
                "中断版消抖有两种主流写法：HAL_GetTick 比较时间戳直接 return，"
                "或者中断只置 flag、主循环检测 flag + 二次确认。后者更工程化，配合 RTOS 是标配。"
            ),
        },
    },
    "p3-key-int-exp": {
        "kind": "experiment",
        "commentary": {
            "stepScripts": _EXP_STEP_SCRIPTS,
            # script 摘要：≤1200 字，仅作 fallback
            "script": (
                "实验目标：在 STM32F103 板上同时验证轮询+消抖和外部中断两种按键检测方案。"
                "四个检查点：1) 搭建 PA0→按键→GND 电路，CubeMX 必须 Pull-up；"
                "2) 跑轮询版本，观察连按跟丢和 CPU 拖慢两个现象；"
                "3) CubeMX 切 EXTI + Falling Edge + NVIC 使能；"
                "4) 实现 HAL_GPIO_EXTI_Callback 翻转 PC13，主循环空 while(1) 看 CPU 真的闲置。"
                "排错顺序：查 NVIC 是否使能、GPIO Mode 是否 EXTI、Trigger 沿是否一致、"
                "是否有更高优先级中断把它阻塞。全部跑通后回顾上拉、负逻辑、消抖、EXTI、NVIC、"
                "Callback、ISR 铁律——这就是按键加外部中断这个看似简单话题里真正的硬核内容。"
            ),
        },
    },
    "p3-key-int-dh": {
        "kind": "digital-human",
        "script": _DH_SCRIPT,
    },
}


# ─────────────────────────────────────────────────────────────────────────────
# 3. 注入函数（数据 → block dict 字段）
# ─────────────────────────────────────────────────────────────────────────────
def _apply_to_block(block: dict[str, Any], spec: dict[str, Any]) -> None:
    """把单条 narration spec 写到 block 上。幂等：覆盖已有字段。"""
    kind = block.get("kind")
    if kind != spec.get("kind"):
        # 类型对不上时静默跳过——避免误注入
        return

    if kind == "animation":
        meta = block.setdefault("metadata", {})
        teacher = dict(spec.get("metadata.teacher") or {})
        # 保留原有 steps 字段（视觉摘要），其余字段被新数据覆盖
        old = meta.get("teacher") or {}
        if "steps" in old and "steps" not in teacher:
            teacher["steps"] = old["steps"]
        meta["teacher"] = teacher
        return

    if kind == "digital-human":
        if spec.get("script"):
            block["script"] = spec["script"]
        return

    # text / code / experiment / mermaid → commentary
    if "commentary" in spec:
        existing = block.get("commentary") or {}
        merged = dict(existing)
        merged.update(spec["commentary"])
        block["commentary"] = merged


def apply_to_pages(pages: list[dict[str, Any]]) -> int:
    """注入 chapters/ch02_ch03.py build_p3_pages() 返回的 page list。

    返回成功注入的 block 数。
    """
    n = 0
    for page in pages:
        if page.get("id") != "p3-key-int":
            continue
        for block in page.get("blocks", []):
            spec = P3_KEY_INT_NARRATION.get(block.get("id"))
            if not spec:
                continue
            _apply_to_block(block, spec)
            n += 1
    return n


def apply_to_manifest(manifest: dict[str, Any]) -> int:
    """注入已生成的 manifest.json（chapter → section → page → blocks 三层嵌套）。"""
    n = 0
    for ch in manifest.get("chapters", []):
        for sec in ch.get("sections", []):
            for page in sec.get("pages", []):
                if page.get("id") != "p3-key-int":
                    continue
                for block in page.get("blocks", []):
                    spec = P3_KEY_INT_NARRATION.get(block.get("id"))
                    if not spec:
                        continue
                    _apply_to_block(block, spec)
                    n += 1
    return n


# ─────────────────────────────────────────────────────────────────────────────
# 4. CLI 入口：直接对 manifest.json 打 narration 补丁
# ─────────────────────────────────────────────────────────────────────────────
def _chinese(s: str) -> int:
    return len(re.findall(r"[\u4e00-\u9fa5]", s))


def _stats() -> tuple[int, list[tuple[str, int]]]:
    """估算每个 block 的「真实播放」字数（与 blockToSpeech.ts 提取规则严格对齐）。

    规则（同 apps/player/src/playback/blockToSpeech.ts）：
      - text/code/experiment/mermaid/graphics → commentary.stepScripts 优先
        若有 stepScripts 则不再计 commentary.script；否则 fallback 到 commentary.script
      - animation → metadata.teacher.stepScripts 优先；否则 metadata.teacher.script
      - digital-human → script
    """
    rows: list[tuple[str, int]] = []
    for bid, spec in P3_KEY_INT_NARRATION.items():
        chars = 0
        kind = spec.get("kind")
        if kind == "animation":
            t = spec.get("metadata.teacher") or {}
            ss = t.get("stepScripts") or []
            if ss:
                chars = sum(_chinese(s) for s in ss)
            else:
                chars = _chinese(t.get("script") or "")
        elif kind == "digital-human":
            chars = _chinese(spec.get("script") or "")
        elif "commentary" in spec:
            c = spec["commentary"]
            ss = c.get("stepScripts") or []
            if ss:
                chars = sum(_chinese(s) for s in ss)
            else:
                chars = _chinese(c.get("script") or "")
        rows.append((bid, chars))
    return sum(c for _, c in rows), rows


def main() -> None:
    public = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    manifest_path = os.path.join(public, 'manifest.json')

    total, rows = _stats()
    print(f"[narration] P3 key-int 播报字数预算（≥3600 字 = ≥15 分钟）：")
    for bid, c in rows:
        print(f"  - {bid:25s} {c:5d} 字")
    print(f"  合计 {total} 字 ≈ {total/240:.2f} 分钟")
    if total < 3600:
        print(f"[WARN] 不足 3600 字，距离 15 分钟还差 {3600-total} 字")

    print(f"\n[manifest] 读取 {manifest_path}")
    with open(manifest_path, encoding='utf-8') as f:
        manifest = json.load(f)
    n = apply_to_manifest(manifest)
    print(f"[OK] 注入 {n} 个 block 的播报数据")
    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    size_kb = os.path.getsize(manifest_path) // 1024
    print(f"[DONE] manifest.json 写回 ({size_kb}KB)")


if __name__ == '__main__':
    main()
