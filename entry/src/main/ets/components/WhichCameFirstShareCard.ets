// WMFWhichCameFirstShareView: the 393x627 card rendered to an image for "Share score". The
// Wikipedia wordmark, a yellow-bordered score card ("I scored N/5 on "Which came first?"
// today." over one green check / red x per question), "Topics included:" and one row per
// question's article (title, description, 40x40 thumbnail). Thumbnails are local files, so
// the snapshot never waits on the network (the source pre-fetches for the same reason).

export class ShareCardArticle {
  title: string = '';
  description: string = '';
  imagePath: string = '';   // file path in the cache dir, '' when there is no image
}

export class ShareCardModel {
  scoreSummary: string = '';
  topicsTitle: string = '';
  results: boolean[] = [];
  articles: ShareCardArticle[] = [];
}

@Builder
export function whichCameFirstShareCard(model: ShareCardModel) {
  Column() {
    Image($r('app.media.footer_wikipedia_wordmark'))
      .height(28)
      .objectFit(ImageFit.Contain)
      .fillColor(Color.Black)
      .margin({ top: 28, bottom: 32 })
    Column({ space: 22 }) {
      Text(model.scoreSummary)
        .fontSize(28)
        .fontFamily('serif')
        .fontColor(Color.Black)
        .textAlign(TextAlign.Center)
        .padding({ left: 8, right: 8 })
      Row({ space: 8 }) {
        ForEach(model.results, (correct: boolean) => {
          Stack() {
            Circle()
              .width(22)
              .height(22)
              .fill(correct ? $r('app.color.green700') : $r('app.color.red700'))
            SymbolGlyph(correct ? $r('sys.symbol.checkmark') : $r('sys.symbol.xmark'))
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor([Color.White])
          }
        })
      }
    }
    .width(353)
    .padding({ top: 22, bottom: 22, left: 16, right: 16 })
    .border({ width: 2, color: $r('app.color.yellow600'), radius: 12 })
    Text(model.topicsTitle)
      .width('100%')
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(Color.Black)
      .padding({ left: 20, right: 20, top: 32, bottom: 16 })
    ForEach(model.articles, (article: ShareCardArticle) => {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(article.title)
            .fontSize(16)
            .fontColor(Color.Black)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (article.description !== '') {
            Text(article.description)
              .fontSize(15)
              .fontColor('#54595D')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        if (article.imagePath !== '') {
          Image('file://' + article.imagePath)
            .width(40)
            .height(40)
            .objectFit(ImageFit.Cover)
            .borderRadius(4)
        } else {
          Blank()
            .width(40)
            .height(40)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 8 })
    })
  }
  .width(393)
  .height(627)
  .backgroundColor(Color.White)
  .clip(true)
}
