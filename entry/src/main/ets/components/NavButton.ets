// Title-bar buttons, HarmonyOS style (design-guides "Title Bar"; the device's own Settings
// app and the NetNewsWire port draw them the same way): every bar button is its own round
// 40 vp button on the system component_normal fill, no shadow. This replaces the port's
// "navChrome" token - white pills and circles with shadow(8, #1F000000) copied from iOS 26
// Liquid Glass - so grouped bar buttons are separate circles NAV_BUTTON_GAP apart, never one
// pill, and a text bar button ("Clear", "Compare", "Done") is a capsule of the same height.
// Apply with .attributeModifier(NAV_ICON_BUTTON) / .attributeModifier(NAV_TEXT_BUTTON) and
// set no size, type, background or shadow of your own on that Button.

export const NAV_BUTTON_SIZE: number = 40;
export const NAV_BUTTON_GAP: number = 8;
// Glyph size inside a nav button, the same for a SymbolGlyph and a PNG icon so the bar's
// glyphs read as one size (the profile symbol at 22 drew larger than the 20 vp images).
export const NAV_BUTTON_SYMBOL_SIZE: number = 20;
export const NAV_BUTTON_IMAGE_SIZE: number = 20;
// The row holding a root tab's bar buttons (HarmonyOS single-line title bar: 56 vp). Every
// root tab uses this height with no top/bottom padding of its own, so the buttons sit at the
// same y on Explore, Places, Saved, Activity and Search; they had drifted by up to 6 vp.
export const ROOT_BAR_HEIGHT: number = 56;

export class NavIconButtonModifier implements AttributeModifier<ButtonAttribute> {
  applyNormalAttribute(instance: ButtonAttribute): void {
    instance
      .type(ButtonType.Circle)
      .width(NAV_BUTTON_SIZE)
      .height(NAV_BUTTON_SIZE)
      .padding(0)
      .backgroundColor($r('sys.color.ohos_id_color_component_normal'))
  }
}

export class NavTextButtonModifier implements AttributeModifier<ButtonAttribute> {
  applyNormalAttribute(instance: ButtonAttribute): void {
    instance
      .type(ButtonType.Capsule)
      .height(NAV_BUTTON_SIZE)
      .padding({ left: 16, right: 16 })
      .fontSize(16)
      .backgroundColor($r('sys.color.ohos_id_color_component_normal'))
  }
}

export const NAV_ICON_BUTTON: NavIconButtonModifier = new NavIconButtonModifier();
export const NAV_TEXT_BUTTON: NavTextButtonModifier = new NavTextButtonModifier();

// Glyph colour for a raster bar icon (more.png is a solid grey template): .fillColor is
// SVG-only and does not tint a raster, so rebuild the colour from the alpha channel.
export function navIconTint(isDark: boolean): ColorFilter {
  const n: number = parseInt((isDark ? 'EAECF0' : '202122'), 16);
  const r: number = ((n >> 16) & 0xFF) / 255;
  const g: number = ((n >> 8) & 0xFF) / 255;
  const b: number = (n & 0xFF) / 255;
  return new ColorFilter([
    0, 0, 0, r, 0,
    0, 0, 0, g, 0,
    0, 0, 0, b, 0,
    0, 0, 0, 1, 0
  ]);
}
