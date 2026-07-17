# -*- coding: utf-8 -*-
"""
manifest_builder.py — STM32F10x 教材 manifest.json 组装器

从各章节模块导入页面生成函数，组装完整的 manifest 结构并写入 manifest.json。
运行方式：通过 gen_manifest_main.py 调用 main()，或直接 python manifest_builder.py
"""
import json, os, sys
import importlib.util as _importlib_util

# 将 public/ 目录加入 sys.path
_PUBLIC_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _PUBLIC_DIR not in sys.path:
    sys.path.insert(0, _PUBLIC_DIR)

# 通过 importlib 装载 gen_manifest.py（兼容 chapters/*.py 的 exec 路径）
_gm_spec = _importlib_util.spec_from_file_location(
    "gen_manifest",
    os.path.join(_PUBLIC_DIR, 'gen_manifest.py'),
)
_gm_module = _importlib_util.module_from_spec(_gm_spec)
_gm_spec.loader.exec_module(_gm_module)
build_p1 = _gm_module.build_p1
mk_anim = _gm_module.mk_anim
mk_intro = _gm_module.mk_intro
quiz = _gm_module.quiz
page = _gm_module.page

# 从 manifest 包导入工厂函数
from manifest.factories import build_intro_page, build_extension_page  # noqa: E402
from manifest.quizzes import build_quizzes                             # noqa: E402

# 动态加载章节工厂（失败时回退到硬编码 import）
from manifest.chapter_loader import load_chapter_factories  # noqa: E402

_CHAPTER_FACTORIES = load_chapter_factories(course_id='stm32-f103')

if _CHAPTER_FACTORIES is not None:
    globals().update(_CHAPTER_FACTORIES)
else:
    print('[manifest_builder] ⚠️  chapter_loader 失败，回退硬编码 import',
          file=sys.stderr)
    from manifest.chapters.ch01 import build_p1_goals_page, build_p2_gpio_hal_page  # noqa: E402, F401
    from manifest.chapters.ch02_ch03 import build_p2_pages, build_p3_pages           # noqa: E402, F401
    from manifest.chapters.ch04_ch05 import build_p4_pages, build_p5_pages           # noqa: E402, F401
    from manifest.chapters.ch06_ch07 import build_p6_pages, build_p7_pages           # noqa: E402, F401
    from manifest.chapters.ch08_ch09 import build_p8_pages, build_p9_pages           # noqa: E402, F401
    from manifest.chapters.ch10_ch12 import build_p10_pages, build_p11_pages, build_p12_pages  # noqa: E402, F401


def _safe_apply(manifest, label, patch_fn, ok_msg=None):
    """运行一个 patch 步骤，失败时 stderr 警告但不中断。"""
    try:
        result = patch_fn(manifest)
        if ok_msg is not None:
            line = ok_msg(result)
            if line:
                print(line, file=sys.stderr)
    except Exception as _e:  # noqa: BLE001 — keep behavior 1:1 with old code
        print(f"⚠️  {label} 跳过: {_e}", file=sys.stderr)


