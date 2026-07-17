import './LessonHeroBanner.css';

export interface LessonHeroBannerProps {
  /** 任务编号，例如 "任务二" / "3.1" */
  eyebrow?: string;
  /** 任务标题，例如 "LED 点亮实验" */
  title: string;
  /** 任务副标题 / 一句话描述 */
  subtitle?: string;
  /** 主图 URL（可选）。没有时走纯教材绿渐变。 */
  heroImage?: string;
  /** 右上角品牌水印，例如 "STMicroelectronics" / "DGBook"。 */
  brand?: string;
  /** 徽章上方的角标标签，例如 "concept" / "task" / "project"。 */
  kind?: string;
  /** 预估时长文本，例如 "40 分钟"。 */
  duration?: string;
}

/**
 * 纸质教材风 Hero 页头：
 * - 上层：主图 + 角标 + 右上角品牌水印
 * - 中层：居中胶囊徽章（eyebrow + title）
 * - 下层：subtitle + duration chip
 *
 * 没有 heroImage 时退化为纯墨绿-米黄渐变+装饰纹理，保持教材风。
 */
export function LessonHeroBanner({
  eyebrow,
  title,
  subtitle,
  heroImage,
  brand,
  kind,
  duration,
}: LessonHeroBannerProps) {
  return (
    <section
      className={`dgb-lesson-hero${heroImage ? ' has-image' : ''}`}
      style={heroImage ? { backgroundImage: `url(${heroImage})` } : undefined}
      aria-label={eyebrow ? `${eyebrow}：${title}` : title}
    >
      <div className="dgb-lesson-hero-veil" aria-hidden />
      {kind && <span className="dgb-lesson-hero-kind">{kind}</span>}
      {brand && <span className="dgb-lesson-hero-brand">{brand}</span>}
      <div className="dgb-lesson-hero-inner">
        <div className="dgb-lesson-hero-pill">
          {eyebrow && <span className="dgb-lesson-hero-eyebrow">{eyebrow}</span>}
          <h1 className="dgb-lesson-hero-title">{title}</h1>
        </div>
        {subtitle && <p className="dgb-lesson-hero-subtitle">{subtitle}</p>}
        {duration && (
          <span className="dgb-lesson-hero-duration">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
              <circle cx="12" cy="12" r="9" />
              <path d="M12 7v5l3 2" />
            </svg>
            {duration}
          </span>
        )}
      </div>
    </section>
  );
}
