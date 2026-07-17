"""
aux_anim_template.py· 辅助页流程动画 HTML 模板

把简版流程卡升级为富场景动画（对齐主线 p3-led-blink-anim 设计语言）：
  - 左侧 SVG 流程管线：N 个圆角节点（蛇形折行）+ 连接线 + 当前节点辉光
  - 右侧编号讲解面板：逐步高亮当前步
  - 底部 4 张要点卡（metrics）：当前步关联卡高亮
  - 顶部标题/副标题 + 右上进度点 + 底部字幕
  - 1920×1080 stage + fit 自适应缩放（上报 dgb-iframe-height）
  - 受控 step：接收 dgb-step / dgb-reset / dgb-anim-finalize，
    上报 dgb-anim-step-change / dgb-anim-steps-total（与播报联动兼容）+ autoplay 兜底

数据：build_flow_html(title, steps, scripts?, subtitle?, metrics?)
"""
import html as _html

BRAND = '#0E7C4A'
BRAND_DK = '#0A5132'
BRAND_LT = '#10915A'
ACCENT = '#D97706'
ACCENT_DK = '#B45309'


def _esc(s: str) -> str:
    return _html.escape(str(s), quote=True)


def _default_metrics(steps):
    out = [{'v': f'{len(steps)} 步', 'l': '流程节点'}]
    for i, s in enumerate(steps[:3]):
        out.append({'v': f'{i + 1}', 'l': s[:8]})
    while len(out) < 4:
        out.append({'v': '·', 'l': ''})
    return out[:4]


def _node_svg(steps):
    """左侧 SVG 流程管线：节点蛇形折行 + 连接线 + 节点编号/标签。"""
    n = len(steps)
    cols = 3 if n > 4 else max(1, n)
    nw, nh, gx, gy = 280, 150, 64, 90
    parts = ['<defs><filter id="fglow" x="-60%" y="-60%" width="220%" height="220%">'
             '<feGaussianBlur stdDeviation="10" result="b"/><feMerge>'
             '<feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>']
    pos = []
    for i in range(n):
        row, c = divmod(i, cols)
        if row % 2 == 1:
            c = cols - 1 - c
        pos.append((40 + c * (nw + gx), 40 + row * (nh + gy)))
    rows = (n + cols - 1) // cols
    vb_w = cols * nw + (cols - 1) * gx + 80
    vb_h = rows * nh + (rows - 1) * gy + 80
    for i in range(n - 1):
        x1, y1 = pos[i]
        x2, y2 = pos[i + 1]
        if abs(y1 - y2) < 1:
            d = (f'M{x1 + nw} {y1 + nh / 2} H{x2}' if x2 > x1
                 else f'M{x1} {y1 + nh / 2} H{x2 + nw}')
        else:
            sx = x1 + nw / 2
            d = f'M{sx} {y1 + nh} V{y2 + nh / 2} H{x2 + nw / 2}'
        parts.append(f'<path d="{d}" class="fwire" data-link="{i}"/>')
    for i, (x, y) in enumerate(pos):
        cx = x + nw / 2
        parts.append(
            f'<g data-step="{i + 1}" class="fnode">'
            f'<rect x="{x}" y="{y}" width="{nw}" height="{nh}" rx="26" class="fbox"/>'
            f'<circle cx="{x + 42}" cy="{y + 42}" r="27" class="fnum-bg"/>'
            f'<text x="{x + 42}" y="{y + 52}" class="fnum">{i + 1}</text>'
            f'<text x="{cx + 18}" y="{y + nh / 2 + 14}" class="flbl">{_esc(steps[i][:9])}</text>'
            f'</g>')
    return (f'<svg viewBox="0 0 {vb_w} {vb_h}" class="fsvg" '
            f'preserveAspectRatio="xMidYMid meet">' + ''.join(parts) + '</svg>')


def build_flow_html(title: str, steps, scripts=None, subtitle: str = '', metrics=None) -> str:
    n = len(steps)
    scripts = list(scripts) if scripts else list(steps)
    while len(scripts) < n:
        scripts.append(steps[len(scripts)])
    if not subtitle:
        subtitle = ' · '.join(s[:6] for s in steps[:4])
    metrics = metrics or _default_metrics(steps)
    return _build_html(title, steps, scripts, subtitle, metrics, n)


