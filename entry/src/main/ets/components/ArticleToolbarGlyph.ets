// One glyph of the article toolbar (ArticleToolbarController), shared by the Article and Random
// article screens. The source draws each item at its asset's own point size (Images.xcassets
// PDFs: toc 33x33, language 28x24, save 16x23, find-in-page 19x25, font-size 24x20) with
// template tinting, and the overflow as the light SF "ellipsis". Here every glyph keeps those
// proportions on one scale, which follows the phone width like the tab bar's icons, and takes the
// theme's text colour. The overflow is drawn as the same three dots.
import { widthScale } from '../common/SafeArea';

// 0.88 vp per source pt on a 360 vp phone: the same ratio as the tab bar (21 vp for the
// source's 23.8 pt), clamped the same way
const SCALE: number = 0.88 * widthScale();

// alpha kept, RGB replaced: gray700 #202122 / gray100 #F8F9FA (primaryText)
const LIGHT_FILTER: number[] = [0, 0, 0, 0, 0.125, 0, 0, 0, 0, 0.129, 0, 0, 0, 0, 0.133, 0, 0, 0, 1, 0];
const DARK_FILTER: number[] = [0, 0, 0, 0, 0.973, 0, 0, 0, 0, 0.976, 0, 0, 0, 0, 0.98, 0, 0, 0, 1, 0];

@Component
export struct ArticleToolbarGlyph {
  // null: the overflow dots
  @Prop icon: Resource | null = null;
  // the source asset's size in pt (unused by the dots)
  @Prop w: number = 24;
  @Prop h: number = 24;
  // test hook carried by the glyph itself (the save state)
  @Prop glyphId: string = '';
  @StorageProp('wmfIsDark') isDark: boolean = false;

  build() {
    if (this.icon === null) {
      // the source's light ellipsis: three 3.5 pt dots, 3.9 pt apart (measured on the capture).
      // The system "more" icon is a 2x2 dot grid, which reads as a different control.
      Row({ space: 3.9 * SCALE }) {
        ForEach([0, 1, 2], (i: number) => {
          Circle({ width: 3.5 * SCALE, height: 3.5 * SCALE })
            .fill(this.isDark ? '#F8F9FA' : '#202122')
        }, (i: number) => i.toString())
      }
    } else {
      Image(this.icon)
        .id(this.glyphId)
        .width(this.w * SCALE)
        .height(this.h * SCALE)
        .objectFit(ImageFit.Contain)
        .interpolation(ImageInterpolation.High)
        .colorFilter(new ColorFilter(this.isDark ? DARK_FILTER : LIGHT_FILTER))
    }
  }
}
