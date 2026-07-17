# -*- coding: utf-8 -*-
"""
inject_finale_p3_led_blink.py — Iter-22 收口 · P3 led-blink finale-challenge 注入

背景
----
p3-key-int 已经迁到 finale-only outro（chapters/ch02_ch03.py + finale_challenge_block helper）。
但 p3-led-blink 仍走 legacy outro（quiz-intro-animation + summary）——主 agent T0 漏改。

manifest 完整生成链路（gen_manifest_main.py / manifest_builder.py）当前缺失，
直接以 inject 脚本 patch manifest.json 是当前可用流程。

本脚本做三件事：
  1. 删除 p3-led-blink-qi（quiz-intro-animation） + p3-led-blink-sum（summary）
  2. 在 experiment 之前注入 p3-led-blink-finale（finale-challenge）
  3. finale 内置 summaryPoints + summaryUnlockMap，把课后总结合并进游戏

幂等：再跑一次会先删旧 finale + 旧 outro 再注入。
"""
from __future__ import annotations

import json
import os
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except Exception:
    pass

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
MF = os.path.join(ROOT, "apps", "player", "public", "manifest.json")

PAGE_ID = "p3-led-blink"
FINALE_ID = "p3-led-blink-finale"
# 配合 quick_page outro_mode='finale-plus'：复习区 = summary 主栏 + finale 副栏，与全站一致。
LEGACY_IDS = {"p3-led-blink-qi"}


# ─── finale block 数据（与 FinaleChallengeBlockSchema 对齐，参考 p3-key-int-finale） ───

def _q_single(qid, stem, options, answer, score=100, difficulty="easy", hint=None):
    q = {
        "id": qid, "scoreBase": score, "difficulty": difficulty,
        "spec": {"type": "quiz", "data": {
            "id": qid, "kind": "single-choice", "stem": stem,
            "options": [{"id": oid, "label": lab} for oid, lab in options],
            "answer": answer,
        }},
    }
    if hint: q["hint"] = hint
    return q


def _q_multi(qid, stem, options, answers, score=160, difficulty="medium", hint=None):
    q = {
        "id": qid, "scoreBase": score, "difficulty": difficulty,
        "spec": {"type": "quiz", "data": {
            "id": qid, "kind": "multiple-choice", "stem": stem,
            "options": [{"id": oid, "label": lab} for oid, lab in options],
            "answer": list(answers),
        }},
    }
    if hint: q["hint"] = hint
    return q


def _q_tf(qid, stem, answer, score=80, difficulty="easy", hint=None):
    q = {
        "id": qid, "scoreBase": score, "difficulty": difficulty,
        "spec": {"type": "quiz", "data": {
            "id": qid, "kind": "true-false", "stem": stem, "answer": bool(answer),
        }},
    }
    if hint: q["hint"] = hint
    return q


def _q_fill(qid, stem, answers, score=160, difficulty="hard", hint=None):
    q = {
        "id": qid, "scoreBase": score, "difficulty": difficulty,
        "spec": {"type": "quiz", "data": {
            "id": qid, "kind": "fill-blank", "stem": stem,
            "placeholder": "___", "answers": list(answers),
        }},
    }
    if hint: q["hint"] = hint
    return q


def _q_matching(qid, prompt, pairs, score=140, difficulty="medium", hint=None):
    q = {
        "id": qid, "scoreBase": score, "difficulty": difficulty,
        "spec": {"type": "interactive", "data": {
            "kind": "matching", "prompt": prompt,
            "pairs": [{"left": l, "right": r} for l, r in pairs],
        }},
    }
    if hint: q["hint"] = hint
    return q


def _q_ordering(qid, prompt, items, score=200, difficulty="hard", hint=None):
    item_list = [{"id": f"o{i}", "text": t} for i, t in enumerate(items)]
    correct = [f"o{i}" for i in range(len(items))]
    q = {
        "id": qid, "scoreBase": score, "difficulty": difficulty,
        "spec": {"type": "interactive", "data": {
            "kind": "ordering", "prompt": prompt,
            "items": item_list, "correctOrder": correct,
        }},
    }
    if hint: q["hint"] = hint
    return q


