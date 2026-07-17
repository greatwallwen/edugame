# -*- coding: utf-8 -*-
"""
gen_svg.py — SVG 图形生成器（Iter-61 重建 · 方案 B 解耦）

历史背景：本文件曾退役删除，导致 chapters/*.py 的 `from gen_svg import ...`
和 svgs.py 的 `exec(gen_svg.py)` 全部 FileNotFoundError，阻断全新构建。

重建策略（保证与生产 manifest byte-equal）：
  13 个 svg_* 函数的产物已固化在 _svg_baseline.json（从生产 manifest 的
  graphics block src 提取）。本模块读取该数据，每个函数返回对应 SVG 字符串。

调用方：
  - chapters/ch01.py: svg_stm32_block / svg_gpio_modes
  - manifest_builder.py: 其余 11 个（svg_led_circuit / svg_pwm_waveform 等）
  - svgs.py: 统一转发入口（懒加载）
"""
import json
import os

_HERE = os.path.dirname(os.path.abspath(__file__))
# _svg_baseline.json 与 gen_svg.py 同在 public/ 还是 manifest/？
# 放 manifest/ 目录（与数据脚本同级），public/ 也兜底查找。
_CANDIDATES = [
    os.path.join(_HERE, 'manifest', '_svg_baseline.json'),
    os.path.join(_HERE, '_svg_baseline.json'),
]


def _load():
    for p in _CANDIDATES:
        if os.path.isfile(p):
            with open(p, encoding='utf-8') as f:
                return json.load(f)
    raise FileNotFoundError(f'_svg_baseline.json not found in {_CANDIDATES}')


_DATA = _load()


def _make(name):
    def fn():
        return _DATA[name]
    fn.__name__ = name
    return fn


# 13 个 SVG 生成函数（数据驱动，名称与基线键一致）
svg_stm32_block = _make('svg_stm32_block')
svg_gpio_modes = _make('svg_gpio_modes')
svg_led_circuit = _make('svg_led_circuit')
svg_pwm_waveform = _make('svg_pwm_waveform')
svg_timer_principle = _make('svg_timer_principle')
svg_uart_frame = _make('svg_uart_frame')
svg_adc_process = _make('svg_adc_process')
svg_i2c_protocol = _make('svg_i2c_protocol')
svg_hcsr04_timing = _make('svg_hcsr04_timing')
svg_spi_connection = _make('svg_spi_connection')
svg_parking_state_machine = _make('svg_parking_state_machine')
svg_step_counter_algo = _make('svg_step_counter_algo')
svg_pid_block = _make('svg_pid_block')
