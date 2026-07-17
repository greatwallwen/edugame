# -*- coding: utf-8 -*-
"""
factories.py — DRY 页面工厂函数

包含：
- build_intro_page()       章节引入页（学习目标+项目引入+任务安排）
- build_extension_page()   知识拓展页（常见错误+进阶技巧+闪卡）
- build_worksheet_page()   实训工作页（7段式工作手册范式）
- quick_page()             通用快速页面（含互动+实验+摘要）
- make_simple_page()       中后期项目页面（含代码块+实验块）
"""
from manifest.blocks import (
    text_block, summary_block, dh_block, flashcard,
    page, table_block, experiment_block,
    mindmap_block, anim_block, intro_block,
    matching, classification, ordering, memory_match, fill_blank, code_block,
)


def build_intro_page(pid, ch_num, ch_title, objectives, intro_text, tasks, prereqs=None):
    """章节引入页工厂（DRY）：学习目标 + 项目引入 + 任务安排
    objectives: [(目标描述, 能力层次), ...]
    tasks:      [(编号, 名称, 核心内容, 建议时间), ...]
    """
    obj_md  = "\n".join(f"| {i+1} | {o[0]} | {o[1]} |" for i, o in enumerate(objectives))
    task_md = "\n".join(f"| **{t[0]}** | {t[1]} | {t[2]} | {t[3]} |" for t in tasks)
    prereq_str = "、".join(prereqs) if prereqs else "无特殊要求"
    md = (
        f"# {ch_num}  {ch_title}\n\n"
        f"## 学习目标\n\n"
        f"| 序号 | 学习目标 | 能力层次 |\n"
        f"|------|---------|----------|\n"
        f"{obj_md}\n\n"
        f"## 项目引入\n\n"
        f"{intro_text}\n\n"
        f"## 工作任务安排\n\n"
        f"| 任务编号 | 任务名称 | 核心内容 | 建议时间 |\n"
        f"|---------|---------|---------|----------|\n"
        f"{task_md}\n\n"
        f"> 📋 **前置知识**：{prereq_str}\n"
    )
    return page(
        pid, f"{ch_num} {ch_title} — 学习目标与项目引入",
        blocks=[
            text_block(f"{pid}-text", md),
            summary_block(f"{pid}-sum",
                [o[0] for o in objectives[:4]],
                [f"完成{ch_title}学习后，你能独立完成哪些实验？"]),
            dh_block(f"{pid}-dh",
                f"欢迎来到{ch_title}！本章通过实际项目带你掌握核心技能，先了解目标，再动手实验。",
                [{"q": f"学习{ch_title}需要哪些前置知识？",
                  "a": f"建议先完成：{prereq_str}。"}]),
        ],
        objectives=[o[0] for o in objectives],
        minutes=15, difficulty="beginner", tags=["intro", "objectives"]
    )


def build_extension_page(pid, ch_num, ch_title, mistakes, tips, cards):
    """知识拓展页工厂（DRY）：常见错误 + 进阶技巧 + 自测闪卡
    mistakes: [(错误名, 说明), ...]
    tips:     [(技巧名, 说明), ...]
    cards:    [(问题, 答案), ...]
    """
    err_md = "\n".join(f"- ❌ **{m[0]}**：{m[1]}" for m in mistakes)
    tip_md = "\n".join(f"- 💡 **{t[0]}**：{t[1]}" for t in tips)
    md = (
        f"# {ch_num}  {ch_title} — 常见错误与知识拓展\n\n"
        f"## 常见错误排查\n\n"
        f"{err_md}\n\n"
        f"## 进阶技巧\n\n"
        f"{tip_md}\n\n"
        f"## 本章小结\n\n"
        f"完成本章学习后，建议：\n"
        f"1. 不看代码独立完成所有实验\n"
        f"2. 修改关键参数（如PSC/ARR/波特率），观察现象变化\n"
        f"3. 将本章知识应用到自己的小项目中\n"
    )
    return page(
        pid, f"{ch_num} {ch_title} — 常见错误与知识拓展",
        blocks=[
            text_block(f"{pid}-text", md),
            flashcard(f"{pid}-fc", f"自测：{ch_title}核心知识", cards),
            summary_block(f"{pid}-sum",
                [f"避免：{m[0]}" for m in mistakes[:3]],
                [f"如何验证{ch_title}实验成功？"]),
        ],
        objectives=[f"掌握{ch_title}常见错误排查", f"了解{ch_title}进阶应用"],
        minutes=20, difficulty="intermediate", tags=["extension", "debugging"]
    )


