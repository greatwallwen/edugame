/**
 * 文本规范化（TTS 朗读前）
 *
 * 把"书面符号"翻成"中文读法"，让神经/原生 TTS 能正确朗读：
 *  - 单位：3.0V → "3点0伏"，220kΩ → "220千欧"，10mA → "10毫安" 等
 *  - 运算符：3+2 → "3加2"，3-2 → "3减2"（数字之间），3×2 → "3乘以2" 等
 *  - 比较：=, ≈, ≠, >, <, ≥, ≤
 *  - 小数：3.0 → "3点0"
 *  - 百分号：50% → "百分之50"
 *  - 上标：x² → "x的平方"，x³ → "x的立方"
 *  - 下标：a₁ → "a下标1"
 *  - 分数：1/2（数字间） → "二分之一"（仅 1..10 的简单分数；其它数走 "X分之Y"）
 *  - 希腊字母：α/β/π/Ω/μ 等常见
 *
 * 设计要点：
 *  1. 纯函数、零依赖、便于单测和后续扩展（规则即数据，集中在 RULES_*）。
 *  2. 顺序敏感：先处理"组合符号"（如 ≥），再处理单字符（>）。
 *  3. 仅在数字相邻时把 -/+/* 视作运算符，避免吞代码标识符（如 max-len、a+b 不带数）。
 */
export function normalizeTextForSpeech(input: string): string {
  if (!input) return '';
  let t = String(input);

  // 0a. 剥离编辑/工程标记，避免 TTS 念出来：
  //    - HTML 注释   <!-- ... -->
  //    - 方括号 marker  [Iter29-补充] / [Iter30-...] / [DEBUG] / [TODO]
  //    保留紧贴正文的 ASCII 横线分隔（——进阶补充——）作为可读过渡词，由 TTS 自然停顿
  t = t.replace(/<!--[\s\S]*?-->/g, '');
  t = t.replace(/\[(?:Iter\d+[-_][^\]]+|DEBUG|TODO|FIXME|NOTE)\]/g, '');

  // 0b. 统一全角到半角（避免规则被全角符号绕开）
  t = t.replace(/[０-９]/g, (c) => String.fromCharCode(c.charCodeAt(0) - 0xfee0));

  // 1. 下标 a₁ a₂ ... → a下标1
  const SUBS = '₀₁₂₃₄₅₆₇₈₉';
  t = t.replace(new RegExp(`([A-Za-z\u4e00-\u9fff])([${SUBS}]+)`, 'g'), (_, base, subs) =>
    `${base}下标${[...subs].map((c: string) => String(SUBS.indexOf(c))).join('')}`);

  // 2. 上标常用：x² x³ x⁴ ...
  const SUPS: Record<string, string> = {
    '²': '的平方', '³': '的立方', '⁴': '的四次方', '⁵': '的五次方',
    '⁶': '的六次方', '⁷': '的七次方', '⁸': '的八次方', '⁹': '的九次方',
  };
  t = t.replace(/([A-Za-z\u4e00-\u9fff0-9])([²³⁴⁵⁶⁷⁸⁹]+)/g, (_, base, sups) =>
    base + [...sups].map((c: string) => SUPS[c] ?? '').join(''));

  // 3. 单位：先处理"复合前缀+单位"再处理"单字符单位"。\b 不识别 Ω 等，用边界字符类
  //   带数字 [(可选小数)] [前缀] 单位
  const PREFIX: Record<string, string> = {
    k: '千', K: '千', M: '兆', G: '吉', m: '毫', μ: '微', u: '微', n: '纳', p: '皮',
  };
  const UNIT: Record<string, string> = {
    V: '伏', A: '安', Ω: '欧', Hz: '赫兹', W: '瓦', J: '焦', F: '法拉',
    H: '亨利', s: '秒', g: '克',
  };
  // 多字符单位优先（Hz）
  t = t.replace(/(\d+(?:\.\d+)?)\s*([kKMGmμunp])?(Hz)\b/g,
    (_, n, p, u) => `${n}${p ? PREFIX[p] : ''}${UNIT[u]}`);
  // 单字符单位（V/A/Ω/W/J/F/H/s/g）
  t = t.replace(/(\d+(?:\.\d+)?)\s*([kKMGmμunp])?(Ω|[VAWJFH])(?![A-Za-z])/g,
    (_, n, p, u) => `${n}${p ? PREFIX[p] : ''}${UNIT[u]}`);

  // 4. 百分号
  t = t.replace(/(\d+(?:\.\d+)?)\s*%/g, '百分之$1');

  // 5. 比较运算符（双字符先于单字符）
  t = t
    .replace(/≥|>=/g, '大于等于').replace(/≤|<=/g, '小于等于')
    .replace(/≠|!=/g, '不等于').replace(/≈/g, '约等于')
    .replace(/=/g, '等于');

  // 6. 数字之间的运算符（避免吞标识符里的 - +）
  //    简单分数：先 1..10 的常见分数中文化
  const FRAC_CN = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
  t = t.replace(/(?<![\w.])(\d+)\/(\d+)(?![\w.])/g, (_, a, b) => {
    const ai = Number(a); const bi = Number(b);
    if (bi >= 2 && bi <= 10 && ai >= 1 && ai <= bi - 1) return `${FRAC_CN[bi]}分之${FRAC_CN[ai]}`;
    return `${a}分之${b}`.replace(/^/, ''); // 兜底："a 分之 b"
  });
  t = t.replace(/(\d)\s*[×*]\s*(\d)/g, '$1乘以$2')
       .replace(/(\d)\s*÷\s*(\d)/g, '$1除以$2')
       .replace(/(\d)\s*\+\s*(\d)/g, '$1加$2')
       .replace(/(\d)\s*[-−]\s*(\d)/g, '$1减$2');

  // 7. 大于/小于（必须在比较运算符之后，避免吞 >= 中的 >）
  t = t.replace(/>/g, '大于').replace(/</g, '小于');

  // 8. 小数点：3.0 → 3点0（仅数字间，避免吞域名/版本号里的点—只处理"两侧都是单一数字段"的最简情形）
  t = t.replace(/(\d)\.(\d)/g, '$1点$2');

  // 9. 希腊字母（电学常见）
  const GREEK: Record<string, string> = {
    'α': '阿尔法', 'β': '贝塔', 'γ': '伽马', 'δ': '德尔塔', 'θ': '西塔',
    'λ': '兰姆达', 'μ': '缪', 'π': '派', 'σ': '西格马', 'φ': '斐', 'ω': '欧米伽',
    'Ω': '欧姆', // 残余的 Ω（没和数字搭配的）
  };
  t = t.replace(/[αβγδθλμπσφωΩ]/g, (c) => GREEK[c] ?? c);

  // 10. 收敛多余空格
  t = t.replace(/[ \t]+/g, ' ').trim();
  return t;
}