_CSS = """*{box-sizing:border-box}
body{margin:0;overflow:hidden;background:#FBF7EC;font-family:"PingFang SC","Microsoft YaHei",Arial,sans-serif;color:#1F2937}
#viewport{position:fixed;inset:0;overflow:hidden;background:linear-gradient(135deg,#FBF7EC,#F4EEDF)}
#stage{position:absolute;width:1920px;height:1080px;left:0;top:0;transform-origin:0 0;
background:linear-gradient(180deg,#fff,#FBF7EC);border-radius:28px;box-shadow:0 24px 80px rgba(14,124,74,.14);
overflow:hidden;border:1px solid #D9E2D1}
.head{position:absolute;left:76px;top:54px;right:76px}
h1{font-size:50px;line-height:1.1;margin:0 0 12px;font-weight:900;letter-spacing:-.8px;color:#0A5132}
.sub{font-size:24px;color:#4B5563}
.panel{position:absolute;left:76px;top:210px;width:1115px;height:510px;background:#fff;border:1px solid #D9E2D1;
border-radius:28px;box-shadow:0 16px 44px rgba(14,124,74,.08);overflow:hidden;padding:20px}
.fsvg{width:100%;height:100%}
.fwire{stroke:#CBD5E1;stroke-width:7;fill:none;stroke-linecap:round;transition:.4s}
.fwire.lit{stroke:#10915A}
.fbox{fill:#fff;stroke:#D9E2D1;stroke-width:4;transition:.4s}
.fnum-bg{fill:#EEF2F7;transition:.4s}
.fnum{font-size:30px;text-anchor:middle;fill:#6B7280;font-weight:900;transition:.4s}
.flbl{font-size:30px;text-anchor:middle;fill:#1F2937;font-weight:800}
.fnode{opacity:.4;transition:.45s}
.fnode.show{opacity:.9}
.fnode.show .fbox{stroke:#10915A}
.fnode.show .fnum-bg{fill:#C8E4D0}.fnode.show .fnum{fill:#0A5132}
.fnode.current{opacity:1}
.fnode.current .fbox{stroke:#0E7C4A;stroke-width:6;filter:drop-shadow(0 0 16px rgba(16,145,90,.55))}
.fnode.current .fnum-bg{fill:#0E7C4A}.fnode.current .fnum{fill:#fff}
.side{position:absolute;right:76px;top:210px;width:585px;height:510px;display:grid;grid-template-rows:auto 1fr;gap:18px}
.ovBox{padding:24px;border-radius:26px;background:#FFF8EC;border:1px solid #F0D9A2;box-shadow:0 12px 34px rgba(217,119,6,.10)}
.ovBox h2{margin:0 0 8px;font-size:28px;color:#0A5132}
.ovBox p{margin:0;font-size:22px;font-weight:700;color:#B45309}
ol{margin:0;padding:0;display:grid;gap:12px;list-style:none;overflow:auto}
li{display:flex;gap:14px;align-items:flex-start;padding:14px 16px;border-radius:18px;background:#fff;
border:1px solid #D9E2D1;font-size:19px;line-height:1.3;color:#4B5563;opacity:.42;transition:.3s}
li b{min-width:32px;height:32px;border-radius:11px;background:#C8E4D0;color:#0A5132;display:grid;place-items:center;font-weight:800}
li.active{opacity:1;border-color:#0E7C4A;box-shadow:0 12px 32px rgba(14,124,74,.18);transform:translateX(-6px)}
li.done{opacity:.8}li.done b{background:#10915A;color:#fff}
.metrics{position:absolute;left:76px;right:76px;top:752px;height:120px;display:grid;grid-template-columns:repeat(4,1fr);gap:18px}
.metric{background:#fff;border:1px solid #D9E2D1;border-radius:24px;padding:16px;text-align:center;
box-shadow:0 12px 30px rgba(14,124,74,.06);transition:.25s;overflow:hidden}
.metric.hl{background:#FFF8EC;border-color:#F0D9A2;box-shadow:0 18px 38px rgba(217,119,6,.20);transform:translateY(-4px)}
.metric strong{display:block;font-size:32px;color:#0E7C4A;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.metric span{display:block;margin-top:8px;color:#4B5563;font-size:17px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.caption{position:absolute;left:120px;right:120px;bottom:42px;text-align:center;padding:16px 22px;border-radius:22px;
background:rgba(255,255,255,.88);backdrop-filter:blur(6px);border:1px solid #D9E2D1}
#cn{font-size:28px;line-height:1.25;font-weight:800;color:#0A5132}
.dots{position:absolute;right:92px;top:34px;display:flex;gap:11px}
.dots i{width:13px;height:13px;border-radius:50%;background:#D9E2D1;transition:.25s}
.dots i.active{background:#0E7C4A;transform:scale(1.4)}.dots i.done{background:#10915A}
"""


