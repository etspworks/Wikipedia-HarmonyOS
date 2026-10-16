// Ported from WMFWhichCameFirstArchiveViewController + WMFWhichCameFirstArchiveView(Model): an X
// close over the mid background, the calendar-clock glyph, "Which came first? Archive" (bold +
// regular), "Play games since June 2024." and a calendar card from June 2024 to today
// (UICalendarView). Completed days carry a dot; tapping one shows "You scored N / 5 on this
// day."; tapping any other day in range (or a paused one) goes back to the game with that day.
import { router, promptAction } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import { GameStore, ArchiveEntry } from '../common/GameStore';
import { formatString } from '../common/Plural';

// archiveStartDate: 2024-06-01
const ARCHIVE_START_YEAR: number = 2024;
const ARCHIVE_START_MONTH: number = 5;   // June, 0-based

function isoDay(y: number, m: number, d: number): string {
  return y + '-' + String(m + 1).padStart(2, '0') + '-' + String(d).padStart(2, '0');
}

@Entry
@Component
struct WMFWhichCameFirstArchiveViewControllerPage {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';
  @StorageProp('wmfMidBg') wmfMidBg: string = '';

  @State year: number = new Date().getFullYear();
  @State month: number = new Date().getMonth();
  // playedDates (yyyy-MM-dd -> score) and pausedDates
  @State played: Map<string, number> = new Map<string, number>();
  private paused: Set<string> = new Set<string>();
  private languageCode: string = 'en';
  private firstWeekday: number = 0;

  aboutToAppear(): void {
    const params: Record<string, string> | undefined = router.getParams() as Record<string, string>;
    this.languageCode = params !== undefined ? (params['languageCode'] ?? 'en') : 'en';
    try {
      this.firstWeekday = i18n.getCalendar(i18n.System.getSystemLocale()).getFirstDayOfWeek() - 1;
    } catch (e) {
      this.firstWeekday = 0;
    }
    GameStore.fetchArchive('wikipedia.' + this.languageCode).then((entries: ArchiveEntry[]) => {
      const played: Map<string, number> = new Map<string, number>();
      for (const e of entries) {
        const day: string = (e.dailyGameDate ?? '').substring(0, 10);
        if (e.paused) {
          this.paused.add(day);
        } else {
          played.set(day, e.score);
        }
      }
      this.played = played;
    }).catch((e: Error) => {
      console.error('archive: sessions failed: ' + e.message);
    });
  }

  private isAvailable(y: number, m: number, d: number): boolean {
    const day: Date = new Date(y, m, d);
    return day.getTime() <= Date.now() && day >= new Date(ARCHIVE_START_YEAR, ARCHIVE_START_MONTH, 1);
  }

  // selectDay
  private selectDay(y: number, m: number, d: number): void {
    const day: string = isoDay(y, m, d);
    const score: number | undefined = this.played.get(day);
    if (score !== undefined) {
      promptAction.showToast({ message: formatString(getContext(this),
        $r('app.string.which_came_first_archive_toast_score'), [String(score)]) });
    } else if (this.paused.has(day) || this.isAvailable(y, m, d)) {
      // showGameForArchiveDate: dismiss the archive and reload the game with that day
      router.back({ url: 'pages/WMFWhichCameFirstViewPage', params: { 'date': day, 'languageCode': this.languageCode } });
    }
  }

  // the month grid: leading blanks for the first weekday, then the days
  private cells(): number[] {
    const lead: number = (new Date(this.year, this.month, 1).getDay() - this.firstWeekday + 7) % 7;
    const count: number = new Date(this.year, this.month + 1, 0).getDate();
    const out: number[] = [];
    for (let i = 0; i < lead; i++) {
      out.push(0);
    }
    for (let d = 1; d <= count; d++) {
      out.push(d);
    }
    return out;
  }

  private weekdaySymbols(): string[] {
    const out: string[] = [];
    // 2024-06-02 is a Sunday
    for (let i = 0; i < 7; i++) {
      const day: Date = new Date(2024, 5, 2 + (i + this.firstWeekday) % 7);
      out.push(day.toLocaleDateString(i18n.System.getSystemLocale(), { weekday: 'short' }).toUpperCase());
    }
    return out;
  }

