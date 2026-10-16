// The editor's Insert media flow (Wikipedia/Code/InsertMedia*.swift, Advanced Settings/): the
// chosen Commons file and its settings, shared by the Insert media, Media settings and Advanced
// settings screens, and the wikitext Insert puts into the editor.

// InsertMediaSettings.Advanced.ImagePosition / ImageType
export type ImagePosition = 'right' | 'left' | 'center' | 'none';
export type ImageType = 'thumb' | 'frameless' | 'frame' | 'basic';

// InsertMediaSettings.Advanced.ImageSize: default is "220x124px"
export const DEFAULT_IMAGE_WIDTH: number = 220;
export const DEFAULT_IMAGE_HEIGHT: number = 124;

export class InsertMediaSettings {
  caption: string = '';
  alternativeText: string = '';
  wrapTextAroundImage: boolean = true;
  // the Image position screen's choice; wrap off makes it none
  position: ImagePosition = 'right';
  type: ImageType = 'thumb';
  customSize: boolean = false;
  width: string = String(DEFAULT_IMAGE_WIDTH);
  height: string = String(DEFAULT_IMAGE_HEIGHT);

  // InsertMediaImagePositionSettingsViewController.selectedImagePosition
  effectivePosition(): ImagePosition {
    return this.wrapTextAroundImage ? this.position : 'none';
  }

  // InsertMediaImageSizeSettingsViewController.selectedImageSize: custom only with both numbers
  sizeRawValue(): string {
    const w: number = parseInt(this.width, 10);
    const h: number = parseInt(this.height, 10);
    if (!this.customSize || Number.isNaN(w) || Number.isNaN(h)) {
      return `${DEFAULT_IMAGE_WIDTH}x${DEFAULT_IMAGE_HEIGHT}px`;
    }
    return `${w}x${h}px`;
  }

  isCustomSize(): boolean {
    return this.sizeRawValue() !== `${DEFAULT_IMAGE_WIDTH}x${DEFAULT_IMAGE_HEIGHT}px`;
  }
}

// InsertMediaSettingsViewController.prepareWikitext: file, type, size, position, alt, caption.
// The English magic words, which every wiki accepts. Empty or blank caption and alt text are left
// out; otherwise they go in as typed (the source does not escape them). With alt text but no
// caption the source writes two spaces after the bar, kept here.
export function mediaWikitext(fileTitle: string, s: InsertMediaSettings): string {
  const type: string = s.type === 'basic' ? '' : ` | ${s.type}`;
  const size: string = s.isCustomSize() ? ` | ${s.sizeRawValue()}` : '';
  const head: string = `[[${fileTitle}${type}${size} | ${s.effectivePosition()}`;
  const caption: string | null = s.caption.trim() === '' ? null : s.caption;
  const alt: string | null = s.alternativeText.trim() === '' ? null : s.alternativeText;
  if (caption !== null && alt !== null) {
    return `${head} | alt=${alt} | ${caption}]]`;
  } else if (caption !== null) {
    return `${head} | ${caption}]]`;
  } else if (alt !== null) {
    return `${head} |  alt=${alt}]]`;
  }
  return `${head}]]`;
}

// MWKSearchResult display title for a file: "File:Foo bar.jpg" -> "Foo bar" (the source drops the
// first five characters and the last four)
export function fileDisplayTitle(fileTitle: string): string {
  return fileTitle.length > 9 ? fileTitle.substring(5, fileTitle.length - 4) : fileTitle;
}

// ImageUtils: MediaWiki's thumbnail buckets; a width is rounded up to the next one
const THUMB_BUCKETS: number[] = [20, 40, 60, 120, 250, 330, 500, 960, 1280, 1920, 3840];

export function thumbnailURL(url: string, width: number): string {
  const bucket: number = THUMB_BUCKETS.find((b: number) => b >= width) ?? THUMB_BUCKETS[THUMB_BUCKETS.length - 1];
  return url.replace(/\/(\d+)px-([^\/]+)$/, `/${bucket}px-$2`);
}

// LicenseView: the icon for each part of a license code ("cc-by-sa-4.0" -> cc, by, sa)
export function licenseIconNames(code: string): string[] {
  const names: Record<string, string> = {
    'cc': 'license_cc', 'by': 'license_by', 'sa': 'license_sa', 'cc0': 'license_cc0', 'pd': 'license_pd',
    'nc': 'license_non_commercial', 'nd': 'license_no_derivatives'
  };
  return code.toLowerCase().split('-').map((part: string) => names[part] ?? '').filter((n: string) => n !== '');
}

// The flow's state between its screens: the article, the chosen file and its settings
export class InsertMediaSession {
  static articleTitle: string = '';
  static host: string = 'en.wikipedia.org';
  static fileTitle: string = '';
  static displayTitle: string = '';
  static imageURL: string = '';
  static imageDescription: string = '';
  static filePageURL: string = '';
  static settings: InsertMediaSettings = new InsertMediaSettings();

  static start(articleTitle: string, host: string): void {
    InsertMediaSession.articleTitle = articleTitle;
    InsertMediaSession.host = host;
    InsertMediaSession.fileTitle = '';
    InsertMediaSession.settings = new InsertMediaSettings();
  }
}

// the wikitext the editor inserts when it shows again
export const INSERT_MEDIA_RESULT_KEY: string = 'wmfInsertMediaResult';

// WMFWikitextUtils.insertImageWikitextIntoArticleWikitextAfterTemplates: after the leading
// templates and comments (nested {{ }} and <!-- -->), on its own line. Throws on a "}}" or "-->"
// with no opening.
export function insertImageWikitextAfterTemplates(imageWikitext: string, articleWikitext: string): string {
  if (imageWikitext === '') {
    return articleWikitext;
  }
  const markups: string[][] = [['{{', '}}'], ['<!--', '-->']];
  const opens: number[][] = [[], []];
  const skip: number[][] = [];
  const skipped = (i: number): boolean => skip.some((r: number[]) => i >= r[0] && i < r[1]);
  for (let i = 0; i < articleWikitext.length; i++) {
    if (skipped(i) || articleWikitext[i] === '\n') {
      continue;
    }
    for (let m = 0; m < markups.length; m++) {
      const open: string = markups[m][0];
      const close: string = markups[m][1];
      if (i + open.length > articleWikitext.length || i + close.length > articleWikitext.length) {
        continue;
      }
      if (articleWikitext.substr(i, open.length) === open) {
        opens[m].push(i);
      } else if (articleWikitext.substr(i, close.length) === close) {
        const start: number | undefined = opens[m].pop();
        if (start === undefined) {
          throw new Error('closing template markup before opening markup');
        }
        skip.push([start, i + close.length]);
      }
    }
  }
  let finalIndex: number = 0;
  for (let i = 0; i < articleWikitext.length; i++) {
    if (articleWikitext[i] !== '\n' && !skipped(i)) {
      finalIndex = i;
      break;
    }
  }
  let image: string = imageWikitext;
  if (finalIndex !== 0) {
    image = articleWikitext[finalIndex - 1] === '\n' ? image + '\n' : '\n' + image + '\n';
  }
  return articleWikitext.substring(0, finalIndex) + image + articleWikitext.substring(finalIndex);
}