/** 自检（在 dev console 调用便于排查规则） */
export function __dgbookSelfTestNormalize(): { case: string; got: string; want: string; ok: boolean }[] {
  const cases: [string, string][] = [
    ['3.0V', '3点0伏'],
    ['220kΩ', '220千欧'],
    ['10mA', '10毫安'],
    ['50Hz', '50赫兹'],
    ['10W', '10瓦'],
    ['3+2=5', '3加2等于5'],
    ['3-2=1', '3减2等于1'],
    ['3×2', '3乘以2'],
    ['3*2', '3乘以2'],
    ['3÷2', '3除以2'],
    ['a≈b', 'a约等于b'],
    ['x≥y', 'x大于等于y'],
    ['50%', '百分之50'],
    ['x²', 'x的平方'],
    ['a₁', 'a下标1'],
    ['1/2', '二分之一'],
    ['[Iter29-补充] 这一段是进阶讲解', '这一段是进阶讲解'],
    ['<!--ITER29_TOPUP--> 内容', '内容'],
    ['[DEBUG] 调试信息', '调试信息'],
    ['——进阶补充——', '——进阶补充——'], // 中文横线分隔保留为可读过渡词
  ];
  return cases.map(([input, want]) => {
    const got = normalizeTextForSpeech(input);
    return { case: input, got, want, ok: got === want };
  });
}
