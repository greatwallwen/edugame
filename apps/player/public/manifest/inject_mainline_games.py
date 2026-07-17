"""
inject_mainline_games.py · 主线页第 6 个互动补全（源头持久化）

5 个核心主线页只有 4~5 个互动，补到 6 个（与生产基线对齐）。
内容按各页知识点个性化。幂等：按 blockId 去重。
"""
import json
import os
import sys

try:
    sys.stdout.reconfigure(encoding='utf-8')
except Exception:
    pass

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')

EXTRA = {
    'p2-clang': {'id': 'p2-cl-i6', 'kind': 'interactive', 'spec': {
        'kind': 'single-choice', 'prompt': 'C 语言位操作：将 P0 的第 3 位置 1，其余不变',
        'options': [
            {'id': 'a', 'text': 'P0 |= (1 << 3)'},
            {'id': 'b', 'text': 'P0 &= ~(1 << 3)'},
            {'id': 'c', 'text': 'P0 ^= (1 << 3)'},
            {'id': 'd', 'text': 'P0 = (1 << 3)'}],
        'answer': 'a', 'explanation': '|= (1<<n) 置位且不影响其他位；&=~ 是清位，^= 是翻转，= 会覆盖全部'}},
    'p3-led-blink': {'id': 'p3-led-i6', 'kind': 'interactive', 'spec': {
        'kind': 'bit-flip', 'prompt': '点亮 PA5 LED：将 ODR 低 8 位的第 5 位置 1',
        'registerName': 'GPIOA->ODR', 'initial': 0, 'target': 32,
        'explanation': 'PA5 接 LED（高电平点亮）。ODR bit5=1（值 32）时 LED 亮。',
        'bitLabels': ['7', '6', '5', '4', '3', '2', '1', '0']}},
    'p10-parking': {'id': 'p10-parking-g5', 'kind': 'interactive', 'spec': {
        'kind': 'timed-quiz', 'prompt': '停车场系统快答 · 限时 45 秒', 'seconds': 45,
        'questions': [
            {'id': 'q1', 'stem': '超声波测距用到定时器的什么功能？', 'options': ['输入捕获', 'PWM输出', 'ADC', 'DAC'], 'answer': 0},
            {'id': 'q2', 'stem': '舵机抬杆用什么信号控制？', 'options': ['PWM', 'UART', 'I2C', 'SPI'], 'answer': 0},
            {'id': 'q3', 'stem': '车位状态显示常用什么器件？', 'options': ['数码管/LED', '电机', '蜂鸣器', '继电器'], 'answer': 0}]}},
    'p11-band': {'id': 'p11-band-g5', 'kind': 'interactive', 'spec': {
        'kind': 'single-choice', 'prompt': 'MPU6050 通过什么接口与 STM32 通信？',
        'options': [
            {'id': 'a', 'text': 'I2C（或 SPI）'},
            {'id': 'b', 'text': '只能用 UART'},
            {'id': 'c', 'text': '只能用 CAN'},
            {'id': 'd', 'text': '直接 GPIO 读取'}],
        'answer': 'a', 'explanation': 'MPU6050 支持 I2C 和 SPI，运动手环常用 I2C 连接读取加速度/陀螺仪数据'}},
    'p12-suntrack': {'id': 'p12-suntrack-g5', 'kind': 'interactive', 'spec': {
        'kind': 'single-choice', 'prompt': 'PID 追光系统中，光敏电阻差值作为什么输入 PID？',
        'options': [
            {'id': 'a', 'text': '误差（error）'},
            {'id': 'b', 'text': '比例系数 Kp'},
            {'id': 'c', 'text': '输出量'},
            {'id': 'd', 'text': '采样周期'}],
        'answer': 'a', 'explanation': '四象限光敏差值即偏离光源的误差，PID 据此计算舵机修正量实现闭环对准'}},
}

INSERT_BEFORE = {'code', 'experiment', 'finale-challenge', 'digital-human', 'summary'}


def main():
    m = json.load(open(MANIFEST, encoding='utf-8'))
    added = 0
    for ch in m['chapters']:
        for s in ch['sections']:
            for p in s['pages']:
                if p['id'] not in EXTRA:
                    continue
                item = EXTRA[p['id']]
                if any(b['id'] == item['id'] for b in p.get('blocks', [])):
                    continue
                # 插在最后一个 interactive 之后
                last_i = -1
                for i, b in enumerate(p['blocks']):
                    if b.get('kind') == 'interactive':
                        last_i = i
                if last_i < 0:
                    for i, b in enumerate(p['blocks']):
                        if b.get('kind') in INSERT_BEFORE:
                            last_i = i - 1
                            break
                p['blocks'].insert(last_i + 1, item)
                added += 1
    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print(f'[mainline-games] 补主线第6互动: {added} 个')


if __name__ == '__main__':
    main()
