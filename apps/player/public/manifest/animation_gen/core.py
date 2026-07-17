# -*- coding: utf-8 -*-
"""OpenMAIC 风格教学动画渲染核心。

设计要点：
- 每个 step 只点亮相应的 SVG 元素组（data-step 属性）和 step 卡片；
- 父页面通过 postMessage({type:'dgb-step', step}) 驱动；
- iframe 通过 'dgb-steps-total' 上报总步数、'dgb-step-change' 回传当前步；
- 舞台按 iframe 宽度缩放（1920 基线），高度自适应。
"""
from __future__ import annotations
import html, json, re

from ._visual import visual  # noqa: F401

def esc(v): return html.escape(str(v or ""), quote=True)
def compact(v): return re.sub(r"\s+", " ", str(v or "")).strip()


def _css() -> str:
    # textbook theme baseline：墨绿 + 米黄 + 白卡（对齐 DGBook textbook 主题）
    return (
        '*{box-sizing:border-box}'
        'body{margin:0;overflow:hidden;background:#FBF7EC;'
        'font-family:"PingFang SC","Source Han Sans SC","Microsoft YaHei",Arial,sans-serif;'
        'color:#1F2937}'
        '#viewport{position:fixed;inset:0;overflow:hidden;'
        'background:linear-gradient(135deg,#FBF7EC,#F4EEDF)}'
        '#stage{position:absolute;width:1920px;height:1080px;left:0;top:0;'
        'transform-origin:0 0;background:linear-gradient(180deg,#fff,#FBF7EC);'
        'border-radius:28px;box-shadow:0 24px 80px rgba(14,124,74,.14);'
        'overflow:hidden;border:1px solid #D9E2D1}'
        '.head{position:absolute;left:76px;top:54px;right:76px;display:flex;'
        'justify-content:flex-start;gap:50px}'
        'h1{font-size:52px;line-height:1.08;margin:0 0 14px;font-weight:900;'
        'letter-spacing:-.8px;max-width:1680px;color:#0A5132}'
        '.sub{font-size:22px;color:#4B5563;max-width:1400px}'
        '.panel{position:absolute;left:76px;top:205px;width:1115px;height:515px;'
        'background:#fff;border:1px solid #D9E2D1;border-radius:28px;'
        'box-shadow:0 16px 44px rgba(14,124,74,.08);overflow:hidden}'
        '.svg{width:100%;height:100%}'
        '.side{position:absolute;right:76px;top:205px;width:585px;height:515px;'
        'display:grid;grid-template-rows:auto 1fr;gap:18px}'
        '.formulaBox{padding:26px;border-radius:26px;background:#FFF8EC;'
        'border:1px solid #F0D9A2;box-shadow:0 12px 34px rgba(217,119,6,.10)}'
        '.formulaBox h2{margin:0 0 12px;font-size:30px;color:#0A5132}'
        '.formulaBox p{margin:0;font-size:28px;font-weight:800;color:#B45309}'
        'ol{margin:0;padding:0;display:grid;gap:14px;list-style:none}'
        'li{display:flex;gap:14px;align-items:flex-start;padding:16px 18px;'
        'border-radius:20px;background:#fff;border:1px solid #D9E2D1;'
        'font-size:20px;line-height:1.32;color:#4B5563;opacity:.4;transition:.3s}'
        'li b{min-width:34px;height:34px;border-radius:12px;background:#C8E4D0;'
        'color:#0A5132;display:grid;place-items:center}'
        'li.active{opacity:1;border-color:#0E7C4A;'
        'box-shadow:0 12px 32px rgba(14,124,74,.18);transform:translateX(-6px)}'
        'li.done{opacity:.85}'
        '.metrics{position:absolute;left:76px;right:76px;top:748px;height:118px;'
        'display:grid;grid-template-columns:repeat(4,1fr);gap:18px}'
        '.metric{background:#fff;border:1px solid #D9E2D1;border-radius:24px;'
        'padding:18px;text-align:center;box-shadow:0 12px 30px rgba(14,124,74,.06);'
        'overflow:hidden;transition:.25s}'
        '.metric.hl{background:#FFF8EC;border-color:#F0D9A2;'
        'box-shadow:0 18px 38px rgba(217,119,6,.20);transform:translateY(-4px)}'
        '.metric strong{display:block;font-size:34px;line-height:1.05;color:#0E7C4A;'
        'white-space:nowrap;overflow:hidden;text-overflow:ellipsis}'
        '.metric span{display:block;margin-top:10px;color:#4B5563;font-size:18px;'
        'white-space:nowrap;overflow:hidden;text-overflow:ellipsis}'
        '.caption{position:absolute;left:120px;right:120px;bottom:46px;'
        'text-align:center;padding:18px 24px;border-radius:24px;'
        'background:rgba(255,255,255,.85);backdrop-filter:blur(6px);'
        'border:1px solid #D9E2D1}'
        '#cn{font-size:30px;line-height:1.25;font-weight:800;color:#0A5132;'
        'white-space:nowrap;overflow:hidden;text-overflow:ellipsis}'
        '.dots{position:absolute;right:92px;top:32px;display:flex;gap:11px}'
        '.dots i{width:13px;height:13px;border-radius:50%;background:#D9E2D1;transition:.25s}'
        '.dots i.active{background:#0E7C4A;transform:scale(1.4)}'
        '.dots i.done{background:#10915A}'
        '.wire,.axis{stroke:#6B7280;stroke-width:8;fill:none;stroke-linecap:round}'
        '.light{stroke:#D9E2D1;stroke-width:4}'
        '.box{fill:#fff;stroke:#0E7C4A;stroke-width:4}'
        '.blue{fill:#E6F1EA;stroke:#0E7C4A}'
        '.green{fill:#DCFCE7;stroke:#10915A}'
        '.purple{fill:#EEE6FF;stroke:#6A52B0}'
        '.amber{fill:#FFF8EC;stroke:#D97706}'
        '.chip{fill:#0E7C4A}'
        '.wtext{font-size:30px;text-anchor:middle;fill:#fff;font-weight:900}'
        '.wsmall,.label{font-size:22px;text-anchor:middle;fill:#4B5563;font-weight:700}'
        '.formula{font-size:30px;text-anchor:middle;fill:#0A5132;font-weight:900}'
        '.res,.diode,.ground path{stroke:#6A52B0;stroke-width:8;fill:none;'
        'stroke-linecap:round;stroke-linejoin:round}'
        '.led{fill:#B91C1C;stroke:#FCA5A5;stroke-width:8}'
        '.dot{fill:#10915A;filter:drop-shadow(0 0 12px #10915A)}'
        '.p1{animation:flow1 3s linear infinite}'
        '.p2{animation:flow2 3s linear infinite}'
        '.p3{animation:flow3 3s linear infinite}'
        '@keyframes flow1{from{cx:90}to{cx:310}}'
        '@keyframes flow2{from{cx:470}to{cx:650}}'
        '@keyframes flow3{from{cx:790}to{cx:900}}'
        '.wave,.cnt,.pwm{stroke:#0E7C4A;stroke-width:8;fill:none;'
        'stroke-linecap:round;stroke-linejoin:round}'
        '.avg{stroke:#D97706;stroke-width:7;stroke-dasharray:18 14}'
        '.irq{fill:#D97706;animation:pulse 1s infinite}'
        '.node{fill:#E6F1EA;stroke:#0E7C4A;stroke-width:5}'
        '.breath{animation:pulse 2.2s ease-in-out infinite}'
        '@keyframes pulse{50%{transform:scale(1.08);opacity:.72}}'
        '[data-step]{opacity:.12;transition:opacity .45s ease, transform .45s ease}'
        '[data-step].show{opacity:1}'
        '[data-step].current{filter:drop-shadow(0 0 14px #10915A)}'
    )


