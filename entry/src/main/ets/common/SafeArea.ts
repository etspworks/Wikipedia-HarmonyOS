import { display } from '@kit.ArkUI';

// The status-bar inset, published once per launch by EntryAbility.
//
// A screen presented with .bindContentCover draws under the system status bar, so its nav
// row - and the close button in it - ends up beneath the clock and battery icons and is
// awkward to hit. Routed pages do not have this problem. Cover screens apply this inset to
// their own root instead, which keeps their background full-bleed while their content
// starts below the status bar.
export const TOP_SAFE_INSET_KEY: string = 'topSafeInset';

export function topSafeInset(): number {
  const value: number | undefined = AppStorage.get<number>(TOP_SAFE_INSET_KEY);
  return value === undefined ? 0 : value;
}

// The navigation-indicator (gesture handle) strip at the bottom, in vp; 0 with button navigation.
export const NAV_INDICATOR_INSET_KEY: string = 'navIndicatorInset';

// The phone's width against a 360 vp phone, clamped to 0.9..1.25. Article chrome that keeps the
// source's point sizes in proportion (toolbar glyphs, table of contents) scales with it, like the
// tab bar's icons.
export function widthScale(): number {
  try {
    const d: display.Display = display.getDefaultDisplaySync();
    return Math.min(1.25, Math.max(0.9, d.width / d.densityPixels / 360));
  } catch (e) {
    return 1;
  }
}
