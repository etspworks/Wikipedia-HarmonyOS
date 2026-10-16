// CollectionViewFooter with footerButtonTitle "Back to Explore feed"
// (WMFContentGroup+DetailViewControllers.swift): the last row of an Explore detail list. Its
// press pops the list (collectionViewFooterButtonWasPressed -> popViewController).
import { router } from '@kit.ArkUI';

@Component
export struct BackToExploreFeedButton {
  @StorageProp('wmfPaperBg') wmfPaperBg: string = '';

  build() {
    Column() {
      Button($r('app.string.explore_detail_back_button_title'))
        .id('back_to_explore_feed')
        .type(ButtonType.Capsule)
        .fontSize(17)
        .fontColor($r('app.color.theme_link'))
        .backgroundColor($r('app.color.theme_card_button_background'))
        .padding({ left: 20, right: 20 })
        .height(44)
        .onClick(() => {
          router.back();
        })
    }
    .width('100%')
    .padding({ top: 24, bottom: 32 })
    .alignItems(HorizontalAlign.Center)
    .backgroundColor((this.wmfPaperBg !== '' ? this.wmfPaperBg : $r('app.color.theme_paper_background')))
  }
}
