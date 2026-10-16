// svc_theme — ported from WMF Framework/Theme.swift (Theme + Colors) and
// WMFComponents/Sources/WMFComponents/Style/WMFColor.swift (the palette hex values).
// UI-facing tokens; the theme name persists under the source's WMFAppThemeName key.

import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { uiAppearance } from '@kit.ArkUI';
import { Prefs, PrefKeys } from './Prefs';
import { BehaviorSubject } from './Reactive';

// --- WMFColor palette (hex, verbatim from WMFColor.swift) ---
export class WMFColor {
  static readonly black: string = '#000000';
  static readonly white: string = '#FFFFFF';
  static readonly gray800: string = '#101418';
  static readonly gray700: string = '#202122';
  static readonly gray675: string = '#27292D';
  static readonly gray650: string = '#2E3136';
  static readonly gray600: string = '#54595D';
  static readonly gray500: string = '#72777D';
  static readonly gray400: string = '#A2A9B1';
  static readonly gray300: string = '#C8CCD1';
  static readonly gray200: string = '#EAECF0';
  static readonly gray150: string = '#EEF2FB';
  static readonly gray100: string = '#F8F9FA';
  static readonly blue700: string = '#2A4B8D';
  static readonly blue600: string = '#3366CC';
  static readonly blue300: string = '#6699FF';
  static readonly blue100: string = '#EAF3FF';
  static readonly red700: string = '#B32424';
  static readonly red600: string = '#DD3333';
  static readonly red100: string = '#FEE7E6';
  static readonly green700: string = '#14866D';
  static readonly green600: string = '#00AF89';
  static readonly green100: string = '#D5FDF4';
  static readonly yellow600: string = '#FFCC33';
  static readonly beige400: string = '#E1DAD1';
  static readonly beige300: string = '#F0E6D6';
  static readonly beige100: string = '#F8F1E3';
  static readonly taupe600: string = '#646059';
  static readonly taupe200: string = '#CBC8C1';
  static readonly purple600: string = '#6B4BA1';
  static readonly orange600: string = '#FF9500';
}

// --- Font tokens ---
// Georgia has no guaranteed face on HarmonyOS devices: give every serif use a fallback stack.
export class WMFFontFamilies {
  // WMFSerif = rawfile/fonts/NotoSerif-Regular.ttf (SIL OFL), registered by the article page:
  // the device ships no Latin serif, so 'Georgia, serif' fell back to the sans face.
  static readonly serifStack: string = 'WMFSerif, Georgia, serif';
  // logo-wikipedia.ttf glyph font; registered at the UI layer (Phase 3) under this family name.
  static readonly wikipediaLogo: string = 'WikipediaLogo';
}

// AppStorage: true while the effective colour mode is dark (EntryAbility keeps it current).
export const IS_DARK_KEY: string = 'wmfIsDark';

export enum ThemeIdentifier {
  light = 'light',
  sepia = 'sepia',
  dark = 'dark',
  black = 'black'
}

// Ported from Theme.swift Colors — one resolved token set per identifier.
export class ThemeColors {
  identifier: ThemeIdentifier = ThemeIdentifier.light;
  baseBackground: string = WMFColor.gray200;
  midBackground: string = WMFColor.gray100;
  subCellBackground: string = WMFColor.white;
  paperBackground: string = WMFColor.white;
  popoverBackground: string = WMFColor.white;
  chromeBackground: string = WMFColor.white;
  chromeShadow: string = WMFColor.gray400;
  primaryText: string = WMFColor.gray700;
  secondaryText: string = WMFColor.gray500;
  tertiaryText: string = WMFColor.gray500;
  disabledText: string = WMFColor.gray500;
  disabledLink: string = WMFColor.gray600;
  chromeText: string = WMFColor.gray700;
  link: string = WMFColor.blue600;
  accent: string = WMFColor.green600;
  secondaryAction: string = WMFColor.blue700;
  destructive: string = WMFColor.red600;
  warning: string = WMFColor.orange600;
  error: string = WMFColor.red600;
  unselected: string = WMFColor.gray400;
  border: string = WMFColor.gray400;
  hintBackground: string = WMFColor.blue100;
  batchSelectionBackground: string = WMFColor.blue100;
  animationBackground: string = WMFColor.gray150;
  overlayText: string = WMFColor.gray600;