def build_worksheet_page(pid, task_title, context_md, objectives, materials,
                          steps, knowledge_cards=None, quiz_items=None, key_points=None):
    """实训工作页工厂（7段式工作手册范式，教职成〔2026〕1号）
    steps: [(标题, 描述, 代码片段), ...]
    """
    bid = pid.replace("-", "_")
    blocks = []

    # ① 任务情境（text block）
    obj_list = "\n".join(f"- {o}" for o in objectives)
    blocks.append(text_block(f"{bid}-ctx", (
        f"## 任务情境\n\n{context_md}\n\n"
        f"## 工作目标\n\n{obj_list}\n"
    )))

    # ② 器材清单（table block）
    if materials:
        blocks.append(table_block(f"{bid}-mat", "器材与资源清单",
            ["器材名称", "型号规格", "数量", "用途说明"], materials))

    # ③ 工作步骤（experiment block）
    exp_steps = [
        {"order": i+1, "title": s[0], "description": s[1], "code": s[2],
         "checkpoint": (i == len(steps)-1)}
        for i, s in enumerate(steps)
    ]
    blocks.append({
        "id": f"{bid}-exp", "kind": "experiment", "title": "工作步骤",
        "steps": exp_steps,
        "expectedResult": "按步骤操作完成后，实验现象与工作目标一致",
        "troubleshooting": [
            "编译失败：检查头文件包含、函数名拼写、分号是否遗漏",
            "硬件无响应：检查接线、确认GPIO时钟已使能、用万用表测量关键点电压",
        ]
    })

    # ④ 知识卡片
    if knowledge_cards:
        blocks.append(flashcard(f"{bid}-kc", "📚 知识卡片（遇到问题时查阅）", knowledge_cards))

    # ⑤ 质量检测
    if quiz_items:
        blocks.append(flashcard(f"{bid}-qz", "✅ 质量检测（自测达标）", quiz_items))

    # ⑥ 能力确认（summary block）
    blocks.append(summary_block(f"{bid}-sum",
        key_points or [task_title],
        ["你能独立完成本任务吗？", "哪个步骤最容易出错？如何避免？"]
    ))

    return page(pid, task_title, blocks,
                objectives=objectives, minutes=90,
                difficulty="intermediate", tags=["worksheet", "hands-on"])


