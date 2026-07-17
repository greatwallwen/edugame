#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
inject_sensor_animations.py — 补充传感器/协议页面缺失的动画

优先级：
1. p9-i2c-proto: I2C 协议时序动画（最急迫）
2. p3-key-int: EXTI 中断触发流程动画
3. p1-history: 单片机发展历程时间轴动画
4. p2-ide: CubeMX 配置流程动画

幂等：按 block id 去重。
"""
import json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'apps', 'player', 'public'))
MF = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

from manifest.blocks import mermaid_block


def _rich_anim_block(bid, topic, steps):
    """生成真正的富 SVG 动画（不依赖 _anim_baseline.json 缓存）"""
    steps_html = ""
    steps_js_data = "["
    dots_html = ""
    for i, s in enumerate(steps):
        icon = s.get("icon", "📌")
        title = s.get("t", "")
        desc = s.get("d", "")
        steps_html += f'<li data-k="{i}"><b>{icon}</b><span><strong>{title}</strong><br/>{desc}</span></li>\n'
        steps_js_data += f'"{desc}",'
        dots_html += f'<i></i>'
    steps_js_data += "]"

    html = f'''<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8">
<title>{topic}</title>
<style>
*{{box-sizing:border-box}}
body{{margin:0;overflow:hidden;background:#FBF7EC;font-family:"PingFang SC","Microsoft YaHei",sans-serif;color:#1F2937}}
#viewport{{position:fixed;inset:0;overflow:hidden}}
#stage{{position:absolute;width:1920px;height:1080px;left:0;top:0;transform-origin:0 0;background:linear-gradient(180deg,#fff,#FBF7EC);border-radius:28px;box-shadow:0 24px 80px rgba(14,124,74,.14);overflow:hidden;border:1px solid #D9E2D1}}
h1{{position:absolute;left:76px;top:40px;font-size:48px;color:#0A5132;margin:0}}
.sub{{position:absolute;left:76px;top:100px;font-size:20px;color:#4B5563}}
ol{{position:absolute;left:76px;top:160px;right:76px;margin:0;padding:0;display:grid;gap:16px;list-style:none}}
li{{display:flex;gap:16px;align-items:flex-start;padding:20px;border-radius:20px;background:#fff;border:1px solid #D9E2D1;font-size:18px;line-height:1.4;color:#4B5563;opacity:.3;transition:.3s}}
li b{{min-width:40px;height:40px;border-radius:14px;background:#C8E4D0;color:#0A5132;display:grid;place-items:center;font-size:24px}}
li.active{{opacity:1;border-color:#0E7C4A;box-shadow:0 12px 32px rgba(14,124,74,.18);transform:translateX(-6px)}}
li.done{{opacity:.7}}
.dots{{position:absolute;right:76px;top:50px;display:flex;gap:10px}}
.dots i{{width:12px;height:12px;border-radius:50%;background:#D9E2D1;transition:.25s}}
.dots i.active{{background:#0E7C4A;transform:scale(1.4)}}
.dots i.done{{background:#10915A}}
.caption{{position:absolute;left:76px;right:76px;bottom:40px;text-align:center;padding:16px 24px;border-radius:20px;background:rgba(255,255,255,.85);border:1px solid #D9E2D1}}
#cn{{font-size:26px;font-weight:800;color:#0A5132}}
</style></head><body>
<div id="viewport"><main id="stage">
<div class="dots">{dots_html}</div>
<h1>{topic}</h1>
<div class="sub">逐步演示 · 共 {len(steps)} 步</div>
<ol>{steps_html}</ol>
<footer class="caption"><div id="cn"></div></footer>
</main></div>
<script>
const steps={steps_js_data};
const total=steps.length;
function fit(){{const s=Math.max(.18,innerWidth/1920);stage.style.transform=`scale(${{s}})`;stage.style.transformOrigin='top left';const ch=Math.min(1080,Math.max(220,1080));parent.postMessage({{type:'dgb-iframe-height',height:Math.ceil(ch*s)}},'*')}}
addEventListener('resize',fit);
let step=0;
function render(i){{
 step=Math.max(0,Math.min(total-1,i));
 document.querySelectorAll('li[data-k]').forEach(el=>{{const k=Number(el.dataset.k);el.classList.toggle('active',k===step);el.classList.toggle('done',k<step)}});
 document.querySelectorAll('.dots i').forEach((el,k)=>{{el.classList.toggle('active',k===step);el.classList.toggle('done',k<step)}});
 cn.textContent=steps[step]||'';
 parent.postMessage({{type:'dgb-step-change',step,total}},'*');setTimeout(fit,40)
}}
addEventListener('message',e=>{{
 const d=e.data||{{}};
 if(d.type==='dgb-step'){{render(d.step|0);return}}
 if(d.type==='dgb-reset'||d.type==='dgb-anim-finalize'){{render(0);return}}
}});
fit();
parent.postMessage({{type:'dgb-steps-total',total}},'*');
render(0);
</script></body></html>'''
    return {
        "id": bid, "kind": "animation",
        "src": f"inline:{html}",
        "format": "html-svg",
        "metadata": {
            "topic": topic,
            "duration": len(steps) * 5,
            "teacher": {
                "script": f"这段动画讲的是「{topic}」",
                "stepScripts": [s.get("d", "") for s in steps],
                "voice": "Cherry",
                "autoPlay": False,
            }
        }
    }

ANIMATIONS = [
    # p3-led-blink: LED 闪烁与流水灯原理（新增）
    ("p3-led-blink", "p3-led-blink-anim", _rich_anim_block("p3-led-blink-anim", "3.1 LED闪烁与流水灯", [
        {"icon": "💡", "t": "Step1：理解 LED 灯珠结构",
         "d": "LED 是单向导电元件，长脚为正极，短脚为负极，需要限流电阻保护"},
        {"icon": "⚡", "t": "Step2：GPIO 推挽输出驱动",
         "d": "GPIO 配置为推挽输出模式，输出高电平点亮 LED，输出低电平熄灭"},
        {"icon": "🔄", "t": "Step3：延时翻转实现闪烁",
         "d": "while(1) 循环中不断翻转 GPIO 电平，中间加入 HAL_Delay() 延时"},
        {"icon": "🌊", "t": "Step4：流水灯逻辑扩展",
         "d": "依次点亮 LED1→LED2→LED3...循环，形成流水效果"},
    ])),

    # p4-timer: 定时器原理与应用（新增）
    ("p4-timer", "p4-timer-anim", _rich_anim_block("p4-timer-anim", "4.1 定时器原理与应用", [
        {"icon": "⏱️", "t": "Step1：定时器本质是计数器",
         "d": "CNT 寄存器从 0 开始递增，每个时钟周期 +1，达到 ARR 值时溢出"},
        {"icon": "🎚️", "t": "Step2：PSC 预分频器",
         "d": "将 72MHz 系统时钟分频，PSC=71 时计数频率=72MHz/72=1MHz"},
        {"icon": "🔔", "t": "Step3：ARR 自动重装载",
         "d": "ARR=999 时，计数 1000 次（0~999）后溢出，产生更新中断"},
        {"icon": "💻", "t": "Step4：中断回调函数",
         "d": "溢出时进入 HAL_TIM_PeriodElapsedCallback()，执行用户代码"},
    ])),

    # p5-pwm: PWM 输出与 LED 呼吸灯（新增）
    ("p5-pwm", "p5-pwm-anim", _rich_anim_block("p5-pwm-anim", "5.1 PWM输出与LED呼吸灯", [
        {"icon": "📊", "t": "Step1：PWM 占空比概念",
         "d": "高电平时间 / 周期 = 占空比，占空比越大，LED 平均亮度越高"},
        {"icon": "⚙️", "t": "Step2：CCR 寄存器控制占空比",
         "d": "TIMx_CCR 值越大，占空比越大（CCR/ARR = 占空比百分比）"},
        {"icon": "🌬️", "t": "Step3：渐变实现呼吸效果",
         "d": "循环递增 CCR（0→ARR）LED 渐亮，递减（ARR→0）LED 渐暗"},
        {"icon": "🎨", "t": "Step4：PWM 频率选择",
         "d": "频率 > 100Hz 人眼看到连续亮度，频率太高产生高频噪声"},
    ])),

    # p3-key-int: 按键扫描与外部中断（新增）
    ("p3-key-int", "p3-key-int-anim", _rich_anim_block("p3-key-int-anim", "3.2 按键扫描与外部中断", [
        {"icon": "🔘", "t": "Step1：按键硬件原理",
         "d": "按键按下时引脚电平从高变低（下拉），松开时恢复高电平"},
        {"icon": "🔁", "t": "Step2：扫描法轮询检测",
         "d": "while(1) 中不断读取 GPIO 输入，检测到低电平判断按下，延时消抖"},
        {"icon": "⚡", "t": "Step3：EXTI 中断触发",
         "d": "配置 EXTI 下降沿触发，按键按下瞬间硬件自动产生中断，无需轮询"},
        {"icon": "🎯", "t": "Step4：中断回调处理",
         "d": "进入 HAL_GPIO_EXTI_Callback()，通过 GPIO_Pin 参数判断哪个按键"},
    ])),

    # p9-i2c-proto: I2C 协议时序动画（已有）
    ("p9-i2c-proto", "p9-i2c-anim", _rich_anim_block("p9-i2c-anim", "I2C 总线通信时序", [
        {"icon": "📡", "t": "Step1：START 条件",
         "d": "SCL 为高电平时，SDA 从高拉低——这是起始信号，总线上所有从机注意"},
        {"icon": "📮", "t": "Step2：发送 7 位从机地址 + R/W",
         "d": "主机逐位发送地址（如 BH1750 = 0x23 = 0100011），最后 1 位是读/写方向"},
        {"icon": "✅", "t": "Step3：从机应答 ACK",
         "d": "地址匹配的从机拉低 SDA 一个时钟周期表示 ACK，主机确认有从机响应"},
        {"icon": "📦", "t": "Step4：数据传输（8 位一组）",
         "d": "每传 8 位数据后，接收方回复一个 ACK/NACK，如此循环直到传完"},
        {"icon": "🛑", "t": "Step5：STOP 条件",
         "d": "SCL 为高电平时，SDA 从低拉高——停止信号，释放总线"},
    ])),

    # p9-i2c-proto: I2C 协议 Mermaid 时序图
    ("p9-i2c-proto", "p9-i2c-mermaid", mermaid_block("p9-i2c-mermaid",
        title="I2C 主从通信时序",
        diagram_type="sequence",
        source="""\