def _stage(sid, title, questions, time_limit_sec=60, subtitle=None, pass_threshold=0.6):
    s = {"id": sid, "title": title, "questions": questions,
         "timeLimitSec": time_limit_sec, "passThreshold": pass_threshold}
    if subtitle: s["subtitle"] = subtitle
    return s


def build_finale_block():
    """组装 p3-led-blink-finale。3 关：基础 → 函数与电路 → Boss 综合实战。"""
    warmup = _stage(
        sid="fs-led-warmup",
        title="第 1 关 · LED 与 GPIO 基础",
        subtitle="3 道单选 + 判断，确认你看懂了动画里的物理过程",
        time_limit_sec=60,
        pass_threshold=0.6,
        questions=[
            _q_single(
                "fq-l-w1",
                stem="LED 必须串一只限流电阻，主要原因是？",
                options=[
                    ("a", "LED 是单向导电的 PN 结，正向压降固定，多余电压必须被电阻分掉"),
                    ("b", "电阻可以让 LED 颜色更鲜艳"),
                    ("c", "STM32 的 GPIO 不能直接驱动 LED"),
                    ("d", "电阻只是为了防止 LED 装反"),
                ],
                answer="a",
                score=100,
                difficulty="easy",
                hint="LED 正向压降约 1.8~3.0V，3.3V 减去压降的电压全部要靠电阻消耗",
            ),
            _q_tf(
                "fq-l-w2",
                stem="STM32 的 GPIO 推挽输出（Push-Pull）既能输出高电平也能输出低电平。",
                answer=True,
                score=80,
                difficulty="easy",
            ),
            _q_single(
                "fq-l-w3",
                stem="板载 LED 常采用反接（LED 一端接 3.3V，另一端经电阻接 GPIO）。此时 GPIO 输出什么电平 LED 会亮？",
                options=[
                    ("a", "高电平（3.3V）"),
                    ("b", "低电平（0V）"),
                    ("c", "高阻态"),
                    ("d", "任意电平都亮"),
                ],
                answer="b",
                score=100,
                difficulty="easy",
                hint="LED 两端有电压差才有电流；GPIO 拉低=形成 3.3V 压差=电流灌入 GPIO",
            ),
        ],
    )

    advance = _stage(
        sid="fs-led-advance",
        title="第 2 关 · 函数与电路",
        subtitle="把 HAL 函数与作用对上号，再用多选确认花样玩法",
        time_limit_sec=75,
        pass_threshold=0.7,
        questions=[
            _q_matching(
                "fq-l-a1",
                prompt="把 HAL/标准库 GPIO 函数与作用连起来",
                pairs=[
                    ("HAL_GPIO_WritePin SET", "把引脚拉到高电平 3.3V"),
                    ("HAL_GPIO_WritePin RESET", "把引脚拉到低电平 0V"),
                    ("HAL_GPIO_TogglePin", "读 ODR 当前位异或 1 后写回"),
                    ("HAL_Delay(ms)", "阻塞延时（基于 SysTick 滴答）"),
                ],
                score=140,
                difficulty="medium",
            ),
            _q_multi(
                "fq-l-a2",
                stem="下列关于「LED 花样玩法」的说法正确的有（多选）：",
                options=[
                    ("a", "for 循环遍历引脚数组 + 翻转 + 延时 = 流水灯"),
                    ("b", "在 1ms 周期内动态调节高电平占比 = 软件 PWM 呼吸灯"),
                    ("c", "硬件定时器 + PWM 外设可以让 CPU 完全不参与翻转"),
                    ("d", "把 HAL_Delay 写在 EXTI 中断回调里能让 LED 闪烁更稳定"),
                ],
                answers=["a", "b", "c"],
                score=160,
                difficulty="medium",
                hint="d 错：中断回调里不应放 HAL_Delay 这种长阻塞",
            ),
        ],
    )

    boss = _stage(
        sid="fs-led-boss",
        title="Boss · LED 综合实战",
        subtitle="3 题混合：填空 + 排序 + 判断",
        time_limit_sec=90,
        pass_threshold=0.7,
        questions=[
            _q_fill(
                "fq-l-b1",
                stem="若想让 LED 闪烁频率为 1Hz，TogglePin 之后的延时应填 ___ 毫秒（填数字）",
                answers=["500", "500ms"],
                score=160,
                difficulty="hard",
                hint="1Hz=周期 1 秒；翻转两次完成一个周期，每次延时 500ms",
            ),
            _q_ordering(
                "fq-l-b2",
                prompt="按「软件 PWM 呼吸灯」的真实执行顺序排列：",
                items=[
                    "duty 从 0 递增到 100",
                    "在 1ms 周期内拉高 duty 微秒",
                    "在 1ms 周期内剩余时间拉低",
                    "duty 增到 100 后递减回 0",
                    "肉眼看到亮度从暗到亮再到暗",
                ],
                score=200,
                difficulty="hard",
            ),
            _q_tf(
                "fq-l-b3",
                stem="while(1) 主循环里调用 HAL_Delay(500) 实现 LED 闪烁是合规写法。",
                answer=True,
                score=120,
                difficulty="hard",
                hint="主循环阻塞延时是合规的；只有中断 ISR 里禁止 HAL_Delay",
            ),
        ],
    )

    return {
        "id": FINALE_ID,
        "kind": "finale-challenge",
        "title": "LED 与 GPIO 综合挑战",
        "intro": "刚学完 LED 闪烁、流水灯、呼吸灯，用 3 关挑战检验你掌握得怎么样",
        "stages": [warmup, advance, boss],
        "hpMax": 3,
        "bgmTrack": "tense",
        "triggerLabel": "游戏挑战",
        "triggerIcon": "🏆",
        "summaryPoints": [
            "LED 是单向导电 PN 结，必须串限流电阻；STM32 GPIO 推挽输出灌入约 25mA",
            "板载 LED 常用反接：GPIO 拉低 LED 亮，利用「灌电流」更稳的硬件特性",
            "Toggle + 500ms 延时 = 1Hz 方波；for 循环遍历引脚数组 = 流水灯；可变占空比 = 软 PWM 呼吸灯",
            "硬件定时器 + PWM 外设可以让 CPU 完全脱离翻转工作——这是后面 PWM 章节的基础",
        ],
        "summaryUnlockMap": {
            "fs-led-warmup": [0, 1],
            "fs-led-advance": [2],
            "fs-led-boss": [3],
        },
    }


