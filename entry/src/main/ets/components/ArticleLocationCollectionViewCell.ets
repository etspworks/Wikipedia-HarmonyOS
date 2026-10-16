// comp_article_location_cell — ported from
// Wikipedia/Code/ArticleLocationCollectionViewCell.swift (+ ArticleLocationCellUpdating.swift):
// a compassView (104pt, needle rotated to the bearing from the user's location/heading to the
// article) with the circular 72pt imageView drawn inside it, and beside it the title, a 2-line
// description and the distance label on its bordered background. When the user location is
// unknown the label reads "unknown distance" (configureForUnknownDistance).
// Users: screen_places, screen_article_location_collection.
// S5: styled on the app baseline tokens (no capture for this screen) — row title 18
// Medium on textPrimary, 15 secondary description, distance chip on the theme border.

const COMPASS: number = 104;
const COMPASS_PADDING: number = 18;

@Component
export struct ArticleLocationCollectionViewCell {
  @Prop title: string = '';
  @Prop articleDescription: string = '';
  @Prop imageURL: string = '';
  // NSString.wmf_localizedString(forDistance:), or "unknown distance"
  @Prop distanceText: string = '';
  // degrees, clockwise from north to the article
  @Prop bearing: number = 0;
  // degrees, clockwise from north to where the phone points (ArticleLocationCollectionViewCell
  // .update(userLocation:heading:)): the needle shows the article relative to the reader
  // Published by PlacesViewControllerPage, read here so a turn redraws only the needle.
  @StorageProp('wmfPlacesHeading') heading: number = 0;
  private compass: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));

  // WMFCompassView.drawRect: 40 ticks on a ring, the arrow at the top (the bearing) and a
  // longer line opposite it, all in the accent colour. Sizes follow the source's ratios.
  private drawCompass(): void {
    const c: CanvasRenderingContext2D = this.compass;
    let color: number = 0xFF14866D;
    try {
      color = getContext(this).resourceManager.getColorSync($r('app.color.theme_accent').id);
    } catch (e) {
      // keep the default green
    }
    const r: number = COMPASS / 2;
    const base: number = r - COMPASS_PADDING;
    const ring: number = base * 1.15;
    const tickLen: number = base * 0.06;
    c.clearRect(0, 0, COMPASS, COMPASS);
    c.strokeStyle = color;
    c.fillStyle = color;
    c.lineWidth = 0.5;
    for (let i: number = 0; i < 40; i++) {
      const a: number = i * Math.PI * 2 / 40;
      c.beginPath();
      c.moveTo(r + Math.sin(a) * ring, r - Math.cos(a) * ring);
      c.lineTo(r + Math.sin(a) * (ring + tickLen), r - Math.cos(a) * (ring + tickLen));
      c.stroke();
    }
    // opposite line, three ticks long, below the ring
    c.lineWidth = 1;
    c.beginPath();
    c.moveTo(r, r + ring);
    c.lineTo(r, r + ring + tickLen * 3);
    c.stroke();
    // the arrow: a house-shaped tick standing on the ring at the top
    const w: number = (COMPASS - COMPASS_PADDING * 2) * 0.115;
    const h: number = (COMPASS - COMPASS_PADDING * 2) * 0.135;
    const bottom: number = r - ring;
    const mid: number = bottom - h / 2 + h * 0.1666;
    c.beginPath();
    c.moveTo(r - w / 2, bottom);
    c.lineTo(r - w / 2, mid);
    c.lineTo(r, bottom - h);
    c.lineTo(r + w / 2, mid);
    c.lineTo(r + w / 2, bottom);
    c.closePath();
    c.fill();
  }

  build() {
    Row() {
      Stack() {
        // WMFCompassView: drawn once pointing up, then rotated to the bearing. (compass_w is
        // the white W placeholder, not a compass, so the rows had no direction at all.)
        Canvas(this.compass)
          .width(COMPASS)
          .height(COMPASS)
          .rotate({ angle: this.bearing - this.heading })
          // the sensor reports about every 60 ms; glide between samples instead of jumping
          .animation({ duration: 100, curve: Curve.Linear })
          .onReady(() => {
            this.drawCompass();
          })
        // A row whose article has no thumbnail still gets the circle: without it the row read
        // as a layout hole, with the title indented past nothing.
        if (this.imageURL !== '') {
          Image(this.imageURL)
            .width(72)
            .height(72)
            .borderRadius(36)
            .objectFit(ImageFit.Cover)
            .backgroundColor($r('app.color.gray200'))
        } else {
          // the source's placeholder: the white Wikipedia W on the green places colour
          Stack() {
            Image($r('app.media.places_w_medium'))
              .width(36)
              .height(36)
              .objectFit(ImageFit.Contain)
              .colorFilter(new ColorFilter([0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0]))
          }
          .id('places_thumbnail_placeholder')
          .width(72)
          .height(72)
          .borderRadius(36)
          .backgroundColor($r('app.color.theme_accent'))
        }
      }
      .width(104)
      .height(104)

      Column() {
        Text(this.title)
          .width('100%')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_text'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.articleDescription !== '') {
          Text(this.articleDescription)
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .fontSize(15)
            .fontColor($r('app.color.theme_secondary_text'))
            .margin({ top: 3 })
        }
        // distanceLabel on distanceLabelBackground
        Text(this.distanceText)
          .borderWidth(1)
          .borderRadius(2)
          .borderColor($r('app.color.theme_border'))
          .fontSize(13)
          .fontColor($r('app.color.theme_secondary_text'))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .margin({ top: 8 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 10 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }
}