def quick_page(pid, title, md_body, mm_root, anim_scenes, games, quiz_ref, sum_pts, dh_script, dh_faq,
               objectives=None, minutes=35, difficulty="intermediate", tags=None, exp_steps=None,
               extra_blocks_before_exp=None, outro_mode='simplified', max_games=3):
    """一次性生成包含完整互动游戏的页面（ch3-ch12 通用模板）

    outro_mode:
      - 'simplified'（默认，Sprint 2 优化）：仅 summary（删除冗余的 quiz-intro 和 dh）
      - 'legacy'：保留 quiz-intro + summary + dh（兼容旧页面）
      - 'finale-plus'：summary only（用于 finale 页面）
      - 'finale-only'：无 outro（finale-challenge 自带 summary）

    max_games: 最多保留几个 interactive（默认 3，防止过载）
    """
    blocks = [
        text_block(f"{pid}-text", md_body),
        mindmap_block(f"{pid}-mm", mm_root),
        anim_block(f"{pid}-anim", title, anim_scenes),
    ]
    # 限制 interactive 数量（Sprint 2 优化：5 个 → 3 个）
    for g in games[:max_games]:
        blocks.append(g)
    if extra_blocks_before_exp:
        blocks.extend(extra_blocks_before_exp)
    if exp_steps:
        blocks.append(experiment_block(f"{pid}-exp", f"{title} 实验", exp_steps))

    # 复习区（Sprint 2 优化：删除冗余 quiz-intro 和 dh）
    if outro_mode == 'simplified':
        blocks.append(summary_block(f"{pid}-sum", sum_pts, [f"{title}的核心应用场景是什么？"]))
    elif outro_mode == 'legacy':
        blocks.append(intro_block(f"{pid}-qi", quiz_ref, f"{title}知识挑战", "检验本节掌握情况", "circuit"))
        blocks.append(summary_block(f"{pid}-sum", sum_pts, [f"{title}的核心应用场景是什么？"]))
        blocks.append(dh_block(f"{pid}-dh", dh_script, dh_faq))
    elif outro_mode == 'finale-plus':
        blocks.append(summary_block(f"{pid}-sum", sum_pts, [f"{title}的核心应用场景是什么？"]))
    # outro_mode == 'finale-only' 时跳过所有 outro

    return page(pid, title, blocks,
                objectives=objectives or [f"掌握{title}的原理与应用"],
                minutes=minutes, difficulty=difficulty, tags=tags or [])


def make_simple_page(pid, title, topic, key_points, games_data, quiz_ref, mm_children, anim_data,
                     minutes=40, difficulty="intermediate", tags=None,
                     code_lang="c", code_snippet=None, code_filename=None,
                     exp_steps_simple=None, md_body=None,
                     extra_blocks_before_exp=None):
    """快速生成中后期项目页面（含代码块和实验块）
    md_body: 可选，覆盖自动生成的正文。传入完整Markdown正文内容。
    extra_blocks_before_exp: 可选，章节文件可注入额外 block（如 mermaid 状态机）。
        与内置的 code_block 合并，章节注入的 block 排在最前。
    """
    games = []
    for g in games_data:
        if g[0] == "matching":
            games.append(matching(f"{pid}-g{len(games)}", g[1], g[2]))
        elif g[0] == "classification":
            games.append(classification(f"{pid}-g{len(games)}", g[1], g[2], g[3]))
        elif g[0] == "ordering":
            games.append(ordering(f"{pid}-g{len(games)}", g[1], g[2]))
        elif g[0] == "flashcard":
            games.append(flashcard(f"{pid}-g{len(games)}", g[1], g[2]))
        elif g[0] == "memory":
            games.append(memory_match(f"{pid}-g{len(games)}", g[1], g[2]))
        elif g[0] == "fill":
            games.append(fill_blank(f"{pid}-g{len(games)}", g[1], g[2]))
    if md_body is None:
        md_body = f"# {title}\n\n" + "\n\n".join([f"**{k}**" for k in key_points])
    # 合并：章节传入的 extra_blocks（如 mermaid 状态机）放在最前，
    # 内置 code_block（如 code_snippet）放在其后。
    _extras = list(extra_blocks_before_exp or [])
    if code_snippet:
        _extras.append(
            code_block(f"{pid}-code", code_lang, code_snippet,
                       fname=code_filename)
        )
    return quick_page(
        pid, title,
        md_body=md_body,
        mm_root={"text": topic, "children": mm_children},
        anim_scenes=anim_data,
        games=games,
        quiz_ref=quiz_ref,
        sum_pts=key_points,
        dh_script=f"同学们，{title}是嵌入式开发中的重要技能。掌握它，你将能处理更复杂的工程挑战。",
        dh_faq=[{"q": f"学习{topic}最难的地方是什么？",
                 "a": f"通常是理解{topic}的底层工作原理，而不是记忆API。建议先画时序图，再写代码，最后用示波器验证。"}],
        objectives=[f"理解{title}的工作原理", f"掌握{title}的HAL库配置", f"完成{title}实验"],
        minutes=minutes, difficulty=difficulty, tags=tags or [],
        exp_steps=exp_steps_simple,
        extra_blocks_before_exp=_extras,
    )
