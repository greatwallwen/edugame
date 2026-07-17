import './TableBlock.css';

export interface TableBlockProps {
  headers: string[];
  rows: string[][];
  caption?: string;
}

export function TableBlock({ headers, rows, caption }: TableBlockProps) {
  return (
    <figure className="dgb-table">
      {caption ? <figcaption className="dgb-table-cap">{caption}</figcaption> : null}
      <div className="dgb-table-wrap">
        <table className="dgb-table-inner">
          <thead>
            <tr>
              {headers.map((h, i) => (
                <th key={i} scope="col">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((row, ri) => (
              <tr key={ri}>
                {row.map((cell, ci) => (
                  <td key={ci}>{cell}</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </figure>
  );
}