# ─── manifest patch ───────────────────────────────────────────────────────────

def apply_to_manifest(mf):
    """对已生成的 manifest dict 做 in-place patch：
    - 删除 p3-led-blink 下的 legacy outro（quiz-intro-animation + summary）
    - 删除已存在的旧 finale-challenge（保证幂等）
    - 在 experiment 之前注入新 finale-challenge
    返回 (patched_count, removed_count)
    """
    patched = 0
    removed = 0
    finale = build_finale_block()

    for ch in mf.get("chapters", []):
        for sec in ch.get("sections", []):
            for p in sec.get("pages", []):
                if p.get("id") != PAGE_ID:
                    continue
                blocks = p.get("blocks") or []

                # 1. 删除 legacy outro + 已存在的同名 finale（幂等）
                kept = []
                for b in blocks:
                    bid = b.get("id")
                    kind = b.get("kind")
                    if bid in LEGACY_IDS or bid == FINALE_ID:
                        removed += 1
                        continue
                    kept.append(b)

                # 2. 在 experiment 前注入 finale；找不到 experiment 就放在末尾倒数第二位
                #    （保持 digital-human 在最后，与 p3-key-int 一致）
                insert_at = len(kept)
                for i, b in enumerate(kept):
                    if b.get("kind") == "experiment":
                        insert_at = i
                        break

                kept.insert(insert_at, finale)
                p["blocks"] = kept
                patched += 1

    return patched, removed


def main(argv=None):
    if not os.path.exists(MF):
        print(f"[ERR] manifest not found: {MF}", file=sys.stderr)
        return 2

    with open(MF, "r", encoding="utf-8") as f:
        mf = json.load(f)

    patched, removed = apply_to_manifest(mf)
    if patched == 0:
        print(f"[WARN] page id={PAGE_ID} not found, nothing patched")
        return 1

    with open(MF, "w", encoding="utf-8") as f:
        json.dump(mf, f, ensure_ascii=False, indent=2)
    size = os.path.getsize(MF)
    print(f"[OK] inject p3-led-blink-finale -> page={PAGE_ID}")
    print(f"     removed legacy/old finale blocks: {removed}")
    print(f"     manifest written: {size} bytes ({size // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
