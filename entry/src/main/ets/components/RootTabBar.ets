// comp_root_tab_bar — the persistent bottom tab bar (source: UITabBarController tab bar in
// Wikipedia/Code/WMFAppViewController.swift, setViewControllers([nav1..nav5])).
// Tab order = WMFAppTabType: main(0) Explore, places(1), saved(2), recent(3) Activity,
// search(4). The .id() of each tab is the VERBATIM capture slug applied by
// applyRootTabAccessibilityIdentifiers (WMFComponents AccessibilityIdentifiers.RootTab.*
// and SearchViewController tabButton).
// Rendered by each of the five root pages, so the bar is present in every captured state.
// Icons: the source's own tab-bar assets (Images.xcassets/tabbar-{explore,nearby,save,recent},
// template images tinted at runtime); Search is UITabBarItem(tabBarSystemItem: .search),
// which has no asset — sys.symbol.magnifyingglass per results/plan/icon-map.json ("exact").
// Style: a plain full-width HarmonyOS bottom tab bar, not the iOS 26 "Liquid Glass" floating
// pill + Search circle of the capture. All five tabs share one row on the paper surface, which
// runs down under the navigation indicator. The icons are the source's own vector assets rendered
// crisp; icon and label sizes match the source's share of the screen width and scale with it,
// and the selected tab sits on the source's selection capsule, tinted per theme.
import { router, Router, display } from '@kit.ArkUI';
import { Prefs, PrefKeys } from '../common/Prefs';

// The tab host. Explore lives inside it rather than being pushed as its own page.
const HOST_PAGE: string = 'pages/Index';
const EXPLORE_TAB: number = 0;

// captured palette (results/traversal-source/pages/ExploreViewController/base.png) for light;
// the bar follows the app theme like every other chrome surface.
const SELECTED_TINT: ResourceStr = $r('app.color.theme_link');      // selected icon + label
const UNSELECTED_TINT: ResourceStr = $r('app.color.theme_text');    // unselected icon + label

// template-image tints: alpha preserved, RGB replaced (same form as the page's BLUE_TINT);
// light: blue600 / gray700, dark: blue300 / gray100
function tint(r: number, g: number, b: number): number[] {
  return [0, 0, 0, 0, r, 0, 0, 0, 0, g, 0, 0, 0, 0, b, 0, 0, 0, 1, 0];
}
const SELECTED_FILTER: number[] = tint(0.2, 0.4, 0.8);
const UNSELECTED_FILTER: number[] = tint(0.125, 0.129, 0.133);
const SELECTED_FILTER_DARK: number[] = tint(0.4, 0.6, 1.0);
const UNSELECTED_FILTER_DARK: number[] = tint(0.973, 0.976, 0.98);

// Measured on the source (440 pt wide): the tab icon spans 5.4 % of the width and "Explore"
// 9.1 %. On a 360 vp phone that is a 21 vp icon box and a 10.5 fp label. The icon follows the
// phone width (clamped so a small phone keeps a usable target and a tablet-wide window does not
// balloon); the label is in fp, so it already follows the system font scale.
const ICON_SIZE_AT_360: number = 21;
const LABEL_SIZE: number = 10.5;
function scaledIconSize(): number {
  try {
    const d: display.Display = display.getDefaultDisplaySync();
    const widthVp: number = d.width / d.densityPixels;
    return Math.round(ICON_SIZE_AT_360 * Math.min(1.25, Math.max(0.9, widthVp / 360)));
  } catch (e) {
    return ICON_SIZE_AT_360;
  }
}
const ICON_SIZE: number = scaledIconSize();

// the source's selection capsule behind the selected tab, per theme (sampled from the iOS bar)
function capsuleColor(isDark: boolean, paperBg: string): string {
  if (paperBg !== '') {
    return isDark ? '#3A3A3A' : '#EDE9D7';         // Black / Sepia
  }
  return isDark ? '#4B4E53' : '#EDEDED';           // Dark / Light
}

export class RootTab {
  // A Resource, not a literal: the tab bar is the app's most visible chrome and it has to
  // follow the device language. Hardcoded English here meant a Turkish device still read
  // "Explore / Places / Saved".
  label: Resource;
  slug: string = '';
  url: string = '';
  icon: Resource | null = null;

  constructor(label: Resource, slug: string, url: string, icon: Resource | null) {
    this.label = label;
    this.slug = slug;
    this.url = url;
    this.icon = icon;
  }
}

