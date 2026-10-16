// Inline colour swatches (Template:Legend, Template:Color box: an empty <span> with a background
// colour and often a thin border). Text spans cannot draw a bordered square, so the swatch is
// an ImageSpan over a small generated pixel map, one per fill/border pair.
import { image } from '@kit.ImageKit';

const SIZE: number = 16;
const cache: Map<string, image.PixelMap> = new Map<string, image.PixelMap>();

function rgb(hex: string): number[] {
  const h: string = hex.replace('#', '');
  const full: string = h.length === 3 ? h.split('').map((c: string) => c + c).join('') : h;
  const n: number = Number.parseInt(full, 16);
  return Number.isNaN(n) ? [0, 0, 0] : [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

// `fill` and `border` are hex colours; an empty `border` draws none.
export function swatchPixelMap(fill: string, border: string): image.PixelMap {
  const key: string = fill + '|' + border;
  const hit: image.PixelMap | undefined = cache.get(key);
  if (hit !== undefined) {
    return hit;
  }
  const inner: number[] = rgb(fill);
  const edge: number[] = border !== '' ? rgb(border) : inner;
  const buffer: ArrayBuffer = new ArrayBuffer(SIZE * SIZE * 4);
  const px: Uint8Array = new Uint8Array(buffer);
  for (let y: number = 0; y < SIZE; y++) {
    for (let x: number = 0; x < SIZE; x++) {
      const onEdge: boolean = x === 0 || y === 0 || x === SIZE - 1 || y === SIZE - 1;
      const c: number[] = onEdge ? edge : inner;
      const i: number = (y * SIZE + x) * 4;
      px[i] = c[0];
      px[i + 1] = c[1];
      px[i + 2] = c[2];
      px[i + 3] = 255;
    }
  }
  const options: image.InitializationOptions = {
    size: { height: SIZE, width: SIZE },
    srcPixelFormat: image.PixelMapFormat.RGBA_8888,
    pixelFormat: image.PixelMapFormat.RGBA_8888,
    editable: false
  };
  const map: image.PixelMap = image.createPixelMapSync(buffer, options);
  cache.set(key, map);
  return map;
}

// An inline text colour that stays readable on the theme: on a dark theme a near-black colour
// (style="color:black") is dropped for the theme's own text colour.
export function readableInlineColor(hex: string, dark: boolean): string {
  if (hex === '' || !dark) {
    return hex;
  }
  const c: number[] = rgb(hex);
  const luminance: number = (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255;
  return luminance < 0.35 ? '' : hex;
}