sequenceDiagram
    participant M as Master(STM32)
    participant S as Slave(BH1750)
    M->>S: START + 地址(0x23) + W
    S-->>M: ACK
    M->>S: 命令字节(0x10=连续高分辨率)
    S-->>M: ACK
    M->>S: STOP
    Note over M,S: 等待 120ms 转换
    M->>S: START + 地址(0x23) + R
    S-->>M: ACK
    S->>M: 数据高字节
    M-->>S: ACK
    S->>M: 数据低字节
    M-->>S: NACK
    M->>S: STOP
""")),

    # p3-key-int: EXTI 中断触发流程
    ("p3-key-int", "p3-exti-flow-mermaid", mermaid_block("p3-exti-flow-mermaid",
        title="外部中断触发流程",
        diagram_type="flowchart",
        source="""\
flowchart TD
    A[引脚电平变化] --> B{边沿检测}
    B -->|上升沿/下降沿| C[EXTI 挂起寄存器置位]
    B -->|无匹配边沿| X[忽略]
    C --> D{NVIC 中断使能?}
    D -->|是| E[CPU 暂停主循环]
    D -->|否| Y[挂起等待]
    E --> F[执行 HAL_GPIO_EXTI_Callback]
    F --> G[清除挂起标志]
    G --> H[返回主循环]
