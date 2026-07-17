"""
inject_gap_games.py· 给真缺口页补课后互动游戏

P2 盘查确认：p9-i2c-proto / p3-exti-code 两个进阶页无动画无游戏。
本脚本各注入一个领域相关的课后互动游戏（幂等：按 blockId 去重）。

  - p9-i2c-proto  : ordering（I2C 读时序步骤排序）
  - p3-exti-code  : fill-blank（EXTI 配置关键代码填空）

用法：python apps/player/public/manifest/inject_gap_games.py
"""
import json
import os
import sys

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

# 各缺口页要注入的 interactive block
GAP_GAMES = {
    'p9-i2c-proto': {
        'id': 'p9-i2c-proto-game',
        'kind': 'interactive',
        'spec': {
            'kind': 'ordering',
            'prompt': '把 I2C 主机读取从机一个字节的时序步骤排成正确顺序',
            'items': [
                {'id': 'i2c-start', 'text': '主机发送 START 起始信号（SCL 高时 SDA 拉低）'},
                {'id': 'i2c-addr', 'text': '主机发送 7 位从机地址 + 读写位（R/W=1 读）'},
                {'id': 'i2c-ack1', 'text': '从机拉低 SDA 回应 ACK 应答'},
                {'id': 'i2c-data', 'text': '从机逐位发出 8 位数据，主机采样'},
                {'id': 'i2c-nack', 'text': '主机发 NACK 表示不再接收'},
                {'id': 'i2c-stop', 'text': '主机发送 STOP 停止信号（SCL 高时 SDA 拉高）'},
            ],
            'correctOrder': ['i2c-start', 'i2c-addr', 'i2c-ack1', 'i2c-data', 'i2c-nack', 'i2c-stop'],
        },
    },
    'p3-exti-code': {
        'id': 'p3-exti-code-game',
        'kind': 'interactive',
        'spec': {
            'kind': 'fill-blank',
            'prompt': '补全 STM32 HAL 库配置外部中断 EXTI 的关键代码',
            'segments': [
                '外部中断回调函数名是 HAL_GPIO_',
                {'blank': True, 'answer': 'EXTI_Callback', 'hint': '外部中断回调'},
                '；在回调里要先判断触发引脚 if (GPIO_Pin == ',
                {'blank': True, 'answer': 'KEY_PIN', 'hint': '按键引脚宏'},
                ')；中断服务函数 EXTIx_IRQHandler 里需调用 HAL_GPIO_',
                {'blank': True, 'answer': 'EXTI_IRQHandler', 'hint': 'HAL 中断处理'},
                ' 来清除标志并分发回调。',
            ],
        },
    },
}


def main():
    with open(MANIFEST, encoding='utf-8') as f:
        m = json.load(f)

    pages = {p['id']: p for ch in m['chapters'] for s in ch['sections'] for p in s['pages']}
    added, skipped, missing = 0, 0, 0
    for pid, block in GAP_GAMES.items():
        page = pages.get(pid)
        if not page:
            print(f'  [MISS] 页面 {pid} 不存在')
            missing += 1
            continue
        blocks = page.setdefault('blocks', [])
        if any(b.get('id') == block['id'] for b in blocks):
            print(f'  [skip] {pid}: 已有 {block["id"]}')
            skipped += 1
            continue
        # 插到 summary 之前（若有），否则末尾
        idx = next((i for i, b in enumerate(blocks) if b.get('kind') == 'summary'), len(blocks))
        blocks.insert(idx, block)
        print(f'  [OK] {pid}: 注入 {block["spec"]["kind"]} 游戏 {block["id"]}')
        added += 1

    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'\n[SUMMARY] 注入={added} 跳过={skipped} 缺页={missing}')


if __name__ == '__main__':
    main()
