# -*- coding: utf-8 -*-
"""OpenMAIC-style animation renderer: shared, safe-layout, platform-ready.

分步叙事版：每个 step 只点亮相应的 SVG 元素组 + step 卡片 + 公式片段，
父页面通过 `postMessage({type:'dgb-step', step})` 驱动；
iframe 通过 `dgb-steps-total` 上报步骤数，`dgb-step-change` 回传当前步，
父页面的数字人据此同步朗读对应 step 的讲稿。
"""
from __future__ import annotations
import html, json, re

def esc(v): return html.escape(str(v or ""), quote=True)
def compact(v): return re.sub(r"\s+", " ", str(v or "")).strip()


def visual(kind: str) -> str:
    """各 kind 的 SVG；关键结构加 data-step 以便按步点亮。
    说明：step 从 1 开始；被命中的 data-step<=当前 step 的元素全量显示，其它半透明。
    """
    if kind == "led":
        return (
            '<svg viewBox="0 0 980 410" class="svg">'
            '<defs><filter id="glow"><feGaussianBlur stdDeviation="10" result="b"/>'
            '<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>'
            # Step1: GPIO 输出
            '<g data-step="1">'
            '<rect x="65" y="130" width="150" height="150" rx="28" class="chip"/>'
            '<text x="140" y="195" class="wtext">PA5</text>'
            '<text x="140" y="235" class="wsmall">3.3V OUT</text>'
            '</g>'
            # Step2: 导线到电阻
            '<g data-step="2">'
            '<path d="M90 205 H310" class="wire"/>'
            '<rect x="310" y="155" width="160" height="100" rx="24" class="box purple"/>'
            '<path d="M335 205 l18 -35 l36 70 l36 -70 l36 70" class="res"/>'
            '<text x="390" y="300" class="label">限流电阻 220Ω</text>'
            '<circle class="dot p1" cy="205" r="13"/>'
            '</g>'
            # Step3: LED 正向压降
            '<g data-step="3">'
            '<path d="M470 205 H650" class="wire"/>'
            '<circle cx="710" cy="205" r="78" class="led" filter="url(#glow)"/>'
            '<path d="M680 235 L740 175 M710 175 L740 205" class="diode"/>'
            '<text x="710" y="320" class="label">LED Vf≈2.0V</text>'
            '<circle class="dot p2" cy="205" r="13"/>'
            '</g>'
            # Step4: 电流公式 + 回 GND
            '<g data-step="4">'
            '<path d="M790 205 H900" class="wire"/>'
            '<g class="ground"><path d="M900 205 v58 M865 263 h70 M878 283 h44 M890 303 h20"/></g>'
            '<text x="492" y="80" class="formula">I = (Vgpio − Vf) / R ≈ 5.9mA</text>'
            '<circle class="dot p3" cy="205" r="13"/>'
            '</g>'
            # Step5: 流水灯 — 多 GPIO 轮询标注
            '<g data-step="5">'
            '<text x="492" y="370" class="label">多 GPIO 轮流建立安全电流路径 → 流水灯</text>'
            '</g>'
            '</svg>'
        )
    if kind == "timer":
        return (
            '<svg viewBox="0 0 980 410" class="svg">'
            '<g data-step="1">'
            '<text x="60" y="60" class="label">CLK 72MHz</text>'
            '<path d="M60 105 C120 60 180 150 240 105 S360 105 420 105" class="wave"/>'
            '</g>'
            '<g data-step="2">'
            '<rect x="470" y="45" width="165" height="100" rx="22" class="box blue"/>'
            '<text x="552" y="105" class="wtext">PSC=71</text>'
            '<path d="M650 95 H760" class="wire"/>'
            '<rect x="760" y="45" width="165" height="100" rx="22" class="box green"/>'
            '<text x="842" y="105" class="wtext">1MHz</text>'
            '</g>'
            '<g data-step="3">'
            '<polyline points="80,335 80,275 230,275 230,335 380,335 380,275 530,275 530,335 680,335 680,275 830,275 830,335" class="cnt"/>'
            '<line x1="80" y1="335" x2="900" y2="335" class="axis"/>'
            '<line x1="80" y1="275" x2="900" y2="275" class="axis light"/>'
            '<text x="70" y="255" class="label">ARR=999 / CNT</text>'
            '</g>'
            '<g data-step="4">'
            '<circle cx="830" cy="275" r="20" class="irq"/>'
            '<text x="790" y="225" class="formula">Overflow → UIF 置位 → IRQ</text>'
            '</g>'
            '<g data-step="5">'
            '<text x="492" y="380" class="label">HAL_TIM_PeriodElapsedCallback → 周期任务</text>'
            '</g>'
            '</svg>'
        )
    if kind == "pwm":
        return (
            '<svg viewBox="0 0 980 410" class="svg">'
            '<g data-step="1">'
            '<line x1="70" y1="310" x2="910" y2="310" class="axis"/>'
            '<polyline points="70,310 70,120 190,120 190,310 310,310 310,120 430,120 430,310 550,310 550,120 670,120 670,310 790,310 790,120 910,120" class="pwm"/>'
            '</g>'
            '<g data-step="2">'
            '<text x="120" y="95" class="label">高电平时间 Ton = CCR 控制</text>'
            '<text x="320" y="355" class="label">周期 T = ARR+1</text>'
            '</g>'
            '<g data-step="3">'
            '<line x1="70" y1="215" x2="910" y2="215" class="avg"/>'
            '<text x="720" y="200" class="formula">Vavg = D × Vmax</text>'
            '</g>'
            '<g data-step="4">'
            '<circle cx="805" cy="115" r="60" class="led breath"/>'
            '<text x="805" y="235" class="label">LED 视觉暂留 → 连续亮度</text>'
            '</g>'
            '<g data-step="5">'
            '<rect x="80" y="38" width="300" height="48" rx="20" class="box amber"/>'
            '<text x="230" y="70" class="wtext">CCR 缓慢递增递减 → 呼吸灯</text>'
            '</g>'
            '</svg>'
        )
    # generic: 每个节点对应一步
    return (
        '<svg viewBox="0 0 980 410" class="svg">'
        '<g data-step="1"><path d="M90 210 H300" class="wire"/><circle cx="170" cy="210" r="70" class="node"/><text x="170" y="215" class="wtext">概念</text></g>'
        '<g data-step="2"><path d="M240 210 H500" class="wire"/><circle cx="420" cy="210" r="70" class="node"/><text x="420" y="215" class="wtext">参数</text></g>'
        '<g data-step="3"><path d="M490 210 H750" class="wire"/><circle cx="670" cy="210" r="70" class="node"/><text x="670" y="215" class="wtext">实验</text></g>'
        '<g data-step="4"><text x="492" y="350" class="formula">概念 → 参数 → 实验</text></g>'
        '<g data-step="5"><text x="492" y="390" class="label">课堂动手验证并总结结论</text></g>'
        '</svg>'
    )