  static forIdentifier(identifier: ThemeIdentifier): ThemeColors {
    const c = new ThemeColors();
    c.identifier = identifier;
    if (identifier === ThemeIdentifier.light) {
      return c; // defaults above ARE the light palette
    }
    if (identifier === ThemeIdentifier.sepia) {
      c.baseBackground = WMFColor.beige400;
      c.midBackground = WMFColor.beige300;
      c.subCellBackground = WMFColor.beige300;
      c.paperBackground = WMFColor.beige100;
      c.popoverBackground = WMFColor.white;
      c.chromeBackground = WMFColor.beige100;
      c.chromeShadow = WMFColor.taupe200;
      c.primaryText = WMFColor.gray700;
      c.secondaryText = WMFColor.taupe600;
      c.tertiaryText = WMFColor.taupe600;
      c.disabledText = WMFColor.taupe600;
      c.disabledLink = WMFColor.gray500;
      c.chromeText = WMFColor.gray700;
      c.link = WMFColor.blue600;
      c.destructive = WMFColor.red700;
      c.error = WMFColor.red700;
      c.unselected = WMFColor.taupe600;
      c.border = WMFColor.taupe200;
      c.hintBackground = WMFColor.blue100;
      c.batchSelectionBackground = WMFColor.blue100;
      c.animationBackground = WMFColor.gray150;
      return c;
    }
    // dark and black share most tokens.
    c.baseBackground = WMFColor.gray800;
    c.midBackground = WMFColor.gray700;
    c.subCellBackground = WMFColor.gray700;
    c.paperBackground = identifier === ThemeIdentifier.dark ? WMFColor.gray675 : WMFColor.black;
    c.popoverBackground = identifier === ThemeIdentifier.dark ? WMFColor.gray800 : WMFColor.gray700;
    c.chromeBackground = WMFColor.gray650;
    c.chromeShadow = identifier === ThemeIdentifier.dark ? WMFColor.gray650 : WMFColor.gray675;
    c.primaryText = WMFColor.gray100;
    c.secondaryText = WMFColor.gray300;
    c.tertiaryText = WMFColor.gray300;
    c.disabledText = WMFColor.gray300;
    c.disabledLink = WMFColor.gray400;
    c.chromeText = WMFColor.gray100;
    c.link = WMFColor.blue300;
    c.warning = WMFColor.yellow600;
    c.unselected = WMFColor.gray300;
    c.border = identifier === ThemeIdentifier.dark ? WMFColor.gray650 : WMFColor.gray675;
    c.hintBackground = identifier === ThemeIdentifier.dark ? WMFColor.gray800 : WMFColor.gray650;
    c.batchSelectionBackground = WMFColor.blue700;
    c.animationBackground = WMFColor.gray700;
    return c;
  }
}

// Ported from Theme.swift Theme.
export class WMFTheme {
  static readonly defaultThemeName: string = 'standard';
  static readonly dimmedImageOpacity: number = 0.65;
  static readonly exploreCardCornerRadius: number = 10;

  colors: ThemeColors = new ThemeColors();
  isDark: boolean = false;
  imageOpacity: number = 1;
  name: string = 'light';
  displayName: string = 'Light';
  webName: string = 'light';

  private static make(identifier: ThemeIdentifier, imageOpacity: number, name: string,
    displayName: string, webName: string): WMFTheme {
    const t = new WMFTheme();
    t.colors = ThemeColors.forIdentifier(identifier);
    t.isDark = identifier === ThemeIdentifier.dark || identifier === ThemeIdentifier.black;
    t.imageOpacity = imageOpacity;
    t.name = name;
    t.displayName = displayName;
    t.webName = webName;
    return t;
  }

