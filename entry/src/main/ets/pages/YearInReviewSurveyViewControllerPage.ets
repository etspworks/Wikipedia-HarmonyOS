// YearInReviewCoordinator.presentSurveyIfNeeded / surveyViewController(): the "Satisfaction survey"
// (WMFSurveyView, single selection) shown once after Year in Review closes having seen two
// slides. Cancel closes it; Submit closes it and shows "Feedback submitted".
import { router, promptAction } from '@kit.ArkUI';
import { WMFSurveyView, SurveyOption } from '../components/WMFSurveyView';

@Entry
@Component
struct YearInReviewSurveyViewControllerPage {
  private options: SurveyOption[] = [
    new SurveyOption($r('app.string.year_in_review_survey_very_satisfied'), '1'),
    new SurveyOption($r('app.string.year_in_review_survey_satisfied'), '2'),
    new SurveyOption($r('app.string.year_in_review_survey_neutral'), '3'),
    new SurveyOption($r('app.string.year_in_review_survey_unsatisfied'), '4'),
    new SurveyOption($r('app.string.year_in_review_survey_very_unsatisfied'), '5')
  ];

  build() {
    Column() {
      WMFSurveyView({
        title: $r('app.string.year_in_review_survey_title'),
        subtitle: $r('app.string.year_in_review_survey_subtitle'),
        otherPlaceholder: $r('app.string.year_in_review_survey_additional_thoughts'),
        options: this.options,
        multiSelect: false,
        onCancel: (): void => {
          router.back();
        },
        onSubmit: (): void => {
          router.back();
          promptAction.showToast({ message: getContext(this).resourceManager.getStringSync(
            $r('app.string.alt_text_feedback_survey_toast_title').id) });
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
