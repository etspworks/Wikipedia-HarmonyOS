// comp_ranked_article_cell — ported from Wikipedia/Code/RankedArticleCollectionViewCell.swift
// (CircledRankView + inherited right-aligned article row). S5: styled per capture — outlined
// colored rank circle, gradient blue -> green down the ranks (Theme rankGradient).
import { ArticleRightAlignedImageCollectionViewCell } from './ArticleRightAlignedImageCollectionViewCell';

@Component
export struct RankedArticleCollectionViewCell {
  @Prop rank: number = 0;
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop imageURL: string = '';
  onTap?: () => void;

  // ponytail: 5-stop approximation of iOS Theme.rankGradient (blue600 -> green600);
  // sample real gradient math if fidelity diff flags the mid ranks.
  private rankColor(): string {
    const stops: string[] = ['#3366CC', '#2C7DBB', '#2492AA', '#12A19A', '#00AF89'];
    let i: number = this.rank - 1;
    if (i < 0) { i = 0; }
    if (i > 4) { i = 4; }
    return stops[i];
  }

  build() {
    Row() {
      // CircledRankView — outlined circle, rank-colored number. The number used to sit low
      // in the circle: a 26vp lineHeight inside a 28vp box with a 1.5vp border leaves the
      // glyph below centre. A Stack centres it on both axes instead.
      Stack() {
        Text(String(this.rank))
          .fontSize(15)
          .fontColor(this.rankColor())
          .textAlign(TextAlign.Center)
      }
        .width(28)
        .height(28)
        .border({ width: 1.5, color: this.rankColor() })
        .borderRadius(14)
        .margin({ left: 16 })
      ArticleRightAlignedImageCollectionViewCell({
        title: this.title,
        description: this.description,
        imageURL: this.imageURL,
        onTap: (): void => {
          if (this.onTap !== undefined) {
            this.onTap();
          }
        }
      })
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