export const ROOT_TABS: RootTab[] = [
  new RootTab($r('app.string.home_title'), 'Root Tab Explore Button', 'pages/ExploreViewControllerPage', $r('app.media.tabbar_explore')),
  new RootTab($r('app.string.places_title'), 'Root Tab Places Button', 'pages/PlacesViewControllerPage', $r('app.media.tabbar_nearby')),
  new RootTab($r('app.string.saved_title'), 'Root Tab Saved Button', 'pages/SavedViewControllerPage', $r('app.media.tabbar_save')),
  new RootTab($r('app.string.activity_tab_title'), 'Root Tab Activity Button', 'pages/WMFActivityTabViewControllerPage', $r('app.media.tabbar_recent')),
  new RootTab($r('app.string.search_title'), 'Search Tab Button', 'pages/SearchViewControllerPage', null)
];

// WMFAppDefaultTabType.explore = 0, .settings = 1.
export const DEFAULT_TAB_TYPE_EXPLORE: number = 0;

// ExploreFeedSettingsPrimary(.entireFeed): "Turning off the Explore tab will replace the
// Explore tab with a Settings tab." The replacement rides in slot 0, so the rest of the bar
// keeps its source order and every other tab's id is untouched.
// The large header title every root tab page draws above its content. One size for all of
// them: they had drifted to 34 (iOS large title) on some tabs and 28 on others. 28 sits next
// to HarmonyOS's own page titles (the system Settings title measures ~27 vp).
export const ROOT_TITLE_FONT_SIZE: number = 28;

const SETTINGS_TAB: RootTab =
  new RootTab($r('app.string.settings_title'), 'Root Tab Settings Button', 'pages/SettingsTabViewControllerPage', null);

// UITabBarController switches tabs in place, with no push animation. Tab pages ask this in
// their pageTransition: a switch started by the bar within the last moment runs at duration
// 0, while article pushes and pops keep the platform slide.
const ROOT_TAB_SWITCH_KEY: string = 'wmfRootTabSwitchAt';

export function isRootTabSwitch(): boolean {
  return Date.now() - (AppStorage.get<number>(ROOT_TAB_SWITCH_KEY) ?? 0) < 1500;
}

// The first root tab, as the reader's preference leaves it.
export function rootTabAt(index: number): RootTab {
  if (index === 0 && !isExploreTabEnabled()) {
    return SETTINGS_TAB;
  }
  return ROOT_TABS[index];
}

export function isExploreTabEnabled(): boolean {
  try {
    return Prefs.getNumber(PrefKeys.defaultTabType, DEFAULT_TAB_TYPE_EXPLORE) === DEFAULT_TAB_TYPE_EXPLORE;
  } catch (e) {
    // An unopened store means a fresh launch: the source default is the Explore tab.
    return true;
  }
}

// Route to root tab `index` the way the bar does (also used by "View on a map").
export function openRootTab(uiRouter: Router, index: number): void {
  // replaceUrl tore the outgoing tab down and built the incoming one from scratch, so
  // leaving Explore and coming back dropped the reader at the top of the feed again. A tab
  // that is already in the stack is popped back to, which keeps its live instance and its
  // scroll position; one that is not is pushed.
  const url: string = rootTabAt(index).url;
  AppStorage.setOrCreate<number>(ROOT_TAB_SWITCH_KEY, Date.now());
  // The Explore tab is not a page of its own in the stack: pages/Index hosts it in slot 0,
  // and the other tabs are pushed on top of Index. So the page to pop back to for tab 0 is
  // Index itself.
  const candidates: string[] = index === EXPLORE_TAB ? [url, HOST_PAGE] : [url];
  for (const candidate of candidates) {
    let existing: number = 0;
    try {
      existing = uiRouter.getStateByUrl(candidate).length;
    } catch (e) {
      existing = 0;
    }
    if (existing === 0) {
      continue;
    }
    try {
      uiRouter.back({ url: candidate });
      return;
    } catch (e) {
      console.error('root tab back failed: ' + (e as Error).message);
    }
  }
  uiRouter.pushUrl({ url: url }).catch((e: Error) => {
    console.error('root tab route failed: ' + e.message);
  });
}