_JS = """
var cur=-1,N=%(n)d,autoT=null,gotExternal=false;
var scripts=%(scripts)s, mhl=%(mhl)s;
var stage=document.getElementById('stage');
function rpt(t){try{parent.postMessage({type:t,step:cur,total:N},'*')}catch(e){}}
function fit(){var s=Math.max(.18,innerWidth/1920);stage.style.transform='scale('+s+')';
 var h=Math.min(1080,1000);try{parent.postMessage({type:'dgb-iframe-height',height:Math.ceil(h*s)},'*')}catch(e){}}
addEventListener('resize',fit);
function render(i){cur=Math.max(0,Math.min(N-1,i));
 document.querySelectorAll('.fnode').forEach(function(el){var k=+el.dataset.step-1;
   el.classList.toggle('show',k<=cur);el.classList.toggle('current',k===cur)});
 document.querySelectorAll('.fwire').forEach(function(el){el.classList.toggle('lit',+el.dataset.link<cur)});
 document.querySelectorAll('li[data-k]').forEach(function(el){var k=+el.dataset.k;
   el.classList.toggle('active',k===cur);el.classList.toggle('done',k<cur)});
 document.querySelectorAll('.dots i').forEach(function(el,k){el.classList.toggle('active',k===cur);el.classList.toggle('done',k<cur)});
 document.querySelectorAll('.metric').forEach(function(el,k){el.classList.toggle('hl',mhl[cur]===k)});
 var cn=document.getElementById('cn');if(cn)cn.textContent=scripts[cur]||'';
 rpt('dgb-anim-step-change');setTimeout(fit,40)}
function autoplay(){if(gotExternal)return;if(cur>=N-1)return;render(cur+1);autoT=setTimeout(autoplay,1600)}
addEventListener('message',function(e){var d=e.data||{};
 if(d.type==='dgb-step'&&typeof d.step==='number'){gotExternal=true;if(autoT){clearTimeout(autoT);autoT=null}render(d.step|0);return}
 if(d.type==='dgb-reset'||d.type==='dgb-anim-finalize'){gotExternal=true;if(autoT){clearTimeout(autoT);autoT=null}render(d.type==='dgb-reset'?0:N-1);return}});
fit();rpt('dgb-anim-steps-total');render(0);autoT=setTimeout(autoplay,1600);
"""


def _build_html(title, steps, scripts, subtitle, metrics, n):
    import json as _j
    svg = _node_svg(steps)
    dots = ''.join('<i></i>' for _ in range(n))
    lis = ''.join(
        f'<li data-k="{i}"><b>{i + 1}</b><span>{_esc(scripts[i])}</span></li>'
        for i in range(n))
    mets = ''.join(
        f'<div class="metric"><strong>{_esc(m.get("v", ""))}</strong>'
        f'<span>{_esc(m.get("l", ""))}</span></div>'
        for m in metrics[:4])
    # 每步高亮哪张要点卡：默认按 step 取 min(step,3)
    mhl = [min(i, 3) for i in range(n)]
    js = _JS % {
        'n': n,
        'scripts': _j.dumps(scripts, ensure_ascii=False),
        'mhl': _j.dumps(mhl),
    }
    return (
        '<!DOCTYPE html><html lang="zh-CN"><head><meta charset="UTF-8">'
        f'<title>{_esc(title)}</title><style>{_CSS}</style></head><body>'
        '<div id="viewport"><main id="stage">'
        f'<div class="dots">{dots}</div>'
        f'<header class="head"><h1>{_esc(title)}</h1><div class="sub">{_esc(subtitle)}</div></header>'
        f'<section class="panel">{svg}</section>'
        f'<aside class="side"><div class="ovBox"><h2>流程总览</h2><p>{_esc(subtitle)}</p></div>'
        f'<ol>{lis}</ol></aside>'
        f'<section class="metrics">{mets}</section>'
        '<footer class="caption"><div id="cn"></div></footer>'
        f'</main></div><script>{js}</script></body></html>'
    )