def main():
    # 导入章节工厂（extras + worksheets）
    from manifest.chapters.extras import (
        build_ch1_extra_pages, build_ch3_extra_pages,
        build_ch6_extra_pages, build_ch9_extra_pages,
        build_ch12_extra_pages,
    )
    from manifest.chapters.worksheets import (  # noqa: E402, F401
        build_ch3_worksheet, build_ch4_worksheet, build_ch5_worksheet,
        build_ch6_worksheet, build_ch7_worksheet, build_ch9_worksheet,
        build_ch10_worksheet, build_ch11_worksheet, build_ch12_worksheet,
    )

    all_p1  = build_p1()
    p1_goals = build_p1_goals_page()
    all_p2  = build_p2_pages()
    p2_gpio = build_p2_gpio_hal_page()
    all_p3  = build_p3_pages()
    all_p4  = build_p4_pages()
    all_p5  = build_p5_pages()
    all_p6  = build_p6_pages()
    all_p7  = build_p7_pages()
    all_p8  = build_p8_pages()
    all_p9  = build_p9_pages()
    all_p10 = build_p10_pages()
    all_p11 = build_p11_pages()
    all_p12 = build_p12_pages()

    # ── 额外子页面（每节扩充为2~3页）─────────────────────────────
    p1_arch, p1_flow = build_ch1_extra_pages()
    p3_led_code, p3_exti_code = build_ch3_extra_pages()
    (p6_uart_code,) = build_ch6_extra_pages()
    (p9_i2c,) = build_ch9_extra_pages()
    (p12_pid,) = build_ch12_extra_pages()

    # ── 实训工作页（工作手册式范式，政策：教职成〔2026〕1号）─────────────────
    (p3_ws_led,)    = build_ch3_worksheet()
    (p4_ws_timer,)  = build_ch4_worksheet()
    (p5_ws_pwm,)    = build_ch5_worksheet()
    (p6_ws_uart,)   = build_ch6_worksheet()
    (p7_ws_adc,)    = build_ch7_worksheet()
    (p9_ws_env,)    = build_ch9_worksheet()
    (p10_ws_park,)  = build_ch10_worksheet()
    (p11_ws_band,)  = build_ch11_worksheet()
    (p12_ws_pid,)   = build_ch12_worksheet()

    # ── 通用引入页/拓展页（从独立模块导入）────────────────────────────
    from manifest.chapters.intros_extensions import (
        intro_ch3, ext_ch3,
        intro_ch4, ext_ch4,
        intro_ch5, ext_ch5,
        intro_ch6, ext_ch6,
        intro_ch7, ext_ch7,
        intro_ch8, ext_ch8,
        intro_ch9, ext_ch9,
        intro_ch10, ext_ch10,
        intro_ch11, ext_ch11,
        intro_ch12, ext_ch12
    )
    from manifest.chapters.course_metadata import get_achievements, get_ability_map


    # ── 章节目录组装 ──────────────────────────────────────────────────
    chapters = [
        # ── 项目1：认识单片机 ────────────────────────────────────────────────
        {
            "id": "ch1", "title": "认识单片机",
            "overview": "单片机基本概念、发展历程、国产MCU崛起、硬件结构与开发流程",
            "pagesRange": "P6~P16",
            "sections": [
                # 任务1：导入+知识链接（概念+历史+架构）
                {"id": "ch1-t1", "title": "任务1 认识单片机基本概念",
                 "pages": [p1_goals, all_p1[0], p1_arch]},
                # 任务2：知识链接（硬件结构+开发流程）
                {"id": "ch1-t2", "title": "任务2 单片机典型结构与开发流程",
                 "pages": [all_p1[1], p1_flow]},
            ],
        },
        # ── 项目2：STM32F1系列MCU与开发流程 ──────────────────────────────────
        {
            "id": "ch2", "title": "认识STM32F1系列MCU及开发流程",
            "overview": "CubeIDE环境搭建、CubeMX图形化配置、GPIO工作模式与HAL库编程、C语言技巧",
            "pagesRange": "P17~P50",
            "sections": [
                # 任务1：导入+开发环境配置
                {"id": "ch2-t1", "title": "任务1 搭建STM32开发环境",
                 "pages": [all_p2[0], all_p2[1], p2_gpio]},
            ],
        },
        # ── 项目3：GPIO应用 ───────────────────────────────────────────────────
        {
            "id": "ch3", "title": "GPIO应用",
            "overview": "LED驱动电路、流水灯、呼吸灯、按键扫描、外部中断EXTI与NVIC优先级",
            "pagesRange": "P51~P84",
            "sections": [
                # 任务1：导入+LED灯控制
                {"id": "ch3-t1", "title": "任务1 LED闪烁与流水灯",
                 "pages": [intro_ch3, all_p3[0], p3_led_code, p3_ws_led]},
                # 任务2：按键与中断+课后练习
                {"id": "ch3-t2", "title": "任务2 按键扫描与外部中断",
                 "pages": [all_p3[1], p3_exti_code, ext_ch3]},
            ],
        },
        # ── 项目4：定时器应用 ─────────────────────────────────────────────────
        {
            "id": "ch4", "title": "定时器应用",
            "overview": "通用定时器原理（PSC/ARR/CNT）、溢出中断、数码管动态扫描、精确计时",
            "pagesRange": "P85~P93",
            "sections": [
                # 任务1：定时器中断配置
                {"id": "ch4-t1", "title": "任务1 定时器中断与数码管控制",
                 "pages": [intro_ch4, *all_p4]},
                # 课后练习
                {"id": "ch4-t2", "title": "课后练习",
                 "pages": [p4_ws_timer, ext_ch4]},
            ],
        },
        # ── 项目5：PWM输出 ────────────────────────────────────────────────────
        {
            "id": "ch5", "title": "PWM输出",
            "overview": "PWM波形原理、占空比调节、LED呼吸灯效果、SG90舵机控制",
            "pagesRange": "P94~P103",
            "sections": [
                # 任务1：PWM波形与呼吸灯
                {"id": "ch5-t1", "title": "任务1 PWM波形输出与呼吸灯",
                 "pages": [intro_ch5, *all_p5]},
                # 课后练习
                {"id": "ch5-t2", "title": "课后练习",
                 "pages": [p5_ws_pwm, ext_ch5]},
            ],
        },
        # ── 项目6：串口通信实验 ───────────────────────────────────────────────
        {
            "id": "ch6", "title": "串口通信实验",
            "overview": "UART协议帧格式、波特率配置、轮询收发、中断接收与printf重定向",
            "pagesRange": "P104~P112",
            "sections": [
                # 任务1：基础收发
                {"id": "ch6-t1", "title": "任务1 UART基础收发与printf重定向",
                 "pages": [all_p6[0], p6_uart_code]},
                # 任务2：中断接收
                {"id": "ch6-t2", "title": "任务2 串口中断接收与数据处理",
                 "pages": [all_p6[1], p6_ws_uart]},
                # 课后练习
                {"id": "ch6-t3", "title": "课后练习",
                 "pages": [ext_ch6]},
            ],
        },
        # ── 项目7：ADC实验 ────────────────────────────────────────────────────
        {
            "id": "ch7", "title": "ADC实验",
            "overview": "ADC采样定理、12位分辨率、光敏电阻分压电路、多通道DMA扫描",
            "pagesRange": "P113~P124",
            "sections": [
                # 任务1：ADC采样
                {"id": "ch7-t1", "title": "任务1 ADC采样与光照强度检测",
                 "pages": [intro_ch7, *all_p7]},
                # 课后练习
                {"id": "ch7-t2", "title": "课后练习",
                 "pages": [p7_ws_adc, ext_ch7]},
            ],
        },
        # ── 项目8：DAC实验 ────────────────────────────────────────────────────
        {
            "id": "ch8", "title": "DAC实验",
            "overview": "DAC输出原理、固定电压输出、DMA+定时器周期波形生成",
            "pagesRange": "P125~P138",
            "sections": [
                # 任务1：DAC输出与波形生成
                {"id": "ch8-t1", "title": "任务1 DAC输出与正弦波形生成",
                 "pages": [intro_ch8, *all_p8]},
                # 课后练习
                {"id": "ch8-t2", "title": "课后练习",
                 "pages": [ext_ch8]},
            ],
        },
        # ── 项目9：环境监测系统 ───────────────────────────────────────────────
        {
            "id": "ch9", "title": "环境监测系统",
            "overview": "MQ-2烟雾/BH1750光照/HDC1080温湿度多传感器融合、I2C协议",
            "pagesRange": "P139~P158",
            "sections": [
                # 任务1：多传感器数据采集
                {"id": "ch9-t1", "title": "任务1 多传感器数据采集实验",
                 "pages": [intro_ch9, *all_p9, p9_i2c]},
                # 课后练习与拓展
                {"id": "ch9-t2", "title": "课后练习与拓展",
                 "pages": [p9_ws_env, ext_ch9]},
            ],
        },
        # ── 项目10：无人停车场 ────────────────────────────────────────────────
        {
            "id": "ch10", "title": "无人停车场",
            "overview": "SPI协议、HC-SR04超声波测距、MFRC522 NFC识别、有限状态机设计",
            "pagesRange": "P159~P172",
            "sections": [
                # 任务1：传感器驱动与测距
                {"id": "ch10-t1", "title": "任务1 超声波测距与NFC识别",
                 "pages": [intro_ch10, *all_p10]},
                # 课后练习与拓展
                {"id": "ch10-t2", "title": "课后练习与拓展",
                 "pages": [p10_ws_park, ext_ch10]},
            ],
        },
        # ── 项目11：运动手环 ──────────────────────────────────────────────────
        {
            "id": "ch11", "title": "运动手环",
            "overview": "LSM6DS3六轴IMU、PPG光电容积、计步算法、STM32低功耗Stop模式",
            "pagesRange": "P173~P182",
            "sections": [
                # 任务1：IMU与PPG数据采集
                {"id": "ch11-t1", "title": "任务1 IMU与PPG数据采集",
                 "pages": [intro_ch11, *all_p11]},
                # 课后练习与拓展
                {"id": "ch11-t2", "title": "课后练习与拓展",
                 "pages": [p11_ws_band, ext_ch11]},
            ],
        },
        # ── 项目12：追光系统 ──────────────────────────────────────────────────
        {
            "id": "ch12", "title": "追光系统",
            "overview": "四象限光敏传感器、SG90舵机PWM、PID控制器设计与参数整定",
            "pagesRange": "P183~P193",
            "sections": [
                # 任务1：传感器与舵机基础控制
                {"id": "ch12-t1", "title": "任务1 传感器与舵机控制",
                 "pages": [intro_ch12, *all_p12]},
                # 任务2：PID控制器实现+拓展
                {"id": "ch12-t2", "title": "任务2 PID控制器实现与调参",
                 "pages": [p12_pid, ext_ch12]},
                # 课后练习
                {"id": "ch12-t3", "title": "课后练习",
                 "pages": [p12_ws_pid]},
            ],
        },
    ]

    manifest = {
        "manifestVersion": 4,
        "courseId": "stm32f10x-complete",
        "version": "1.0.0-release",
        "title": "嵌入式系统开发与应用（STM32F10x）",
        "subtitle": "基于ARM Cortex-M3·12个项目·从基础到综合",
        "generatedAt": "2026-05-15T00:00:00.000Z",
        "bookInfo": {
            "totalProjects": 12,
            "totalPages": "194页",
            "reference": "stm32f103.pdf",
            "difficulty": "初学者到中级",
        },
        "theme": {
            "primary": "#0E7C4A",
            "variant": "textbook",
            "brandName": "DGBook",
            "brandSubtitle": "嵌入式数字教材平台"
        },
        "aiTutor": {
            "name": "课程助教",
            "subtitle": "随堂问答 · 课堂伙伴",
            "avatarEmoji": "📘",
            "welcome": "你好，我是这门 STM32F10x 课程的助教，12 个项目里的知识点都可以问我——从 GPIO 到 PID，从原理到代码，随时开口。"
        },
        "chapters": chapters,
        "quizzes": build_quizzes(),
        "achievements": get_achievements(),
        "abilityMap": get_ability_map(),
    }
    # ── 后处理：将SVG图形块注入到各页面 ────────────────────────────
    try:
        import importlib, importlib.util
        _svg_path = os.path.join(_PUBLIC_DIR, 'gen_svg.py')
        _spec = importlib.util.spec_from_file_location("gen_svg", _svg_path)
        _svg_mod = importlib.util.module_from_spec(_spec)
        _spec.loader.exec_module(_svg_mod)

        # 为关键页面注入SVG图形块
        # Phase G3 · p3-led-blink 升级为 graphics schema v2 示范：
        #   - nodes[]：可寻址 SVG 元素 + label/description（朗读 + AI 引用）
        #   - commentary.stepScripts：与节点同步的 4 段讲解
        _svg_map = {
            "p3-led-blink": [{
                "id": "p3b-led-svg", "kind": "graphics",
                "src": "inline:" + _svg_mod.svg_led_circuit(),
                "format": "svg", "caption": "LED限流电阻驱动电路（PA5→220Ω→LED→GND）",
                "nodes": [
                    {"id": "gpio",  "selector": "#led-gpio", "label": "GPIO 输出引脚",
                     "description": "GPIO 引脚配置为推挽输出后，可在 0V 与 3.3V 之间切换，提供约 6mA 的驱动电流。"},
                    {"id": "r",     "selector": "#led-r",    "label": "限流电阻 220Ω",
                     "description": "限流电阻把 LED 工作电流压到 6mA 量级，保护 LED 与 GPIO 引脚不被烧毁。"},
                    {"id": "led",   "selector": "#led-led",  "label": "LED 发光二极管",
                     "description": "LED 是单向器件，长脚为正极、短脚为负极，电流从 GPIO 经限流电阻流入正极后才发光。"},
                    {"id": "gnd",   "selector": "#led-gnd",  "label": "GND 地",
                     "description": "电流必须形成闭环，最终回到 GND 才能点亮 LED；否则即使 GPIO 输出高电平也不会发光。"},
                ],
                "commentary": {
                    "stepScripts": [
                        "GPIO 引脚配置为推挽输出后,可在 0V 与 3.3V 之间切换,这是 LED 闪烁的电源开关。",
                        "电流从 GPIO 流出,首先经过限流电阻把工作电流压到大约 6 毫安,这一步保护 LED 和引脚。",
                        "电流接着从 LED 正极流入、负极流出,二极管被点亮。",
                        "最后电流通过 GND 形成闭环,缺少回路 LED 是不会亮的。",
                    ]
                },
            }],
            "p4-timer": [{"id": "p4-timer-svg", "kind": "graphics",
                "src": "inline:" + _svg_mod.svg_timer_principle(),
                "format": "svg", "caption": "定时器工作原理：PSC分频→CNT计数→ARR溢出中断"}],
            "p5-pwm": [{"id": "p5-pwm-svg", "kind": "graphics",
                "src": "inline:" + _svg_mod.svg_pwm_waveform(),
                "format": "svg", "caption": "PWM波形·不同占空比对应不同等效电压"}],
            "p6-uart": [{"id": "p6-uart-svg", "kind": "graphics",
                "src": "inline:" + _svg_mod.svg_uart_frame(),
                "format": "svg", "caption": "UART数据帧格式：1位起始+8位数据(LSB先)+1位停止"}],
            "p7-adc": [{"id": "p7-adc-svg", "kind": "graphics",
                "src": "inline:" + _svg_mod.svg_adc_process(),
                "format": "svg", "caption": "ADC模数转换过程（12位逐次逼近型）"}],
            "p9-env": [{"id": "p9-i2c-svg", "kind": "graphics",
                "src": "inline:" + _svg_mod.svg_i2c_protocol(),
                "format": "svg", "caption": "I2C通信时序图（START→地址+R/W→ACK→数据→STOP）"}],
            "p10-parking": [
                {"id": "p10-hcsr04-svg", "kind": "graphics",
                 "src": "inline:" + _svg_mod.svg_hcsr04_timing(),
                 "format": "svg", "caption": "HC-SR04超声波测距时序：10μs触发→ECHO高电平时间→距离计算"},
                {"id": "p10-spi-svg", "kind": "graphics",
                 "src": "inline:" + _svg_mod.svg_spi_connection(),
                 "format": "svg", "caption": "SPI四线连接图：MOSI/MISO/SCK/CS（主从设备）"},
                {"id": "p10-state-svg", "kind": "graphics",
                 "src": "inline:" + _svg_mod.svg_parking_state_machine(),
                 "format": "svg", "caption": "无人停车场状态机：IDLE→DETECT→NFC→OPEN→CLOSE"},
            ],
            "p11-band": [{"id": "p11-step-svg", "kind": "graphics",
                "src": "inline:" + _svg_mod.svg_step_counter_algo(),
                "format": "svg", "caption": "峰值检测计步算法流程：读加速度→合力→峰值检测→防抖→计步"}],
            "p12-suntrack": [{"id": "p12-pid-svg", "kind": "graphics",
                "src": "inline:" + _svg_mod.svg_pid_block(),
                "format": "svg", "caption": "PID闭环控制框图：目标值→误差→PID控制器→被控对象→反馈"}],
            "p2-gpio-hal": [],  # 已在build函数中内联
        }
        # 遍历所有页面，在正文text块后插入SVG
        for ch in manifest["chapters"]:
            for s in ch["sections"]:
                for p in s["pages"]:
                    pid = p["id"]
                    if pid in _svg_map and _svg_map[pid]:
                        # 在第一个text块后插入SVG
                        insert_pos = 1
                        for i, blk in enumerate(p["blocks"]):
                            if blk["kind"] == "text":
                                insert_pos = i + 1
                                break
                        for j, svg_blk in enumerate(_svg_map[pid]):
                            p["blocks"].insert(insert_pos + j, svg_blk)
        import sys as _sys2; print("✅ SVG图形块注入完成", file=_sys2.stderr)
    except Exception as _e:
        import sys as _sys3; print(f"⚠️  SVG注入跳过: {_e}", file=_sys3.stderr)

    # ── 路径 B：用 final_animation_blocks.json 覆盖 17 个 final 动画 ──
    # 数据源由 scripts/_export_final_animation_blocks.py 维护，
    # 让 gen_manifest_main.py 可复现 17/17 final，避免 cicd 把验证好的动画丢失。
    from manifest.final_animations import apply_final_animations
    _safe_apply(
        manifest, "final animations 覆盖",
        apply_final_animations,
    )

    # ── 路径 B：digital-human FAQ 后处理（删模板 + 改写 P 级 FAQ） ──
    from manifest.followup_patches import apply_followup_patches
    _safe_apply(
        manifest, "followup patches",
        apply_followup_patches,
        ok_msg=lambda r: f"📝 followup patches: 删除 {r[0]} 条模板 / 改写 {r[1]} 条 FAQ",
    )

    # ── 路径 C：code-flow patch（Phase 4） ──
    # 把 materials/<course>/_templates/**/*.extras.yaml 中
    # kind: code-flow-patch 的 entry 注入到 target_id 指向的 code block，
    # 让 code block 获得可选的 flow（Mermaid 流程图）+ commentary（stepScripts）字段。
    from manifest.codeflow_patches import apply_codeflow_patches
    _safe_apply(
        manifest, "codeflow patches",
        apply_codeflow_patches,
        ok_msg=lambda r: f"🔀 codeflow patches: 注入 {r[0]} 个 code block / 跳过 {r[1]}",
    )

    # ── 路径 D：text-commentary patch（2 · 数据补全工具链） ──
    # 把 materials/<course>/_templates/**/*.extras.yaml 中
    # kind: text-commentary-patch 的 entry 注入到 target_id 指向的任意 SPEAKABLE block，
    # 把哑巴 block 拉回朗读链路（commentary.script / stepScripts）。
    # 保守不覆盖：已有非空 stepScripts / script 的 block 不动，保护 final_animation
    # 与 codeflow_patches 已注入的 step 同步数据。
    from manifest.text_commentary_patches import apply_text_commentary_patches
    _safe_apply(
        manifest, "text commentary patches",
        apply_text_commentary_patches,
        ok_msg=lambda r: f"💬 text commentary patches: 注入 {r[0]} / 跳过 {r[1]} / 忽略 {r[2]}",
    )

    # ── 路径 E：manim / widget 持久化注入（Phase 7） ──
    # 扫描 materials/<course>/manim/<ch>/<stem>.meta.yaml +
    # materials/<course>/widgets/<ch>/<stem>.meta.yaml，构造 animation/widget
    # block 并按 pageHint 注入对应 page。这是替代 scripts/_phase_inject_manim_widget_preview.py
    # 的"正路"接入：完整跑 manifest_builder.py 不再清掉 manim/widget block。
    # 红线：避开 17 个 final 动画 id；缺 pageHint / TTS 必填字段则 warning + 跳过。
    from manifest.manim_widget_patches import apply_manim_widget_patches
    _safe_apply(
        manifest, "manim/widget patches",
        apply_manim_widget_patches,
        ok_msg=lambda r: f"🎞️ manim/widget patches: manim={r[0]} / widget={r[1]} / skipped={r[2]}",
    )

    import sys
    total_pages = sum(len(s["pages"]) for ch in chapters for s in ch["sections"])
    total_blocks = sum(len(p["blocks"]) for ch in chapters for s in ch["sections"] for p in s["pages"])
    print(f"📚 章节数: {len(chapters)}", file=sys.stderr)
    print(f"📄 总页数: {total_pages}", file=sys.stderr)
    print(f"🧩 总积木数: {total_blocks}", file=sys.stderr)

    out_path = os.path.join(_PUBLIC_DIR, 'manifest.json')
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    size_kb = os.path.getsize(out_path) // 1024
    print(f"✅ 已写入 {out_path} ({size_kb} KB)", file=sys.stderr)


if __name__ == '__main__':
    main()
