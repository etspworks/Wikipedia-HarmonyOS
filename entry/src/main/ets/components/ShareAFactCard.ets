// ShareAFactViewController.xib: the 512x291 card rendered to an image for Share-a-fact, always
// in the standard theme. Left: the selected text (Georgia 17) from 15/17 in, a 43x1 separator,
// the article title (14, two lines), the CC BY-SA licence. Right half: the lead image filling
// 256x291 under a bottom gradient, with the licence, the Wikipedia wordmark and "Made with the
// Wikipedia app" in white. Without an image the text spans the card and the wordmark and
// "Made with the Wikipedia app" sit bottom right in the text colours.

export class ShareAFactCardModel {
  text: string = '';
  articleTitle: string = '';
  imagePath: string = '';      // a local file, so the snapshot never waits on the network
  madeWith: string = '';
}

@Builder
export function shareAFactCard(model: ShareAFactCardModel) {
  Row() {
    Column() {
      Text(model.text)
        .width('100%')
        .layoutWeight(1)
        .fontFamily('serif')
        .fontSize(17)
        .lineHeight(22)
        .fontColor('#202122')
        .align(Alignment.TopStart)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Divider()
        .width(43)
        .strokeWidth(1)
        .color('#202122')
        .margin({ top: 15 })
      Text(model.articleTitle)
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#202122')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 15 })
      Row() {
        Text('CC BY-SA')
          .fontSize(10)
          .fontColor('#72777D')
        Blank()
        if (model.imagePath === '') {
          Column({ space: 2 }) {
            Image($r('app.media.footer_wikipedia_wordmark'))
              .height(14)
              .objectFit(ImageFit.Contain)
              .fillColor('#202122')
            Text(model.madeWith)
              .fontSize(10)
              .fontColor('#72777D')
          }
          .alignItems(HorizontalAlign.End)
        }
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .layoutWeight(1)
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 15, right: 15, top: 17, bottom: 13 })

    if (model.imagePath !== '') {
      Stack({ alignContent: Alignment.Bottom }) {
        Image('file://' + model.imagePath)
          .width(256)
          .height(291)
          .objectFit(ImageFit.Cover)
        // imageGradientView: clear -> 10% -> 40% black
        Column()
          .width(256)
          .height(291)
          .linearGradient({ direction: GradientDirection.Bottom,
            colors: [['#00000000', 0], ['#1A000000', 0.5], ['#66000000', 1]] })
        Row() {
          Text('CC BY-SA')
            .fontSize(10)
            .fontColor(Color.White)
          Blank()
          Column({ space: 2 }) {
            Image($r('app.media.footer_wikipedia_wordmark'))
              .height(14)
              .objectFit(ImageFit.Contain)
              .fillColor(Color.White)
            Text(model.madeWith)
              .fontSize(10)
              .fontColor(Color.White)
          }
          .alignItems(HorizontalAlign.End)
        }
        .width(256)
        .padding({ left: 15, right: 15, bottom: 15 })
      }
      .width(256)
      .height(291)
      .clip(true)
    }
  }
  .width(512)
  .height(291)
  .backgroundColor(Color.White)
}
