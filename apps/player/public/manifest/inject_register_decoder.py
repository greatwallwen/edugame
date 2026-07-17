"""
inject_register_decoder.py · 第 25 种题型实例注入（寄存器位段解码）

给寄存器教学相关页注入 register-decoder 互动。STM32 核心技能：读懂寄存器位段。
幂等：按 blockId 去重。加入 inject_all 管线。
"""
import json, os, sys
try: sys.stdout.reconfigure(encoding='utf-8')
except Exception: pass

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

DECODERS = {
    'p2-gpio-hal': {'id': 'p2gh-regdec', 'kind': 'interactive', 'spec': {
        'kind': 'register-decoder',
        'prompt': '解码 GPIOx_CRL 寄存器：判断 PA0 被配置成什么模式',
        'registerName': 'GPIOA->CRL', 'registerValue': '0x44444443',
        'fields': [
            {'id': 'f0', 'label': 'PA0 MODE[1:0] = 0b11', 'options': ['输入模式', '输出 10MHz', '输出 2MHz', '输出 50MHz'], 'answer': 3},
            {'id': 'f1', 'label': 'PA0 CNF[1:0] = 0b00', 'options': ['通用推挽输出', '通用开漏输出', '复用推挽', '模拟输入'], 'answer': 0},
            {'id': 'f2', 'label': 'PA1 配置位 = 0x4', 'options': ['推挽输出', '浮空输入', '上拉输入', '模拟输入'], 'answer': 1}],
        'explanation': 'CRL 每 4 位配置一个引脚：低 2 位 MODE（00输入/11输出50MHz），高 2 位 CNF。0x3=输出50MHz推挽，0x4=浮空输入。'}},
    'p3-led-blink': {'id': 'p3b-regdec', 'kind': 'interactive', 'spec': {
        'kind': 'register-decoder',
        'prompt': '解码 RCC_APB2ENR：哪些外设时钟被使能',
        'registerName': 'RCC->APB2ENR', 'registerValue': '0x00000015',
        'fields': [
            {'id': 'f0', 'label': 'bit0 (AFIOEN) = 1', 'options': ['AFIO 时钟使能', 'AFIO 时钟关闭', 'GPIOA 使能', '保留位'], 'answer': 0},
            {'id': 'f1', 'label': 'bit2 (IOPAEN) = 1', 'options': ['GPIOA 时钟使能', 'GPIOB 时钟使能', 'GPIOC 时钟使能', 'ADC 使能'], 'answer': 0},
            {'id': 'f2', 'label': 'bit4 (IOPCEN) = 1', 'options': ['GPIOC 时钟使能', 'GPIOA 时钟使能', 'USART1 使能', 'TIM1 使能'], 'answer': 0}],
        'explanation': '0x15=0b10101：bit0=AFIO，bit2=GPIOA，bit4=GPIOC。点 LED 必须先使能对应 GPIO 端口时钟，这是初学最易漏的一步。'}},
}

INSERT_BEFORE = {'code', 'experiment', 'finale-challenge', 'digital-human', 'summary'}

def main():
    m = json.load(open(MANIFEST, encoding='utf-8'))
    added = 0
    for ch in m['chapters']:
        for s in ch['sections']:
            for p in s['pages']:
                if p['id'] not in DECODERS: continue
                item = DECODERS[p['id']]
                if any(b['id'] == item['id'] for b in p.get('blocks', [])): continue
                last_i = -1
                for i, b in enumerate(p['blocks']):
                    if b.get('kind') == 'interactive': last_i = i
                if last_i < 0:
                    for i, b in enumerate(p['blocks']):
                        if b.get('kind') in INSERT_BEFORE: last_i = i - 1; break
                p['blocks'].insert(last_i + 1, item)
                added += 1
    json.dump(m, open(MANIFEST, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
    print(f'[register-decoder] 注入: {added} 个')

if __name__ == '__main__':
    main()
