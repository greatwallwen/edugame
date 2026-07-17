"""
inject_terms.py· 术语词典注入 manifest

把 materials/stm32-course/terms.json 中的 domainTerms / followUpTemplates /
codeHighlightExtras 合入 manifest.json 顶层字段。

幂等：每次覆盖写入（JSON 值相等时跳过）。
"""
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', '..'))
MANIFEST = os.path.join(ROOT, 'apps', 'player', 'public', 'manifest.json')
TERMS = os.path.join(ROOT, 'materials', 'stm32-course', 'terms.json')


def main():
    if not os.path.isfile(MANIFEST):
        print(f'[FAIL] manifest 不存在：{MANIFEST}')
        sys.exit(1)
    if not os.path.isfile(TERMS):
        print(f'[FAIL] terms.json 不存在：{TERMS}')
        sys.exit(1)

    with open(MANIFEST, encoding='utf-8') as f:
        m = json.load(f)
    with open(TERMS, encoding='utf-8') as f:
        terms = json.load(f)

    changed = False
    for key in ('domainTerms', 'followUpTemplates', 'codeHighlightExtras'):
        if key not in terms:
            continue
        if m.get(key) != terms[key]:
            m[key] = terms[key]
            changed = True

    if not changed:
        print('[OK] manifest 已含最新术语数据，无变更')
        return

    with open(MANIFEST, 'w', encoding='utf-8') as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
    print('[OK] 已注入 domainTerms + followUpTemplates + codeHighlightExtras')


if __name__ == '__main__':
    main()