""")),

    # p1-history: 单片机发展历程（富动画）
    ("p1-history", "p1-timeline-anim", _rich_anim_block("p1-timeline-anim", "单片机发展里程碑", [
        {"icon": "🔬", "t": "1971：Intel 4004",
         "d": "世界第一颗微处理器，4位架构，时钟 740kHz，2300 个晶体管"},
        {"icon": "📟", "t": "1976：Intel 8048",
         "d": "第一颗单片机，集成 CPU+RAM+ROM+IO 到一颗芯片，开创 MCU 时代"},
        {"icon": "🏭", "t": "1980：Intel 8051",
         "d": "经典 8 位单片机架构，至今仍在使用（STC89C52 等）"},
        {"icon": "📱", "t": "2004：ARM Cortex-M3",
         "d": "32 位低功耗架构，STM32 系列诞生，嵌入式进入 32 位时代"},
        {"icon": "🇨🇳", "t": "2013：国产 MCU 崛起",
         "d": "GD32/AT32 等引脚兼容 STM32，国产替代浪潮开始"},
    ])),

    # p2-ide: CubeMX 配置流程
    ("p2-ide", "p2-cubemx-flow-mermaid", mermaid_block("p2-cubemx-flow-mermaid",
        title="CubeMX 开发流程",
        diagram_type="flowchart",
        source="""\
flowchart LR
    A[选择芯片型号] --> B[引脚配置]
    B --> C[时钟树设置]
    C --> D[外设参数]
    D --> E[Generate Code]
    E --> F[CubeIDE 编写逻辑]
    F --> G[编译]
    G --> H[ST-Link 下载]
    H --> I[调试验证]
""")),
]


def main():
    with open(MF, 'r', encoding='utf-8') as f:
        m = json.load(f)

    added = 0
    for page_id, block_id, block_data in ANIMATIONS:
        page = None
        for ch in m['chapters']:
            for sec in ch['sections']:
                for p in sec['pages']:
                    if p['id'] == page_id:
                        page = p
                        break
        if not page:
            print(f"  [SKIP] {page_id} not found", file=sys.stderr)
            continue

        # 检查是否已存在同 ID block
        existing_idx = None
        for i, b in enumerate(page['blocks']):
            if b.get('id') == block_id:
                existing_idx = i
                break

        if existing_idx is not None:
            # 替换已有的占位动画
            page['blocks'][existing_idx] = block_data
            added += 1
        else:
            # 在第一个 text block 后插入新动画
            insert_pos = 1
            for i, b in enumerate(page['blocks']):
                if b['kind'] == 'text':
                    insert_pos = i + 1
                    break
            page['blocks'].insert(insert_pos, block_data)
            added += 1

    with open(MF, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f"[sensor-anim] 注入 {added} 个动画/图表 block", file=sys.stderr)


if __name__ == '__main__':
    main()