  private monthTitle(): string {
    return new Date(this.year, this.month, 1).toLocaleDateString(i18n.System.getSystemLocale(),
      { month: 'long', year: 'numeric' });
  }

  private canGoBack(): boolean {
    return this.year * 12 + this.month > ARCHIVE_START_YEAR * 12 + ARCHIVE_START_MONTH;
  }

  private canGoForward(): boolean {
    const now: Date = new Date();
    return this.year * 12 + this.month < now.getFullYear() * 12 + now.getMonth();
  }

  private step(delta: number): void {
    const total: number = this.year * 12 + this.month + delta;
    this.year = Math.floor(total / 12);
    this.month = total % 12;
  }

  @Builder
  dayCell(day: number) {
    Column() {
      if (day > 0) {
        Text(String(day))
          .fontSize(20)
          .fontColor(this.isAvailable(this.year, this.month, day) ? $r('app.color.theme_text')
            : $r('app.color.theme_secondary_text'))
          .opacity(this.isAvailable(this.year, this.month, day) ? 1 : 0.4)
        // circlebadge.fill decoration in the tint colour on completed days
        Circle()
          .width(6)
          .height(6)
          .margin({ top: 3 })
          .fill($r('app.color.theme_link'))
          .opacity(this.played.has(isoDay(this.year, this.month, day)) ? 1 : 0)
      }
    }
    .id(day > 0 ? 'archive_day_' + isoDay(this.year, this.month, day) : '')
    .width('14.28%')
    .height(52)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (day > 0) {
        this.selectDay(this.year, this.month, day);
      }
    })
  }

  build() {
    Column() {
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor([$r('app.color.theme_text')])
        }
          .id('CloseButton')
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(44)
          .height(44)
          .onClick(() => {
            router.back();
          })
        Blank()
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 8 })

      Scroll() {
        Column() {
          // headerSection
          Column({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.calendar_badge_clock'))
              .fontSize(64)
              .fontColor([$r('app.color.theme_text')])
              .margin({ bottom: 12 })
            Text() {
              Span($r('app.string.which_came_first_archive_title'))
                .fontWeight(FontWeight.Bold)
              Span(' ')
              Span($r('app.string.which_came_first_archive_nav_title'))
            }
              .fontSize(22)
              .fontColor($r('app.color.theme_text'))
              .textAlign(TextAlign.Center)
            Text($r('app.string.which_came_first_archive_subtitle'))
              .fontSize(17)
              .fontColor($r('app.color.theme_text'))
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 16, bottom: 32 })

          // calendarCard
          Column() {
            Row() {
              Text(this.monthTitle())
                .layoutWeight(1)
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.theme_text'))
              SymbolGlyph($r('sys.symbol.chevron_left'))
                .id('archive_previous_month')
                .fontSize(20)
                .fontColor([$r('app.color.theme_link')])
                .opacity(this.canGoBack() ? 1 : 0.3)
                .padding(10)
                .onClick(() => {
                  if (this.canGoBack()) {
                    this.step(-1);
                  }
                })
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .id('archive_next_month')
                .fontSize(20)
                .fontColor([$r('app.color.theme_link')])
                .opacity(this.canGoForward() ? 1 : 0.3)
                .padding(10)
                .onClick(() => {
                  if (this.canGoForward()) {
                    this.step(1);
                  }
                })
            }
            .width('100%')
            .padding({ left: 16, right: 6, top: 10 })
            Row() {
              ForEach(this.weekdaySymbols(), (w: string) => {
                Text(w)
                  .width('14.28%')
                  .textAlign(TextAlign.Center)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.theme_secondary_text'))
              }, (w: string, i: number) => i + w)
            }
            .width('100%')
            .padding({ top: 8, bottom: 4 })
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.cells(), (day: number) => {
                this.dayCell(day)
              }, (day: number, i: number) => this.year + '-' + this.month + '-' + i + '-' + day + '-' +
                this.played.has(isoDay(this.year, this.month, day)))
            }
            .width('100%')
            .padding({ bottom: 12 })
          }
          .width('100%')
          .borderRadius(16)
          .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
          .shadow({ radius: 8, color: '#0D000000' })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .id('WMFWhichCameFirstArchiveViewController')
    .width('100%')
    .height('100%')
    .backgroundColor((this.wmfMidBg !== '' ? this.wmfMidBg : $r('app.color.theme_mid_background')))
  }
}
