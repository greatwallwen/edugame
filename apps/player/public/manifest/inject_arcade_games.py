#!/usr/bin/env python3
"""
inject_arcade_games.py — 为章节 ext 页面注入 arcade-runner 街机跑酷游戏

每章一个跑酷游戏，学生收集正确知识碎片，躲避错误选项。
幂等：按 block id 去重/替换。基于 InjectBase。
"""
import sys, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'apps', 'player', 'public'))
from manifest.inject_base import InjectBase

GAMES = [
    ("ch3-ext", "ch3-arcade", {
        "kind": "arcade-runner", "prompt": "GPIO 知识跑酷 — 收集正确的 GPIO 配置步骤！",
        "theme": "circuit",
        "collectibles": [
            {"id": "g1", "text": "使能时钟", "correct": True},
            {"id": "g2", "text": "配置模式", "correct": True},
            {"id": "g3", "text": "设置电平", "correct": True},
            {"id": "g4", "text": "推挽输出", "correct": True},
            {"id": "g5", "text": "不需要时钟", "correct": False},
            {"id": "g6", "text": "模拟输入驱动LED", "correct": False},
            {"id": "g7", "text": "直接写寄存器", "correct": False},
            {"id": "g8", "text": "忘记初始化", "correct": False},
        ],
        "duration": 30, "passThreshold": 3,
        "explanation": "GPIO 使用四步：使能时钟 → 配置模式 → 初始化 → 操作引脚"
    }),
    ("ch4-ext", "ch4-arcade", {
        "kind": "arcade-runner", "prompt": "定时器知识跑酷 — 收集正确的定时器参数！",
        "theme": "space",
        "collectibles": [
            {"id": "t1", "text": "PSC预分频", "correct": True},
            {"id": "t2", "text": "ARR重装载", "correct": True},
            {"id": "t3", "text": "CNT计数器", "correct": True},
            {"id": "t4", "text": "溢出中断", "correct": True},
            {"id": "t5", "text": "PSC=0不分频", "correct": False},
            {"id": "t6", "text": "ARR越大频率越高", "correct": False},
            {"id": "t7", "text": "不需要使能时钟", "correct": False},
            {"id": "t8", "text": "CNT手动清零", "correct": False},
        ],
        "duration": 30, "passThreshold": 3,
        "explanation": "定时器核心三寄存器：PSC 分频、ARR 重装载、CNT 计数"
    }),
    ("ch6-ext", "ch6-arcade", {
        "kind": "arcade-runner", "prompt": "串口通信跑酷 — 收集正确的 UART 帧格式！",
        "theme": "ocean",
        "collectibles": [
            {"id": "u1", "text": "起始位(低)", "correct": True},
            {"id": "u2", "text": "8位数据", "correct": True},
            {"id": "u3", "text": "停止位(高)", "correct": True},
            {"id": "u4", "text": "115200波特率", "correct": True},
            {"id": "u5", "text": "起始位(高)", "correct": False},
            {"id": "u6", "text": "停止位(低)", "correct": False},
            {"id": "u7", "text": "7位数据", "correct": False},
            {"id": "u8", "text": "不需要GND", "correct": False},
        ],
        "duration": 30, "passThreshold": 3,
        "explanation": "UART 8N1 帧：1起始位(低) + 8数据位 + 1停止位(高)"
    }),
    ("ch9-ext", "ch9-arcade", {
        "kind": "arcade-runner", "prompt": "I2C 协议跑酷 — 收集正确的 I2C 通信步骤！",
        "theme": "forest",
        "collectibles": [
            {"id": "i1", "text": "START条件", "correct": True},
            {"id": "i2", "text": "发送地址+RW", "correct": True},
            {"id": "i3", "text": "等待ACK", "correct": True},
            {"id": "i4", "text": "STOP条件", "correct": True},
            {"id": "i5", "text": "上拉电阻", "correct": True},
            {"id": "i6", "text": "不需要上拉", "correct": False},
            {"id": "i7", "text": "8位地址", "correct": False},
            {"id": "i8", "text": "无需应答", "correct": False},
        ],
        "duration": 35, "passThreshold": 4,
        "explanation": "I2C 通信：START → 地址(7bit)+R/W → ACK → 数据 → STOP"
    }),
    ("ch12-ext", "ch12-arcade", {
        "kind": "arcade-runner", "prompt": "PID 控制跑酷 — 收集正确的 PID 调参知识！",
        "theme": "space",
        "collectibles": [
            {"id": "p1", "text": "Kp比例项", "correct": True},
            {"id": "p2", "text": "Ki积分项", "correct": True},
            {"id": "p3", "text": "Kd微分项", "correct": True},
            {"id": "p4", "text": "先调Kp", "correct": True},
            {"id": "p5", "text": "Kp越大越稳", "correct": False},
            {"id": "p6", "text": "Ki消除超调", "correct": False},
            {"id": "p7", "text": "Kd消除稳态误差", "correct": False},
            {"id": "p8", "text": "三参数一起调", "correct": False},
        ],
        "duration": 30, "passThreshold": 3,
        "explanation": "PID 调参顺序：先 Kp(比例) → 再 Ki(消稳态误差) → 最后 Kd(抑超调)"
    }),
]

class ArcadeGamesInject(InjectBase):
    def run(self, m):
        added = 0
        for page_id, block_id, spec in GAMES:
            page = self.find_page(m, page_id)
            if not page:
                continue
            block_data = {"id": block_id, "kind": "interactive", "spec": spec}
            self.upsert_block(page, block_data, position='before_summary')
            added += 1
        print(f"[arcade-games] 注入 {added} 个跑酷游戏", file=sys.stderr)
        return m

def main():
    ArcadeGamesInject().execute()

if __name__ == '__main__':
    main()
