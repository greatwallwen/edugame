import { useState } from 'react';
import type { InteractiveSpec } from '@dgbook/types';
import './HotspotBlock.css';

export interface HotspotBlockProps {
  spec: Extract<InteractiveSpec, { kind: 'hotspot' }>;
}

/**
 * 热点点击互动：底图上叠加热区，用户逐个点击标记。
 * 全部发现后显示成功反馈。
 */
export function HotspotBlock({ spec }: HotspotBlockProps) {
  const { prompt, image, hotspots } = spec;
  const total = hotspots.length;

  const [found, setFound] = useState<Set<string>>(new Set());
  const [submitted, setSubmitted] = useState(false);

  const clickSpot = (id: string) => {
    if (submitted || found.has(id)) return;
    setFound((prev) => {
      const next = new Set(prev);
      next.add(id);
      if (next.size === total) setSubmitted(true);
      return next;
    });
  };

  const isAllFound = found.size === total;

  return (
    <div className="dgb-hotspot">
      <h4 className="dgb-hotspot-title">🎯 {prompt}</h4>
      <p className="dgb-hotspot-hint">在图中找出 {total} 个关键位置，点击圆形热点标记。</p>
      <div className="dgb-hotspot-stage">
        <img src={image} alt="热点图" className="dgb-hotspot-img" draggable={false} />
        {hotspots.map((h, idx) => (
          <div
            key={h.id}
            className={`dgb-hotspot-area ${found.has(h.id) ? 'found' : ''}`}
            data-idx={idx + 1}
            style={{
              left: `${Math.max(0, h.x - h.radius)}px`,
              top: `${Math.max(0, h.y - h.radius)}px`,
              width: `${h.radius * 2}px`,
              height: `${h.radius * 2}px`,
            }}
            onClick={() => clickSpot(h.id)}
            title={found.has(h.id) ? h.description : '点击发现'}
          />
        ))}
      </div>
      {isAllFound && (
        <div className="dgb-hotspot-result ok">
          🎉 全部发现！你找到了所有 {total} 个关键点。
        </div>
      )}
      {submitted && (
        <div className="dgb-hotspot-found-list">
          {hotspots.filter((h) => found.has(h.id)).map((h) => (
            <div key={h.id} className="dgb-hotspot-found-item">
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                <circle cx="7" cy="7" r="6" stroke="currentColor" strokeWidth="2" />
                <path d="M4 7l2 2 4-4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
              </svg>
              {h.description}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