@Component
export struct RootTabBar {
  // index of the active tab (UITabBarController.selectedIndex)
  @Prop selected: number = 0;
  @StorageProp('wmfIsDark') isDark: boolean = false;
  @StorageProp('wmfPaperBg') paperBg: string = '';
  // the gesture-handle strip under the bar (vp, 0 with button navigation)
  @StorageProp('navIndicatorInset') navIndicatorInset: number = 0;
  // when set, the host switches tabs in place; otherwise the bar routes to the tab's page
  onSelect?: (index: number) => void;

  private surface(): ResourceColor {
    return this.paperBg !== '' ? this.paperBg : $r('app.color.theme_paper_background');
  }

  private select(index: number): void {
    const cb: ((index: number) => void) | undefined = this.onSelect;
    if (cb !== undefined) {
      cb(index);
      return;
    }
    if (index === this.selected) {
      return;
    }
    openRootTab(this.getUIContext().getRouter(), index);
  }

  // The cells are centred in their 56 vp, but the bar's surface runs on through the gesture-handle
  // strip below, so the items looked pushed to the top edge. They drop by about a third of that
  // strip (capped), which balances them on any phone and changes nothing without the strip.
  // Visual only: the cell, its tap area and the bar height stay put.
  private itemOffset(): number {
    return Math.min(this.navIndicatorInset * 0.35, 12);
  }

  // A long translated label (Turkish "Kaydedilenler") gets a wider cell instead of a smaller
  // font, so every label keeps the same size and none runs into its neighbour.
  private cellWeight(index: number): number {
    try {
      const label: string = getContext(this).resourceManager.getStringSync(rootTabAt(index).label.id);
      return Math.max(1, label.length / 9);
    } catch (e) {
      return 1;
    }
  }

  @Builder
  tabCell(index: number) {
    Column() {
      Column({ space: 2 }) {
        // Search (UITabBarItem .search) and the Settings replacement have no tab-bar asset in
        // the source; both are system glyphs.
        if (rootTabAt(index).icon === null) {
          SymbolGlyph(index === 4 ? $r('sys.symbol.magnifyingglass') : $r('sys.symbol.gearshape'))
            .fontSize(ICON_SIZE - 1)
            .fontWeight(FontWeight.Medium)
            .fontColor([index === this.selected ? SELECTED_TINT : UNSELECTED_TINT])
            .height(ICON_SIZE)
        } else {
          Image(rootTabAt(index).icon!)
            .width(ICON_SIZE)
            .height(ICON_SIZE)
            .objectFit(ImageFit.Contain)
            .interpolation(ImageInterpolation.High)
            .colorFilter(new ColorFilter(index === this.selected ? (this.isDark ? SELECTED_FILTER_DARK : SELECTED_FILTER)
              : (this.isDark ? UNSELECTED_FILTER_DARK : UNSELECTED_FILTER)))
        }
        Text(rootTabAt(index).label)
          .fontSize(LABEL_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(index === this.selected ? SELECTED_TINT : UNSELECTED_TINT)
          .maxLines(1)
          // A translated label can be much longer than the English one - Turkish
          // "Kaydedilenler" against "Saved". Shrink to fit instead of cutting the word.
          .minFontSize(8.5)
          .maxFontSize(LABEL_SIZE)
          .heightAdaptivePolicy(TextHeightAdaptivePolicy.MAX_LINES_FIRST)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .padding({ left: 14, right: 14, top: 5, bottom: 5 })
      .translate({ y: this.itemOffset() })
      .borderRadius(100)
      .backgroundColor(index === this.selected ? capsuleColor(this.isDark, this.paperBg) : Color.Transparent)
      .alignItems(HorizontalAlign.Center)
    }
    .layoutWeight(this.cellWeight(index))
    .height(56)
    .justifyContent(FlexAlign.Center)
    // the lowered items reach a little below the cell: the tap area follows them down
    .responseRegion({ x: 0, y: 0, width: '100%', height: 56 + this.itemOffset() })
    .id(rootTabAt(index).slug)
    .onClick(() => {
      this.select(index);
    })
  }

  build() {
    Row() {
      this.tabCell(0)
      this.tabCell(1)
      this.tabCell(2)
      this.tabCell(3)
      this.tabCell(4)
    }
    // no fixed height here: expandSafeArea is ignored on a component with a fixed size, so
    // the 56 vp comes from the cells
    .width('100%')
    .backgroundColor(this.surface())
    .border({ width: { top: 0.5 }, color: $r('app.color.theme_border') })
    // the bar's surface also fills the navigation-indicator strip below it
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
