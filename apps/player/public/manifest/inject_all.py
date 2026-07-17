"""
inject_all.py · 课程 inject 脚本自动发现与执行

架构：
  1. 先执行框架通用脚本（在 manifest/ 目录下）
  2. 再从 courses/{courseId}/inject/ 自动发现并执行课程特定脚本
  3. 脚本按文件名排序执行

用法：
  python apps/player/public/manifest/inject_all.py
  python apps/player/public/manifest/inject_all.py --dry-run
  python apps/player/public/manifest/inject_all.py --continue-on-error
"""
import argparse
import os
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
HERE = os.path.dirname(os.path.abspath(__file__))

# ── 框架通用脚本（与课程无关）──
FRAMEWORK_SCRIPTS = [
    ('inject_narration_factory.py',         '通用旁白工厂', False),
    ('inject_finale_all.py',                'finale-challenge 一次性合集', True),
    ('inject_aux_anim.py',                  '辅助页流程动画（ws + code）', False),
    ('inject_fix_anim_duration.py',         '修复短动画duration（全部≥15秒）', False),
    ('inject_flashcard_rebalance.py',       'flashcard占比优化（≤25%）', False),
]

# ── 课程特定脚本（标记 [course]，待后续物理分离）──
COURSE_SCRIPTS = [
    ('inject_narration_chapter_intros.py', '[course] 章节导览开场旁白', False),
    ('inject_narration_p3_led_blink.py',    '[course] p3 LED 旁白', False),
    ('inject_narration_p3_key_int.py',      '[course] p3 key-int 旁白', False),
    ('inject_narration_p4_p5_p6.py',        '[course] p4/p5/p6 旁白主线', False),
    ('inject_narration_p7_p11_p12.py',      '[course] p7/p11/p12 旁白主线', False),
    ('inject_narration_p8_p9.py',           '[course] p8/p9 旁白', False),
    ('inject_narration_p8_p9_p6it_p10_final.py', '[course] p8/p9/p6-it/p10 旁白终版', True),
    ('inject_narration_p11_p12_anim_extra.py',   '[course] p11/p12 动画扩段', True),
    ('inject_animation_teacher.py',         '[course] 动画教师剧本', False),
    ('inject_key_int_animation.py',         '[course] p3 key-int 动画注解', True),
    ('inject_key_int_flow.py',              '[course] p3 key-int 流程动画', False),
    ('inject_commentary.py',                '[course] 通用 commentary 注解', False),
    ('inject_faq.py',                       '[course] FAQ 段', False),
    ('inject_template_all.py',              '[course] template animation（已退役）', True),
    ('inject_finale_p3_led_blink.py',       '[course] p3 LED finale 题集', True),
    ('inject_bit_flip_extend.py',           '[course] bit-flip 5 道扩展题', False),
    ('inject_wokwi_d1.py',                  '[course] Wokwi 五元件接入', False),
    ('inject_terms.py',                     '[course] 术语词典', False),
    ('inject_gap_games.py',                 '[course] 缺口页课后游戏', False),
    ('enhance_device_svg.py',               '[course] 动画器件素材 CSS', False),
    ('inject_chapter_games.py',             '[course] 章节个性化互动游戏', False),
    ('inject_mainline_games.py',            '[course] 主线页互动补全', False),
    ('inject_register_decoder.py',          '[course] register-decoder 题型', False),
    ('inject_advanced_code.py',             '[course] 进阶代码示例', False),
    ('inject_iter59_fixes.py',              '[course] Iter-59 修复', False),
    ('inject_finale_chapters.py',           '[course] 每章 finale-challenge', False),
    ('inject_extended_interactive.py',      '[course] 扩展互动题型', False),
    ('inject_register_tables.py',           '[course] 寄存器剖析', False),
    ('inject_sensor_animations.py',         '[course] 传感器动画补充', False),
    ('inject_structure_page_visuals.py',    '[course] 结构页Mermaid流程图', False),
    ('inject_arcade_games.py',              '[course] 章节街机跑酷游戏', False),
    # ── 最后：生成 page.actions（spotlight + speak 时间线）──
    ('generate_page_actions.py',            '[framework] 生成播报时间线 actions', False),
]


def run_one(script_path, label):
    """执行单个脚本，接受绝对路径或相对于 HERE 的文件名"""
    if os.path.isabs(script_path):
        p = script_path
    else:
        p = os.path.join(HERE, script_path)
    if not os.path.exists(p):
        return ('skip-missing', 0)
    t0 = time.time()
    # 确保课程脚本能 import manifest.* 模块
    public_dir = os.path.dirname(HERE)  # apps/player/public/
    env = {**os.environ, 'PYTHONIOENCODING': 'utf-8', 'PYTHONUTF8': '1'}
    existing_pp = env.get('PYTHONPATH', '')
    env['PYTHONPATH'] = public_dir + (os.pathsep + existing_pp if existing_pp else '')
    res = subprocess.run(
        [sys.executable, p],
        cwd=ROOT, env=env,
        capture_output=True, text=True, encoding='utf-8', errors='replace',
    )
    elapsed = time.time() - t0
    if res.returncode != 0:
        return ('fail', elapsed)
    return ('ok', elapsed)


def main():
    parser = argparse.ArgumentParser(description='inject_*.py 自动发现与执行')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--continue-on-error', action='store_true')
    args = parser.parse_args()

    # 构建完整管线：框架通用 + 课程特定
    pipeline = []
    for script, label, optional in FRAMEWORK_SCRIPTS:
        pipeline.append((os.path.join(HERE, script), label, optional))
    for script, label, optional in COURSE_SCRIPTS:
        pipeline.append((os.path.join(HERE, script), label, optional))

    print('=' * 60)
    print(f'  inject_all : {len(pipeline)} scripts')
    print(f'  框架通用: {len(FRAMEWORK_SCRIPTS)} | 课程特定: {len(COURSE_SCRIPTS)}')
    print('=' * 60)

    if args.dry_run:
        for i, (p, label, opt) in enumerate(pipeline, 1):
            mark = '?' if opt else '!'
            name = os.path.basename(p)
            print(f'  {i:2d}. [{mark}] {name:50s} {label}')
        return

    t0 = time.time()
    ok, skip, fail = 0, 0, 0
    for i, (script_path, label, optional) in enumerate(pipeline, 1):
        name = os.path.basename(script_path)
        status, elapsed = run_one(script_path, label)
        if status == 'skip-missing':
            mark = '[skip]' if optional else '[MISS]'
            print(f'  {i:2d}. {mark} {name:50s} ({label})')
            if optional: skip += 1
            else:
                fail += 1
                if not args.continue_on_error:
                    sys.exit(1)
        elif status == 'fail':
            tag = '[skip-fail]' if optional else '[FAIL]'
            print(f'  {i:2d}. {tag:11s} {name:50s} ({label})  {elapsed:.1f}s')
            if optional: skip += 1
            else:
                fail += 1
                if not args.continue_on_error:
                    sys.exit(1)
        else:
            print(f'  {i:2d}. [ ok ]      {name:50s} ({label})  {elapsed:.1f}s')
            ok += 1

    total = time.time() - t0
    print(f'\n[SUMMARY] ok={ok}  skip={skip}  fail={fail}  total {total:.1f}s')
    if fail > 0 and not args.continue_on_error:
        sys.exit(1)


if __name__ == '__main__':
    main()
