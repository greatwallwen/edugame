import './VideoBlock.css';

export interface VideoBlockProps {
  src: string;
  poster?: string;
  caption?: string;
}

/**
 * Video 原语：HTML5 video 播放器
 * N1 安全：使用标准 HTML5 video，无外部依赖
 * N6：成熟方案优先（原生 video API）
 */
export function VideoBlock({ src, poster, caption }: VideoBlockProps) {
  return (
    <figure className="dgb-video" aria-label="视频">
      <video
        className="dgb-video-player"
        controls
        preload="metadata"
        poster={poster}
      >
        <source src={src} type={inferMimeType(src)} />
        <div className="dgb-video-fallback">
          您的浏览器不支持视频播放。
          <a href={src} target="_blank" rel="noopener noreferrer">下载视频</a>
        </div>
      </video>
      {caption ? <figcaption className="dgb-video-caption">{caption}</figcaption> : null}
    </figure>
  );
}

/** 根据文件扩展名推断 MIME type */
function inferMimeType(src: string): string {
  const ext = src.split('?')[0]?.split('.').pop()?.toLowerCase();
  switch (ext) {
    case 'mp4': return 'video/mp4';
    case 'webm': return 'video/webm';
    case 'ogg': return 'video/ogg';
    default: return 'video/mp4';
  }
}