  static readonly light: WMFTheme = WMFTheme.make(ThemeIdentifier.light, 1, 'light', 'Light', 'light');
  static readonly sepia: WMFTheme = WMFTheme.make(ThemeIdentifier.sepia, 1, 'sepia', 'Sepia', 'sepia');
  static readonly dark: WMFTheme = WMFTheme.make(ThemeIdentifier.dark, 1, 'dark', 'Dark', 'dark');
  static readonly darkDimmed: WMFTheme =
    WMFTheme.make(ThemeIdentifier.dark, WMFTheme.dimmedImageOpacity, 'dark-dimmed', 'Dark', 'dark');
  static readonly black: WMFTheme = WMFTheme.make(ThemeIdentifier.black, 1, 'black', 'Black', 'black');
  static readonly blackDimmed: WMFTheme =
    WMFTheme.make(ThemeIdentifier.black, WMFTheme.dimmedImageOpacity, 'black-dimmed', 'Black', 'black');
  static readonly standard: WMFTheme = WMFTheme.light;

  get isDimmed(): boolean {
    return this.imageOpacity < 1;
  }

  static isDefaultThemeName(name: string | null): boolean {
    if (name === null) {
      return true;
    }
    return name === WMFTheme.defaultThemeName;
  }

  static isDarkThemeName(name: string | null): boolean {
    if (name === null) {
      return false;
    }
    return name.startsWith('dark') || name.startsWith('black');
  }

  static withName(name: string | null): WMFTheme | null {
    if (name === 'light') {
      return WMFTheme.light;
    }
    if (name === 'sepia') {
      return WMFTheme.sepia;
    }
    if (name === 'dark') {
      return WMFTheme.dark;
    }
    if (name === 'dark-dimmed') {
      return WMFTheme.darkDimmed;
    }
    if (name === 'black') {
      return WMFTheme.black;
    }
    if (name === 'black-dimmed') {
      return WMFTheme.blackDimmed;
    }
    return null;
  }

  withDimmingEnabled(isDimmingEnabled: boolean): WMFTheme {
    const baseName: string = this.name.split('-')[0];
    const adjustedName: string = isDimmingEnabled ? baseName + '-dimmed' : baseName;
    return WMFTheme.withName(adjustedName) ?? this;
  }
}

export class ThemeManager {
  static readonly theme: BehaviorSubject<WMFTheme> = new BehaviorSubject<WMFTheme>(WMFTheme.standard);
  private static appContext: common.ApplicationContext | null = null;

  // EntryAbility.onCreate, after Prefs.init. The screens paint with the theme_* colour
  // resources, so a theme reaches every screen only through the app's colour mode (dark/black
  // resolve the `dark` resource set). Before this the choice was stored and published but
  // only the settings row and the article image opacity read it.
  static attach(context: common.ApplicationContext): void {
    ThemeManager.appContext = context;
    ThemeManager.restore();
  }

