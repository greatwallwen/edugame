# -*- coding: utf-8 -*-
"""
inject_narration_p3_led_blink.py — M11 子-A · P3 led-blink 播报脚本注入

设计同 inject_narration_p3_key_int.py：
  - P3_LED_BLINK_NARRATION 是单一事实源
  - apply_to_pages(pages)   → 注入 chapters/ch02_ch03.py build_p3_pages() 返回值
  - apply_to_manifest(m)    → 注入 manifest.json 已生成的产物
  - python inject_narration_p3_led_blink.py 直接对 manifest.json 打补丁，幂等

P3 led-blink 比 P3 key-int 多两个 SPEAKABLE：
  - graphics  p3b-led-svg                ← 4 节点 SVG，commentary.stepScripts
  - animation p3-led-blink-gpio-manim    ← 第二个 manim 动画

预算（≥3600 中文字 = ≥15 分钟，与 blockToSpeech.ts 提取规则严格对齐）：
  text 700 + graphics 250 + anim 900 + manim 400 + code 700 + exp 600 + dh 250 ≈ 3800
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Any


# ─────────────────────────────────────────────────────────────────────────────
# 1. text · p3-led-blink-text — 6 段递进
#    (LED 物理 → 限流电阻 → HAL 函数族 → 流水灯 → 呼吸灯 → GPIO 模式选型)
# ─────────────────────────────────────────────────────────────────────────────

_TEXT_STEP_SCRIPTS = [
    "LED 是发光二极管的简称，对嵌入式新人来说它就是「亮灯三件套」里最可亲的一件。"
    "物理上 LED 是单向导电的 PN 结，正向电压超过它的开启电压（红灯约 1.8 伏，"
    "蓝灯绿灯约 3.0 伏）才会发光。STM32 的 GPIO 推挽输出能直接给到 3.3 伏，"
    "所以最常见的接法就是 PA5 → 220 欧限流电阻 → LED 正极 → LED 负极 → GND。"
    "高电平时电流从引脚流出经电阻和 LED 回到 GND，LED 就亮了；低电平时引脚被拉到 0 伏，"
    "和 LED 负极同电位，没有电压差也就没有电流，LED 自然就灭。",

    "为什么必须串联限流电阻？因为 LED 是「电压敏感器件」——电压超过它的导通阈值后，"
    "电流会随电压指数增长，一不小心就过流烧毁。STM32 引脚虽然标称最大 25 毫安，"
    "但 LED 的工作电流通常只要 5 到 20 毫安，多出来的能量都会在 LED 内部变成热失效。"
    "限流电阻的算法很简单：电阻阻值 R = (Vcc − VLED) / Iled。"
    "用 3.3 伏减 2 伏正向压降，再除以 6 毫安目标电流，得到 217 欧，工程上取标称值 220 欧。"
    "把这条公式记在脑子里，以后给任何 LED 配电阻都能秒算。",

    "HAL 库给 GPIO 输出准备了三个常用函数，背下来就能写 90% 的 LED 程序。"
    "第一个 HAL_GPIO_WritePin(GPIOA, GPIO_PIN_5, GPIO_PIN_SET) 把 PA5 拉高，LED 亮；"
    "第二个把第三个参数换成 GPIO_PIN_RESET 就拉低，LED 灭；"
    "第三个 HAL_GPIO_TogglePin 是「翻转」——上次是高这次就是低，无需自己记状态。"
    "Toggle 配 HAL_Delay 是写闪烁的最短代码：while(1){ Toggle; Delay(500); } 五行解决。"
    "这就是 STM32 入门第一个 Hello LED 程序的标准长相。",

    "流水灯的本质是把闪烁拓展到多个引脚 + 时间错位。"
    "把 4 颗 LED 接在 PA5 到 PA8，用一个数组 leds[] = {PIN_5, PIN_6, PIN_7, PIN_8} 存引脚号，"
    "再写 for 循环 i 从 0 到 3：先 WritePin 把 leds[i] 拉高，Delay 200 毫秒，再拉低。"
    "肉眼看到的就是「灯依次点亮、依次熄灭」的流水效果。"
    "如果想换花样——比如双向跑、追逐效果、霹雳游侠的扫描灯——只要改 for 循环的下标顺序就行，"
    "数组和 for 循环就是流水灯的全部秘密。",

    "呼吸灯比流水灯更有意思，它考验的是「时间分辨率」概念。"
    "原理是软件 PWM——固定 100 微秒为一个周期，"
    "用 duty 变量控制其中高电平占多长。duty=20 表示 20 微秒高、80 微秒低，"
    "肉眼上一秒钟内看到几千次切换，平均亮度就是 20%。"
    "把 duty 从 0 渐变到 100 再回到 0，肉眼就看到了「呼吸」。"
    "需要注意的是软件 PWM 占 CPU，等学到 PWM 外设后，把 duty 写进定时器寄存器，"
    "硬件自己生成方波，CPU 完全不用管，那才是工业级的呼吸灯写法。",

    "最后聊一下 GPIO 模式选型。CubeMX 里 PA5 配置成 GPIO_Output 后，下面还能选 Push Pull 还是 Open Drain。"
    "推挽（Push Pull）是双向驱动，高电平拉到 3.3 伏、低电平拉到 GND，电流可灌可拉，"
    "驱动 LED 用它就够了。开漏（Open Drain）只能拉低不能拉高，需要外部上拉电阻才能输出高电平，"
    "适合做 I2C 这种多主线通信的总线。LED 这一类负载，记住「先想推挽，再想开漏」就不会出错。"
    "OK 这一节的物理铺垫到这里，下面我们对照动画一格一格看电流路径。",
]


# ─────────────────────────────────────────────────────────────────────────────
# 2. graphics · p3b-led-svg — 4 节点 SVG → 4 段长解说（对应 4 个节点）
# ─────────────────────────────────────────────────────────────────────────────

_GRAPHICS_STEP_SCRIPTS = [
    "看左侧第一个节点：GPIO 引脚配置为推挽输出后，可在 0 伏与 3.3 伏之间切换——"
    "这就是 LED 闪烁的总电源开关。所谓「推挽」，是说它既能往外推电流（高电平时），"
    "也能往内吸电流（低电平时）。电流从 STM32 内部的 PMOS 管被推出来，"
    "或者通过 NMOS 管被吸回去，整条引脚就像一个可以双向工作的水龙头，方向取决于你写 SET 还是 RESET。",

    "第二个节点是限流电阻。电流从 GPIO 流出后第一站就是这颗电阻，"
    "它把工作电流压到大约 6 毫安。为什么是 6 毫安？因为这是 LED 的「合理发光区间」——"
    "亮度足够清晰，又不会让芯片引脚因过流而升温。"
    "电阻在这里既是保护元件，也是「能量分配器」：3.3 伏总电压里，"
    "约 1.3 伏会落在电阻上变成热，剩下的 2 伏给 LED 发光。这是高中物理串联分压的真实工程应用。",

    "第三个节点电流流入 LED 正极、从负极流出，PN 结被「点亮」——"
    "其实点亮的并不是电流本身，而是电子在 PN 结复合时释放出的能量以光子形式辐射出来。"
    "LED 的颜色由材料的禁带宽度决定：红色 LED 用磷化镓铝、蓝色用氮化铟镓，颜色不同正向压降也不同。"
    "这就是为什么蓝色和白色 LED 经常需要更高电源电压：它们的开启电压更高，3.3 伏 GPIO 直驱可能不够，"
    "需要换 5 伏供电或者升压。",

    "第四个节点是回路闭合。电流通过 GND 完成闭环——这是被新人最常忽略的一步。"
    "记住一句口诀：「电流必须形成闭环，开路就不工作」。"
    "如果你把 LED 负极悬空忘接 GND，前面三步全做对，电路也是死的。"
    "排查 LED 不亮时，先用万用表测引脚电压，再测 LED 两端电压，最后确认 GND 通路——"
    "这条「电源 → 限流 → LED → 回地」的四段路径就是所有点灯电路的祖宗模板，"
    "后面无论是按键、传感器还是显示模块，本质都是它的变种。",
]


# ─────────────────────────────────────────────────────────────────────────────
# 3. animation · p3-led-blink-anim — 4 镜电流路径动画 → 5 段（含收束）
# ─────────────────────────────────────────────────────────────────────────────

_ANIM_TEACHER_SCRIPT = (
    "下面这段动画把 LED 闪烁与流水灯背后的电流路径完整可视化。"
    "我们会依次走过四个画面：电压差形成、限流电阻分压、LED 发光、流水灯多路扩展，"
    "外加一段总收束。看完这一段你就知道——LED 程序是写软件，但本质上是设计电流路径。"
)

_ANIM_STEP_SCRIPTS = [
    "第一幕：电压差的形成。屏幕上 PA5 引脚初始是低电平 0 伏，与 GND 等电位，整条电路没有电流。"
    "代码写下 WritePin(PA5, SET) 的瞬间，引脚被推到 3.3 伏，PA5 与 GND 之间出现 3.3 伏电压差。"
    "请注意——「高电平」并不是「亮灯命令」，它是「形成电压差」。"
    "电压差是发动机，电流才是真正点亮 LED 的能量。"
    "这一步的工程意义是：写软件的同学要养成「想电压差」的本能，不要把代码理解成魔法。",

    "第二幕：限流电阻把电压差转化为安全电流。3.3 伏电压差落在电阻和 LED 串联回路上，"
    "电阻吃掉一部分电压，剩下的给 LED。电阻吃多少电压取决于电流需求——"
    "动画里你能看到电流条被「卡」在 6 毫安附近，那是 220 欧电阻规定好的安全速率。"
    "如果你换成 1 千欧电阻，电流会被压到 1.3 毫安，LED 还能亮但很暗；"
    "换成 100 欧，电流飙到 13 毫安，LED 更亮但寿命降低；换成 10 欧，电流逼近 100 毫安，"
    "LED 立刻烧毁、引脚也可能受损。这就是「电阻是 LED 的命门」。",

    "第三幕：LED 真正发光。电流流过 PN 结，电子和空穴在结区复合，每复合一次就释放一个光子。"
    "动画里你看到的红色光波，就是这些光子的视觉化。"
    "LED 的「正向压降」固定在 2.0 伏左右，无论你用什么电阻，只要 LED 在工作，它两端的电压就是 2 伏。"
    "这意味着电源越高，电阻必须越大，才能维持安全电流——这就是 5 伏单片机配 330 欧、"
    "12 伏 LED 灯条配 1 千欧的原因。一条公式打通所有电压等级。",

    "第四幕：流水灯的本质是多个 GPIO 轮流建立这条安全电流路径。"
    "PA5、PA6、PA7、PA8 各接一颗 LED，循环里轮流 SET 和 RESET——"
    "动画里你能看到电流路径在四颗 LED 之间像水流一样滑动。"
    "硬件上四条路径完全独立、互不干扰，软件上你只需要一个 for 循环加一个引脚数组。"
    "这就是嵌入式编程的优雅之处：你写的是「概念」（数组遍历），跑出来的是「物理现象」（光的流动）。",

    "把这四幕串起来：写软件就是在硬件上设计电流路径。"
    "电压差是因，电流是果，电阻是法律，LED 是表演者。"
    "理解这条逻辑后，你回头看 HAL_GPIO_WritePin 这一行代码，"
    "脑子里浮现的不再是抽象的「拉高拉低」，而是一条从 PA5 出发、经过 220 欧、点亮 LED、回到 GND 的真实电流。"
    "下面进入第二段动画，把这条静态电路换成方波，让 LED 真的「闪烁」起来。",
]


# ─────────────────────────────────────────────────────────────────────────────
# 4. animation · p3-led-blink-gpio-manim — 第二个 manim：方波闪烁 → 4 段
#    （Iter-22 收口：steps=4 ↔ stepScripts=4 严格对齐 ADR-0016；
#      原第 5 段「总结」融入镜头四，避免 ANIMATION_MISMATCH）
# ─────────────────────────────────────────────────────────────────────────────

_MANIM_TEACHER_SCRIPT = (
    "这一段 manim 动画把 LED 闪烁还原成最朴素的物理过程：GPIO 输出方波。"
    "我们会一步步看引脚电压在 0 伏和 3.3 伏之间反复跳变，怎么变成你眼前这颗一秒亮一次的 LED。"
    "一旦理解了这条 1 赫兹方波的来龙去脉，再看流水灯、呼吸灯、PWM、定时器中断，全都是这条方波的变种。"
)

_MANIM_STEP_SCRIPTS = [
    "镜头一：硬件铺设。屏幕上左边是 STM32 芯片，右边一颗 LED——LED 一端接电源，"
    "另一端经 220 欧限流电阻接到 GPIO 引脚（视频里用 PC13，工程里也常见 PA5）。"
    "请记住这条「电源 → LED → 电阻 → GPIO」的串联是反接，"
    "GPIO 拉低时 LED 亮、GPIO 拉高时 LED 灭——板载 LED 的常见接法。"
    "这是为了让 GPIO 「灌入电流」而不是「输出电流」，对低端 MCU 而言灌入能力通常更强。",

    "镜头二：调用 GPIO_SetBits 或 HAL_GPIO_WritePin SET，"
    "动画里你看到引脚电压从 0 伏跳到 3.3 伏，但 LED 反而灭了——"
    "因为 LED 另一端是电源，引脚高电平意味着两端等电位、没电压差、没电流。"
    "这一镜可能颠覆你的直觉：「拉高 = 灭灯」。"
    "板载 LED 用反接是为了利用「灌电流」更强这一硬件特性，"
    "外接 LED 要点亮就用前面讲的「拉高=亮」正接，两种接法都要会。",

    "镜头三：调用 GPIO_ResetBits 或 HAL_GPIO_WritePin RESET，"
    "引脚被拉到 0 伏，LED 另一端的 3.3 伏与引脚之间形成电压差，电流从电源出发，"
    "经 LED 经电阻流入引脚，再被 STM32 灌进 GND——LED 亮起。"
    "动画里你看到一条红色的电流路径在芯片内部完成闭环，"
    "这条路径就是「灌入电流」的真身。STM32F103 的 GPIO 灌入能力大约 25 毫安，"
    "驱动一两颗 LED 不在话下。",

    "镜头四：把 SET 和 RESET 周期切换，"
    "PC13 上就形成一条 1 赫兹方波——半秒高、半秒低。"
    "肉眼看到的就是 LED 一秒亮一次、一秒灭一次。"
    "如果把切换周期降到几毫秒，LED 在视觉上会变成「一直亮着但稍微暗」的状态，"
    "因为人眼有 50 毫秒左右的视觉暂留——这就是后面呼吸灯和 PWM 的物理基础。"
    "频率越低你看到「闪」，频率越高你看到「亮度」。"
    "总结一下：1 赫兹方波 = 把 GPIO 当作电源开关，按周期切换。"
    "再加一层 for 循环就是流水灯，再加可变占空比就是呼吸灯，"
    "再把这件事交给硬件定时器自动做就是 PWM 外设——"
    "本节学到的所有花样都是这条方波的不同改装。"
    "下面进入互动环节，把刚刚动画里看到的物理过程，落到代码每一行的具体写法。",
]


# ─────────────────────────────────────────────────────────────────────────────
# 5. code · p3-led-code — led_demo.c 三个函数 → 5 段
#    (闪烁原型 / 流水灯数组遍历 / 呼吸灯软 PWM / 高亮行 / 工程化建议)
# ─────────────────────────────────────────────────────────────────────────────

_CODE_STEP_SCRIPTS = [
    "看 led_blink 这个函数。它只有四行——while(1) 死循环里调一次 HAL_GPIO_TogglePin，"
    "再调一次 HAL_Delay(500)，循环结束。STM32 启动后会一直跑这两行，"
    "PA5 每 500 毫秒翻转一次电平，1 赫兹方波，肉眼看就是「一秒亮一次」。"
    "Toggle 函数内部会读出 ODR 寄存器当前位、按位异或 1、再写回去——"
    "这种「读改写」操作在 STM32 上是原子的，不需要担心被中断打断。"
    "记住这个函数原型：它是 99% 的 STM32 入门第一颗灯的写法。",

    "led_flow 函数演示流水灯。第 16 行定义 pins[] 数组，存四个引脚号 PIN_5 到 PIN_8——"
    "工程上这种「集合 + 遍历」是非常 Pythonic 的 C 写法。"
    "while(1) 套 for(i=0..3) 双层循环：内层每轮先 WritePin SET 把 leds[i] 拉高、Delay 200 毫秒、"
    "再 RESET 拉低。外层负责把 i 重置为 0 让流水永不停。"
    "如果你想换成「双向跑」效果，把 for 循环换成 0,1,2,3,2,1 这样的下标序列就行——"
    "整个修改不超过 5 行代码。",

    "第 28 行进入 led_breath 函数，这是软件 PWM 实现呼吸灯的最简版本。"
    "外层两个 for 循环：第一段 duty 从 0 涨到 100，第二段从 100 降回 0，构成一个完整的呼吸周期。"
    "内层做的事很简单——周期 100 微秒里，先把 PA5 拉高 duty 微秒，再拉低 100 减 duty 微秒。"
    "duty=20 时占空比 20%，肉眼看到的平均亮度是满亮的 1/5；"
    "duty=80 时是 4/5。从 0 平滑变到 100 再变回 0，看起来就是 LED 在缓缓呼吸。"
    "注意 delay_us 是用户自己实现的微秒级延时函数，HAL 库没有现成的，"
    "通常用 SysTick 或 DWT 的 CYCCNT 计数器实现。",

    "高亮行是 8、16、28 行——分别对应三个函数的入口。这种「只读高亮」的代码片段，"
    "实际播放时会触发摄像机拉到对应行附近，方便你在视频里跟着指读。"
    "建议你把这段代码完整 Copy 到 main.c 的 USER CODE BEGIN 4 区域，"
    "在 main 函数 while(1) 之前调用 led_blink() 或 led_flow()——CubeMX 重新生成代码也不会被覆盖。"
    "这是工程实践里最稳的代码组织规则：业务函数放 USER CODE 区，自动生成区一字不动。",

    "三个函数对比一下：闪烁是 1 个引脚 + 周期切换；流水是 N 个引脚 + 时间错位；呼吸是 1 个引脚 + 占空比变化。"
    "这三种模式合起来已经能写出相当复杂的灯光效果——比如把流水和呼吸叠加，每颗 LED 在「跑」的同时还在「呼吸」，"
    "做出的氛围灯光绝对不输商业产品。但软件 PWM 的代价是 CPU 全程被占住，无法跑别的任务。"
    "等学到 TIM 定时器和 PWM 输出比较模式后，把这三种花样换成寄存器配置，CPU 就能一边呼吸一边干活，"
    "那才是工业级的写法。这一节的代码，先把基础打牢。",
]


# ─────────────────────────────────────────────────────────────────────────────
# 6. experiment · p3-led-blink-exp — 4 步实验 + 排错收束 → 6 段
# ─────────────────────────────────────────────────────────────────────────────

_EXP_STEP_SCRIPTS = [
    "实验第一步：搭建 LED 电路。准备一块面包板、一颗红色 LED、一个 220 欧电阻、两根杜邦线。"
    "接线顺序：开发板 PA5 引脚 → 一根杜邦线 → 面包板上 220 欧电阻一端 → 电阻另一端 → LED 长脚（正极）→ "
    "LED 短脚（负极）→ 另一根杜邦线 → 开发板 GND。注意 LED 极性千万别接反——长脚接正极、短脚接负极，"
    "反接虽然不会烧 LED 但绝对不亮。这一步看似简单，但工程师 80% 的「不亮事故」都来自布线错误，"
    "包括：电阻接到电源正极、LED 反接、GND 没接、面包板内部断路。",

    "实验第二步：CubeMX 配置 PA5 为 GPIO 输出。打开 .ioc 文件，在芯片视图里点 PA5 引脚，选 GPIO_Output。"
    "右下角的 Configuration 标签里把 GPIO output level 设为 Low（启动时 LED 灭），"
    "GPIO mode 选 Push Pull（推挽），Maximum output speed 选 Low（节能）。"
    "User Label 起一个有意义的名字比如 LED_RED 或 LED_GREEN，CubeMX 会自动生成宏定义到 main.h，"
    "之后写代码就能用 LED_RED_Pin 替代 GPIO_PIN_5，可读性大幅提升。"
    "配置完点 Project → Generate Code 一键生成 Keil 工程。",

    "实验第三步：实现 LED 闪烁。打开 main.c，找到 while(1) 死循环里的 USER CODE BEGIN WHILE 注释——"
    "在它下面加两行：HAL_GPIO_TogglePin(GPIOA, GPIO_PIN_5); 然后 HAL_Delay(500);"
    "按 F7 编译，按 F8 下载到开发板，按 RESET 复位——LED 应该开始稳定地一秒闪一次。"
    "如果 LED 没动静，按下面这个流程排查：先看编译有没有报错，再看下载有没有成功，"
    "再用万用表测 PA5 引脚电压是不是在 0 伏和 3.3 伏之间跳变，最后看接线。"
    "记住 80% 的 bug 都在硬件不在软件。",

    "实验第四步：实现流水灯。把 PA5 到 PA8 都配置成 GPIO_Output，每个引脚都接一颗 LED。"
    "代码里定义 uint16_t pins[] = {GPIO_PIN_5, GPIO_PIN_6, GPIO_PIN_7, GPIO_PIN_8}; "
    "写一个 for 循环，i 从 0 到 3，每次 WritePin SET、Delay 200、WritePin RESET。"
    "把这个 for 循环放在 while(1) 里，编译下载——四颗 LED 应该开始流水。"
    "如果只有一颗亮，检查是不是少配了引脚；如果整体闪得太快，把 200 调到 500；"
    "如果想做「霹雳游侠」效果，把 for 改成 i 从 0 到 3 再从 3 回到 0 的两段循环。",

    "做完这四步实验，你已经走完了 STM32 GPIO 输出的完整链条：从硬件接线到 CubeMX 配置、"
    "从代码编写到下载验证、从单颗 LED 到流水灯多路扩展。"
    "这一套流程是后面所有 STM32 项目的共同模板——按键、传感器、电机、显示屏，全都遵循「先硬件、再 CubeMX、再代码、再下载」的四步法。"
    "把这一套熟练到能盲打的程度，后面学外设速度会快好几倍。",

    "最后讲一下排错心法。LED 不亮按这个顺序查：第一查极性，长脚接正极没？第二查电阻，220 欧串联没？"
    "第三查 GND，回路闭合没？第四查 CubeMX，PA5 模式是不是 Output、Push Pull？"
    "第五查代码，是不是用了 PA5 但写成了 PIN_4？第六查时钟，HAL_RCC_GPIOA_CLK_ENABLE 调了没？"
    "（CubeMX 一般会自动加，但偶尔会漏。）按这六步排查，99% 的「不亮事故」都能定位。"
    "把这条诊断链刻进肌肉记忆，你就从「会跑代码的同学」升级成「能 debug 的工程师」了。",
]


# ─────────────────────────────────────────────────────────────────────────────
# 7. digital-human · p3-led-blink-dh — 站位寄语 + 收束 + 衔接下一节
# ─────────────────────────────────────────────────────────────────────────────

_DH_SCRIPT = (
    "GPIO 是 STM32 与物理世界交互的第一道门，点亮第一颗 LED 是每个嵌入式工程师的成年礼。"
    "看似简单的闪烁背后涉及五件事：时钟使能、引脚配置、电流路径设计、限流电阻选型、HAL 函数调用，每一步都有它的物理依据。"
    "把这一节的「电压差 → 限流电阻 → LED 发光 → GND 回路」四段路径刻进脑子，"
    "你以后看任何 GPIO 输出电路都不会再迷路。"
    "下一节我们把视角切到 GPIO 输入，研究怎么用按键告诉单片机「人类的指令」——"
    "你会发现按键的电路虽然反过来，但电压差、上下拉电阻、消抖、中断这些概念，全都是这一节物理直觉的延伸。"
)


# ─────────────────────────────────────────────────────────────────────────────
# 8. 短 fallback：commentary.script / metadata.teacher.script
#    schema 限制最大 1200 字符；全文走 stepScripts，script 只做兜底摘要
# ─────────────────────────────────────────────────────────────────────────────

_TEXT_FALLBACK_SCRIPT = (
    "本节系统讲解 STM32 GPIO 输出驱动 LED 的完整知识链：LED 的 PN 结发光原理与正向压降、"
    "限流电阻 R = (Vcc − Vled) / Iled 的计算公式、HAL_GPIO_WritePin / TogglePin 三大常用函数、"
    "流水灯（数组 + for 循环）与呼吸灯（软件 PWM 占空比）两类常见花样，"
    "以及 Push Pull 与 Open Drain 两种 GPIO 模式的选型差异。"
    "完整脚本在 stepScripts 中分 6 段播放。"
)

_GRAPHICS_FALLBACK_SCRIPT = (
    "电流路径四段视图：GPIO 推挽输出 → 220 欧限流电阻 → LED 发光 → GND 闭环。"
    "完整解说在 stepScripts 中分 4 段播放，对应 SVG 4 个节点。"
)

_CODE_FALLBACK_SCRIPT = (
    "led_demo.c 三个函数：闪烁（Toggle + Delay）、流水（数组 + for）、呼吸（软件 PWM 占空比）。"
    "高亮行 8/16/28 分别对应三个函数入口。完整解说在 stepScripts 中分 5 段播放。"
)

_EXP_FALLBACK_SCRIPT = (
    "四步实验法 + 排错心法：搭电路 → CubeMX 配 PA5 → 写 Toggle 闪烁代码 → 扩展为流水灯。"
    "排错六步：极性、电阻、GND、CubeMX 模式、代码引脚号、时钟使能。"
    "完整解说在 stepScripts 中分 6 段播放。"
)


# ─────────────────────────────────────────────────────────────────────────────
# 9. 聚合：P3_LED_BLINK_NARRATION（单一事实源）
# ─────────────────────────────────────────────────────────────────────────────

P3_LED_BLINK_NARRATION: dict[str, dict[str, Any]] = {
    "p3-led-blink-text": {
        "kind": "text",
        "commentary": {
            "script": _TEXT_FALLBACK_SCRIPT,
            "stepScripts": _TEXT_STEP_SCRIPTS,
        },
    },
    "p3b-led-svg": {
        "kind": "graphics",
        "commentary": {
            "script": _GRAPHICS_FALLBACK_SCRIPT,
            "stepScripts": _GRAPHICS_STEP_SCRIPTS,
        },
    },
    "p3-led-blink-anim": {
        "kind": "animation",
        "teacher": {
            "script": _ANIM_TEACHER_SCRIPT,
            "stepScripts": _ANIM_STEP_SCRIPTS,
        },
    },
    "p3-led-blink-gpio-manim": {
        "kind": "animation",
        "teacher": {
            "script": _MANIM_TEACHER_SCRIPT,
            "stepScripts": _MANIM_STEP_SCRIPTS,
        },
    },
    "p3-led-code": {
        "kind": "code",
        "commentary": {
            "script": _CODE_FALLBACK_SCRIPT,
            "stepScripts": _CODE_STEP_SCRIPTS,
        },
    },
    "p3-led-blink-exp": {
        "kind": "experiment",
        "commentary": {
            "script": _EXP_FALLBACK_SCRIPT,
            "stepScripts": _EXP_STEP_SCRIPTS,
        },
    },
    "p3-led-blink-dh": {
        "kind": "digital-human",
        "script": _DH_SCRIPT,
    },
}


# ─────────────────────────────────────────────────────────────────────────────
# 10. 注入函数：_apply_to_block / apply_to_pages / apply_to_manifest
# ─────────────────────────────────────────────────────────────────────────────

def _apply_to_block(block: dict[str, Any], spec: dict[str, Any]) -> bool:
    """对单个 block 注入 narration spec。已注入则原地覆盖，幂等。"""
    kind = spec.get("kind")
    if kind in ("text", "code", "experiment", "mermaid", "graphics"):
        c = block.setdefault("commentary", {})
        s = spec.get("commentary") or {}
        if "script" in s:
            c["script"] = s["script"]
        if "stepScripts" in s:
            c["stepScripts"] = list(s["stepScripts"])
        return True
    if kind == "animation":
        meta = block.setdefault("metadata", {})
        teacher = meta.setdefault("teacher", {})
        t = spec.get("teacher") or {}
        if "script" in t:
            teacher["script"] = t["script"]
        if "stepScripts" in t:
            teacher["stepScripts"] = list(t["stepScripts"])
        return True
    if kind == "digital-human":
        if "script" in spec:
            block["script"] = spec["script"]
        return True
    return False


def apply_to_pages(pages: list[dict[str, Any]]) -> int:
    """供 chapters/ch02_ch03.py build_p3_pages() 调用。返回注入的 block 数。"""
    n = 0
    for p in pages:
        if p.get("id") != "p3-led-blink":
            continue
        for b in p.get("blocks", []):
            spec = P3_LED_BLINK_NARRATION.get(b.get("id"))
            if spec and _apply_to_block(b, spec):
                n += 1
    return n


def apply_to_manifest(manifest: dict[str, Any]) -> int:
    """供 inject_finale_patch.py 同级流水线调用，对 manifest.json 已生成产物注入。"""
    n = 0
    for ch in manifest.get("chapters", []):
        for sec in ch.get("sections", []):
            for p in sec.get("pages", []):
                if p.get("id") != "p3-led-blink":
                    continue
                for b in p.get("blocks", []):
                    spec = P3_LED_BLINK_NARRATION.get(b.get("id"))
                    if spec and _apply_to_block(b, spec):
                        n += 1
    return n


# ─────────────────────────────────────────────────────────────────────────────
# 11. _stats() 与 blockToSpeech.ts 严格对齐：有 stepScripts 不计 script
# ─────────────────────────────────────────────────────────────────────────────

_CN_RE = re.compile(r"[\u4e00-\u9fa5]")


def _chinese(s: str | None) -> int:
    return len(_CN_RE.findall(s or ""))


def _stats() -> tuple[int, list[tuple[str, str, int]]]:
    """返回 (总字数, [(id, kind, chars), ...]) — 真实播放口径。"""
    rows: list[tuple[str, str, int]] = []
    total = 0
    for bid, spec in P3_LED_BLINK_NARRATION.items():
        kind = spec.get("kind", "")
        if kind == "animation":
            t = spec.get("teacher") or {}
            ss = t.get("stepScripts") or []
            chars = sum(_chinese(s) for s in ss) if ss else _chinese(t.get("script"))
        elif kind == "digital-human":
            chars = _chinese(spec.get("script"))
        elif "commentary" in spec:
            c = spec.get("commentary") or {}
            ss = c.get("stepScripts") or []
            chars = sum(_chinese(s) for s in ss) if ss else _chinese(c.get("script"))
        else:
            chars = 0
        rows.append((bid, kind, chars))
        total += chars
    return total, rows


# ─────────────────────────────────────────────────────────────────────────────
# 12. CLI：直接对 manifest.json 打补丁（幂等）
# ─────────────────────────────────────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument(
        "--manifest",
        default=os.path.join(os.path.dirname(__file__), "..", "manifest.json"),
        help="manifest.json 路径",
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="只打印统计，不写回 manifest.json")
    parser.add_argument("--threshold", type=int, default=3600,
                        help="字数门槛（默认 3600 = 15 分钟）")
    args = parser.parse_args(argv)

    total, rows = _stats()
    print("=== P3 led-blink narration · 真实播放字数（与 blockToSpeech.ts 对齐）===")
    for bid, kind, chars in rows:
        print(f"  [{kind:13s}] {bid:30s} {chars:5d} 字")
    print(f"  {'TOTAL':47s} {total:5d} 字  (~{total/240:.2f} min)")
    print(f"  threshold: {args.threshold} ({args.threshold/240:.1f} min)  "
          f"-> {'PASS' if total >= args.threshold else 'FAIL'}")

    mp = os.path.abspath(args.manifest)
    if not os.path.isfile(mp):
        print(f"[WARN] manifest not found: {mp}")
        return 0 if total >= args.threshold else 1

    with open(mp, encoding="utf-8") as f:
        m = json.load(f)
    n = apply_to_manifest(m)
    print(f"[apply_to_manifest] {n} block(s) updated in {os.path.relpath(mp)}")

    if args.dry_run:
        print("[dry-run] manifest.json 未写回")
        return 0 if total >= args.threshold else 1

    with open(mp, "w", encoding="utf-8") as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f"[saved] {os.path.relpath(mp)}")
    return 0 if total >= args.threshold else 1


if __name__ == "__main__":
    sys.exit(main())
