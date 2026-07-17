# -*- coding: utf-8 -*-
"""
svgs.py — SVG 图形与动画生成的统一入口

从 gen_svg.py 导入各类电路/时序/框图 SVG，
从 gen_manifest.py 导入 mk_anim/mk_intro 动画 HTML 生成器。

其他模块应通过 `from manifest.svgs import xxx` 引用，而非直接 exec gen_svg.py。
"""
import sys, os

# 将 public 目录加入路径，以便导入同级的 gen_svg.py / gen_manifest.py
_PUBLIC_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _PUBLIC_DIR not in sys.path:
    sys.path.insert(0, _PUBLIC_DIR)


def _load_gen_svg():
    """Iter-61 方案 B 解耦：import gen_svg（消除 exec __file__ 缺失问题）"""
    import gen_svg
    return vars(gen_svg)


def _load_gen_manifest():
    """Iter-61 方案 B 解耦：import gen_manifest"""
    import gen_manifest
    return vars(gen_manifest)


# ── 延迟加载（避免启动时耗时）──────────────────────────────────────────
_svg_ns = None
_anim_ns = None


def _svg():
    global _svg_ns
    if _svg_ns is None:
        _svg_ns = _load_gen_svg()
    return _svg_ns


def _anim():
    global _anim_ns
    if _anim_ns is None:
        _anim_ns = _load_gen_manifest()
    return _anim_ns


# ── 公共接口 ────────────────────────────────────────────────────────────

def svg_led_circuit():
    """LED限流电阻电路图 SVG"""
    return _svg()['svg_led_circuit']()


def svg_gpio_modes():
    """GPIO 8种工作模式对比图"""
    return _svg()['svg_gpio_modes']()


def svg_timer_structure():
    """定时器内部结构图"""
    return _svg()['svg_timer_structure']()


def svg_pwm_waveform():
    """PWM波形图"""
    return _svg()['svg_pwm_waveform']()


def svg_uart_frame():
    """UART数据帧格式图"""
    return _svg()['svg_uart_frame']()


def svg_adc_sampling():
    """ADC采样原理图"""
    return _svg()['svg_adc_sampling']()


def svg_i2c_waveform():
    """I2C时序图"""
    return _svg().get('svg_i2c_waveform', lambda: '')()


def svg_pid_block():
    """PID控制框图"""
    return _svg().get('svg_pid_block', lambda: '')()


def mk_anim(topic, scenes):
    """生成内联HTML动画（多帧轮播）"""
    return _anim()['mk_anim'](topic, scenes)


def mk_intro(title, subtitle, bg="#667eea,#764ba2"):
    """生成测验开场动画 HTML"""
    return _anim()['mk_intro'](title, subtitle, bg)
