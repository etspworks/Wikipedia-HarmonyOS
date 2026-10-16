// comp_toc_panel — from Wikipedia/Code/TableOfContentsViewController.swift, TableOfContentsCell
// (.swift + .xib) and TableOfContentsHeader (.swift + .xib): one scrolling table whose section
// header is the small "CONTENTS" caption, followed by the article title and its sections. The
// presentation around it (slide-in panel, dimmed strip, close button) is TableOfContentsView.

import { common } from '@kit.AbilityKit';
import { upperText } from '../common/LocaleText';
import { LengthMetrics } from '@kit.ArkUI';
import { WMFFontFamilies } from '../common/ThemeManager';
import { widthScale } from '../common/SafeArea';

// The source's points, drawn on a 440 pt phone, on the toolbar glyphs' scale (0.88 vp per pt on
// a 360 vp phone). The fonts are fitted to the source's line widths: Noto Serif is about 5 %
// wider than Georgia, and HarmonyOS Sans about 5 % narrower than SF.
const S: number = 0.88 * widthScale();
const TITLE_SIZE: number = 20 * 0.95 * S;   // georgiaTitle3
const SUB_SIZE: number = 15 * 1.05 * S;     // subheadline

export class TocItem {
  anchor: string = '';
  title: string = '';
  // 1 = an h2 section (and the footer entries), 2 = h3, ...: the source's indentationLevel + 1
  level: number = 1;
}

// One row as TableOfContentsCell lays it out. The article title is a row like the others
// (TableOfContentsItem id 0, anchor ''), so it scrolls with the list instead of staying pinned
// over it.
class TocRow {
  anchor: string = '';
  title: string = '';
  indentation: number = 0;
}

@Component
export struct TableOfContentsViewController {
  // Sepia/Black background overrides (ThemeManager.publishBackgrounds)
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  @Prop items: TocItem[] = [];
  @Prop articleTitle: string = '';
  // The section in view when the panel opened ('' = the article top).
  @Prop currentAnchor: string = '';
  onSelect?: (anchor: string) => void;
  // The panel is built fresh each time it opens, so the rows and the selection are worked out
  // once here.
  private rowList: TocRow[] = [];
  private selected: number = 0;
  private root: number = 0;

  aboutToAppear(): void {
    this.rowList = this.rows();
    this.selected = this.selectedIndex(this.rowList);
    this.root = this.rootIndex(this.rowList);
  }

  private rows(): TocRow[] {
    const title: TocRow = new TocRow();
    title.title = this.articleTitle;
    const out: TocRow[] = [title];
    for (const item of this.items) {
      const row: TocRow = new TocRow();
      row.anchor = item.anchor;
      row.title = item.title;
      row.indentation = Math.max(0, item.level - 1);
      out.push(row);
    }
    return out;
  }

  private selectedIndex(rows: TocRow[]): number {
    return Math.max(0, rows.findIndex((r: TocRow) => r.anchor === this.currentAnchor));
  }

  // TableOfContentsItem.rootItemId: the top-level row the selected row belongs to. Only that
  // row carries the dot (setSectionSelected shows it on level-0 rows only).
  private rootIndex(rows: TocRow[]): number {
    let i: number = this.selectedIndex(rows);
    while (i > 0 && rows[i].indentation > 0) {
      i--;
    }
    return i;
  }

  @Builder
  cell(row: TocRow, index: number) {
    Row() {
      // selectedSectionIndicator: an 8 vp link-coloured dot, leading margin + 2, 7 vp below
      // the title's top
      Column()
        .width(8 * S)
        .height(8 * S)
        .borderRadius(4 * S)
        .backgroundColor($r('app.color.theme_link'))
        .opacity(index === this.root ? 1 : 0)
        .margin({ top: 7 * S })
      // TableOfContentsItemType: top-level rows in the serif title3, deeper rows in the
      // smaller secondary subheadline; the selected row in the link colour
      Text(row.title)
        .layoutWeight(1)
        .fontFamily(row.indentation === 0 ? WMFFontFamilies.serifStack : undefined)
        .fontSize(row.indentation === 0 ? TITLE_SIZE : SUB_SIZE)
        .lineSpacing(LengthMetrics.vp(3 * S))
        .fontColor(index === this.selected ? $r('app.color.theme_link')
          : row.indentation === 0 ? $r('app.color.theme_text') : $r('app.color.theme_secondary_text'))
        // indentationWidth 10 x (1 + level) after the dot
        .margin({ left: 10 * S * (1 + row.indentation) })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    // titleLabelTopConstraint: 19 on top-level rows, 11 on the rest; 10 below
    .padding({ left: 18 * S, right: 18 * S, top: (row.indentation === 0 ? 19 : 11) * S, bottom: 10 * S })
  }

  build() {
    // the table and its cells share the paper background in the modal presentation
    List({ initialIndex: Math.max(0, this.selected - 2) }) {
      // TableOfContentsHeader: "CONTENTS", subheadline, secondary text, scrolling with the rows
      ListItem() {
        Text(upperText(getContext(this) as common.Context, $r('app.string.table_of_contents_heading')))
          .id('Article Table of Contents View')
          .fontSize(SUB_SIZE)
          .fontColor($r('app.color.theme_secondary_text'))
          .width('100%')
          .padding({ left: 22 * S, right: 21 * S, top: 10 * S, bottom: 5 * S })
      }
      ForEach(this.rowList, (row: TocRow, index: number) => {
        ListItem() {
          this.cell(row, index)
        }
        // list row — shared id, index-resolved by replay (Rule 12 exception)
        .id('toc_itemroot')
        .onClick(() => {
          if (this.onSelect !== undefined) {
            this.onSelect(row.anchor);
          }
        })
      }, (row: TocRow, index: number) => index + '_' + row.anchor)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