def _script() -> str:
    """受控动画显示器脚本（与 manifest 中 17 个 final inline JS 语义等价）。

    协议：
      iframe → parent: dgb-iframe-height / dgb-step-change / dgb-steps-total
      parent → iframe: dgb-step / dgb-reset / dgb-anim-finalize
                       + SET_WIDGET_STATE / HIGHLIGHT_ELEMENT / ANNOTATE_ELEMENT

    关键 invariant（H2 漂移回写）：
      · measureContentH(scale): 实测内容底沿，让 iframe 高度紧贴内容，避免米黄空白
      · transformOrigin='top left': 与 fit() 的 scale 配合，避免缩放原点偏移
      · setTimeout(fit, 40): 每次 render 后 4 帧再重测高（每步内容高度可能不同）
      · dgb-reset / dgb-anim-finalize → render(0): 受控协议归零
      · 不使用 RAF 自走（受控显示器不应自播）
    """
    return r"""
const total=steps.length;
function measureContentH(scale){try{let maxBottom=0;const sr=stage.getBoundingClientRect();const all=stage.querySelectorAll('*');for(const el of all){const cs=getComputedStyle(el);if(cs.display==='none'||cs.visibility==='hidden')continue;const r=el.getBoundingClientRect();const bottom=r.bottom-sr.top;if(bottom>maxBottom)maxBottom=bottom;}const rawH=Math.ceil(maxBottom/Math.max(scale,.0001))+24;return Math.min(1080,Math.max(220,rawH));}catch(e){return 1080}}
function fit(){const s=Math.max(.18,innerWidth/1920);stage.style.transform=`scale(${s})`;stage.style.transformOrigin='top left';stage.style.left='0px';stage.style.top='0px';const ch=measureContentH(s);parent.postMessage({type:'dgb-iframe-height',height:Math.ceil(ch*s)},'*')}
addEventListener('resize',fit);
let step=0;
function render(i){
  step=Math.max(0,Math.min(total-1,i));
  document.querySelectorAll('li[data-k]').forEach(el=>{const k=Number(el.dataset.k);el.classList.toggle('active',k===step);el.classList.toggle('done',k<step)});
  document.querySelectorAll('.dots i').forEach((el,k)=>{el.classList.toggle('active',k===step);el.classList.toggle('done',k<step)});
  document.querySelectorAll('[data-step]').forEach(el=>{const k=Number(el.dataset.step)-1;el.classList.toggle('show',k<=step);el.classList.toggle('current',k===step)});
  document.querySelectorAll('.metric').forEach((el,k)=>el.classList.toggle('hl',k===step));
  cn.textContent=steps[step]||'';
  parent.postMessage({type:'dgb-step-change',step,total},'*');
  setTimeout(fit,40)
}
addEventListener('message',e=>{
  const d=e.data||{};
  if(d.type==='dgb-step'){render(d.step|0);return}
  if(d.type==='dgb-reset'||d.type==='dgb-anim-finalize'){render(0);return}
  if(d.type==='SET_WIDGET_STATE'&&d.state)Object.entries(d.state).forEach(([k,v])=>{const el=document.getElementById(k);if(el)el.textContent=v});
  if(d.type==='HIGHLIGHT_ELEMENT'){const el=document.querySelector(d.target);if(el){el.classList.add('current');setTimeout(()=>el.classList.remove('current'),2400)}}
  if(d.type==='ANNOTATE_ELEMENT'){cn.textContent=d.text||cn.textContent}
});
document.addEventListener('visibilitychange',()=>{});
addEventListener('pagehide',()=>{});
fit();
parent.postMessage({type:'dgb-steps-total',total},'*');
render(0);
""".strip()


