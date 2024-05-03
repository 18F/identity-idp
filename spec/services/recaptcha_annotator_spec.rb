require 'rails_helper'

RSpec.describe RecaptchaAnnotator do
  let(:recaptcha_enterprise_api_key) { 'recaptcha_enterprise_api_key' }
  let(:recaptcha_enterprise_project_id) { 'project_id' }
  let(:assessment_id) { 'assessment-id' }
  let(:analytics) { FakeAnalytics.new }
  let(:annotation_url) do
    format(
      '%{base_endpoint}/%{project_id}/assessments/%{assessment_id}:annotate?key=%{api_key}',
      base_endpoint: RecaptchaAnnotator::BASE_ENDPOINT,
      project_id: recaptcha_enterprise_project_id,
      assessment_id:,
      api_key: recaptcha_enterprise_api_key,
    )
  end
  subject(:annotator) { RecaptchaAnnotator.new(assessment_id:, analytics:) }

  describe '#annotate' do
    let(:reason) { RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR }
    let(:annotation) { RecaptchaAnnotator::Annotations::LEGITIMATE }
    subject(:annotate) { annotator.annotate(reason:, annotation:) }

    context 'without recaptcha enterprise' do
      before do
        allow(FeatureManagement).to receive(:recaptcha_enterprise?).and_return(false)
      end

      it 'does not submit annotation' do
        annotate

        expect(WebMock).not_to have_requested(:post, annotation_url)
      end

      it 'logs analytics' do
        annotate

        expect(analytics).to have_logged_event(
          :recaptcha_assessment_annotated,
          assessment_id:,
          reason:,
          annotation:,
        )
      end
    end

    context 'with recaptcha enterprise' do
      before do
        allow(FeatureManagement).to receive(:recaptcha_enterprise?).and_return(true)
        allow(IdentityConfig.store).to receive(:recaptcha_enterprise_project_id).
          and_return(recaptcha_enterprise_project_id)
        allow(IdentityConfig.store).to receive(:recaptcha_enterprise_api_key).
          and_return(recaptcha_enterprise_api_key)
        stub_request(:post, annotation_url).
          to_return(headers: { 'Content-Type': 'application/json' }, body: '')
      end

      it 'submits annotation' do
        annotate

        expect(WebMock).to have_requested(:post, annotation_url)
      end

      it 'logs analytics' do
        annotate

        expect(analytics).to have_logged_event(
          :recaptcha_assessment_annotated,
          assessment_id:,
          reason:,
          annotation:,
        )
      end

      context 'with an optional argument omitted' do
        subject(:annotate) { annotator.annotate(reason:) }

        it 'submits and logs only what is provided' do
          annotate

          expect(WebMock).to have_requested(:post, annotation_url).with(body: { reason: }.to_json)

          expect(analytics).to have_logged_event(
            :recaptcha_assessment_annotated,
            assessment_id:,
            annotation: nil,
            reason:,
          )
        end
      end
    end
  end
end