  private static applyColorMode(theme: WMFTheme, followSystem: boolean): void {
    const ctx: common.ApplicationContext | null = ThemeManager.appContext;
    if (ctx === null) {
      return;
    }
    try {
      ctx.setColorMode(followSystem ? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
        : theme.isDark ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
          : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (e) {
      console.error('theme: setColorMode failed: ' + (e as Error).message);
    }
  }

  // Light and Dark come from the theme_* colour resources (the colour mode picks the set), but
  // Sepia and Black have no resource set, so only screens that painted them by hand changed.
  // Their backgrounds are published here and every screen reads them (@StorageProp('wmf*Bg'));
  // an empty value means "use the resource", which keeps Default following the device.
  private static publishBackgrounds(theme: WMFTheme): void {
    const id: ThemeIdentifier = theme.colors.identifier;
    const own: boolean = id === ThemeIdentifier.sepia || id === ThemeIdentifier.black;
    const c: ThemeColors = theme.colors;
    AppStorage.setOrCreate<string>('wmfPaperBg', own ? c.paperBackground : '');
    AppStorage.setOrCreate<string>('wmfMidBg', id === ThemeIdentifier.sepia ? c.midBackground : '');
    AppStorage.setOrCreate<string>('wmfBaseBg', id === ThemeIdentifier.sepia ? c.baseBackground : '');
    AppStorage.setOrCreate<string>('wmfChromeBg', id === ThemeIdentifier.sepia ? c.chromeBackground : '');
    AppStorage.setOrCreate<string>('wmfPopoverBg', own ? c.popoverBackground : '');
  }

  // NSUserDefaults+WMFExtensions theme(compatibleWith:): the Default ('standard') theme follows
  // the device, Black in dark mode and Light otherwise. The one place Default is resolved, so
  // picking Default, a cold start and a device switch all land on the same theme. Asks the
  // device, not this app's configuration, which still reads dark right after Dark was picked.
  static resolveDefault(): WMFTheme {
    try {
      return uiAppearance.getDarkMode() === uiAppearance.DarkMode.ALWAYS_DARK ? WMFTheme.black : WMFTheme.light;
    } catch (e) {
      console.error('theme: reading the device colour mode failed: ' + (e as Error).message);
      return WMFTheme.light;
    }
  }

  // EntryAbility.onConfigurationUpdate: under Default a device light/dark switch has to
  // re-resolve the theme too, or Black's black surfaces stay up over the light colour mode.
  // Never sets the colour mode itself: setColorMode delivers onConfigurationUpdate
  // synchronously, so doing it from here looped until the main thread froze.
  static deviceColorModeChanged(): void {
    // EntryAbility.onCreate's setColorMode lands here before Prefs.init; restore() runs after.
    if (ThemeManager.appContext === null) {
      return;
    }
    const name: string = Prefs.getString(PrefKeys.appThemeName, WMFTheme.defaultThemeName);
    if (!WMFTheme.isDefaultThemeName(name)) {
      return;
    }
    const theme: WMFTheme = ThemeManager.resolve(name);
    if (theme.name === ThemeManager.theme.value.name) {
      return;
    }
    ThemeManager.publish(theme);
  }

  // A stored theme name as the screens get it: Default resolved, dark themes dimmed per the switch.
  private static resolve(name: string): WMFTheme {
    const theme: WMFTheme = WMFTheme.isDefaultThemeName(name)
      ? ThemeManager.resolveDefault()
      : (WMFTheme.withName(name) ?? WMFTheme.standard);
    return theme.isDark ? theme.withDimmingEnabled(Prefs.getBoolean(PrefKeys.isImageDimmingEnabled, false)) : theme;
  }

  private static publish(theme: WMFTheme): void {
    ThemeManager.theme.next(theme);
    AppStorage.setOrCreate<string>(PrefKeys.appThemeName, theme.name);
    ThemeManager.publishBackgrounds(theme);
  }

  // Call after Prefs.init: restores WMFAppThemeName + WMFIsImageDimmingEnabled.
  static restore(): void {
    const name: string = Prefs.getString(PrefKeys.appThemeName, WMFTheme.defaultThemeName);
    const theme: WMFTheme = ThemeManager.resolve(name);
    ThemeManager.publish(theme);
    ThemeManager.applyColorMode(theme, WMFTheme.isDefaultThemeName(name));
  }

  // followSystem: the Default row - the colour mode keeps tracking the device.
  static setTheme(theme: WMFTheme, followSystem: boolean = false): void {
    Prefs.putString(PrefKeys.appThemeName, theme.name);
    ThemeManager.theme.next(theme);
    // Every themed page reads @StorageProp('WMFAppThemeName'); publishing here is what
    // restyles them, so it belongs with the persist, not in each caller.
    AppStorage.setOrCreate<string>(PrefKeys.appThemeName, theme.name);
    ThemeManager.publishBackgrounds(theme);
    ThemeManager.applyColorMode(theme, followSystem);
  }

  static setImageDimming(enabled: boolean): void {
    Prefs.putBoolean(PrefKeys.isImageDimmingEnabled, enabled);
    ThemeManager.theme.next(ThemeManager.theme.value.withDimmingEnabled(enabled));
  }
}