def render_scene(spec: dict) -> str:
    steps = spec.get("steps") or []
    steps = steps[:5] or ["观察动画并解释关键概念"]
    metrics = (spec.get("metrics") or [])[:4]
    while len(metrics) < 4:
        metrics.append(("OpenMAIC", "交互协议"))
    step_cards = "".join(
        f'<li data-k="{i}"><b>{i+1}</b><span>{esc(x)}</span></li>'
        for i, x in enumerate(steps)
    )
    metric_cards = "".join(
        f'<div class="metric"><strong>{esc(v)}</strong><span>{esc(k)}</span></div>'
        for v, k in metrics
    )
    dots = "".join("<i></i>" for _ in steps)
    steps_json = json.dumps(steps, ensure_ascii=False)
    return (
        '<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8">'
        f'<title>{esc(spec.get("title"))}</title>'
        f'<style>{_css()}</style></head><body>'
        '<div id="viewport"><main id="stage">'
        f'<div class="dots">{dots}</div>'
        '<header class="head">'
        f'<div><h1>{esc(spec.get("title"))}</h1>'
        f'<div class="sub">{esc(spec.get("subtitle"))}</div></div>'
        '</header>'
        f'<section class="panel">{visual(spec.get("kind","generic"))}</section>'
        '<aside class="side">'
        '<div class="formulaBox"><h2>核心模型</h2>'
        f'<p>{esc(spec.get("formula"))}</p></div>'
        f'<ol>{step_cards}</ol></aside>'
        f'<section class="metrics">{metric_cards}</section>'
        '<footer class="caption"><div id="cn"></div></footer>'
        '</main></div>'
        f'<script>const steps={steps_json};{_script()}</script>'
        '</body></html>'
    )
