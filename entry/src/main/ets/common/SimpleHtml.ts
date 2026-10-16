// The campaign text and footer are short HTML (<b>, <i>, <br>, <a href>). ScrollableEducationPanel
// renders them as attributed strings; here they become runs for Spans.

export class HtmlRun {
  text: string = '';
  bold: boolean = false;
  italic: boolean = false;
  href: string = '';
}

function decodeEntities(text: string): string {
  return text.replace(/&nbsp;/g, ' ').replace(/&quot;/g, '"').replace(/&#39;|&apos;/g, '\'')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&');
}

export function htmlRuns(html: string): HtmlRun[] {
  const runs: HtmlRun[] = [];
  let bold: number = 0;
  let italic: number = 0;
  let href: string = '';
  const re: RegExp = /<\s*(\/?)\s*([a-zA-Z]+)([^>]*)>|([^<]+)/g;
  // TemplateStyles and scripts carry no text
  html = html.replace(/<(style|script)[^>]*>[\s\S]*?<\/\1>/gi, '');
  let m: RegExpExecArray | null = re.exec(html);
  while (m !== null) {
    if (m[4] !== undefined) {
      const run: HtmlRun = new HtmlRun();
      run.text = decodeEntities(m[4]);
      run.bold = bold > 0;
      run.italic = italic > 0;
      run.href = href;
      runs.push(run);
    } else {
      const closing: boolean = m[1] === '/';
      const tag: string = m[2].toLowerCase();
      if (tag === 'br' || closing && (tag === 'p' || tag === 'div' || tag === 'li' || tag === 'tr')) {
        const run: HtmlRun = new HtmlRun();
        run.text = '\n';
        runs.push(run);
      } else if (tag === 'b' || tag === 'strong') {
        bold += closing ? -1 : 1;
      } else if (tag === 'i' || tag === 'em') {
        italic += closing ? -1 : 1;
      } else if (tag === 'a') {
        if (closing) {
          href = '';
        } else {
          const h: RegExpMatchArray | null = m[3].match(/href\s*=\s*(["'])(.*?)\1/i);
          href = h !== null ? decodeEntities(h[2]) : '';
        }
      }
    }
    m = re.exec(html);
  }
  return runs;
}
