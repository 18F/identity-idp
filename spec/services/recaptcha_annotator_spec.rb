require 'rails_helper'

RSpec.describe RecaptchaAnnotator do
  let(:assessment_id) { 'projects/enterprise_project_id/assessments/assessment-id' }
  let(:analytics) { FakeAnalytics.new }

  describe '#annotate' do
    let(:reason) { RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR }
    let(:annotation) { RecaptchaAnnotator::Annotations::LEGITIMATE }
    subject(:annotate) do
      RecaptchaAnnotator.annotate(assessment_id:, reason:, annotation:, analytics:)
    end
    let(:recaptcha_service) { instance_double(RecaptchaService) }

    before do
      allow(RecaptchaService).to receive(:new).and_return(recaptcha_service)
      allow(recaptcha_service).to receive(:annotate_assessment)
        .with(assessment_id:, reason:, annotation:)
    end

    context 'without recaptcha enabled' do
      before do
        allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(false)
      end

      it 'does not submit annotation' do
        annotate

        expect(recaptcha_service).not_to have_received(:annotate_assessment)
      end

      it 'returns a hash describing annotation' do
        expect(annotate).to eq(
          assessment_id:,
          reason:,
          annotation:,
        )
      end

      context 'with nil assessment id' do
        let(:assessment_id) { nil }

        it { expect(annotate).to be_nil }
      end
    end

    context 'with recaptcha enabled' do
      before do
        allow(FeatureManagement).to receive(:recaptcha_enabled?).and_return(true)
      end

      it 'submits annotation' do
        annotate

        expect(recaptcha_service).to have_received(:annotate_assessment)
      end

      it 'logs a successful annotation with its response time' do
        annotate

        expect(analytics).to have_logged_event(
          :recaptcha_annotation_result_received,
          reason:,
          annotation:,
          success: true,
          duration_ms: kind_of(Integer),
        )
      end

      context 'when annotation submission fails' do
        let(:error) { Google::Cloud::Error.new('annotation failed') }

        before do
          allow(recaptcha_service).to receive(:annotate_assessment).and_raise(error)
        end

        it 'logs the failed annotation and re-raises the error' do
          expect { annotate }.to raise_error(error)

          expect(analytics).to have_logged_event(
            :recaptcha_annotation_result_received,
            reason:,
            annotation:,
            success: false,
            exception_class: 'Google::Cloud::Error',
            duration_ms: kind_of(Integer),
          )
        end
      end

      context 'with an optional argument omitted' do
        let(:annotation) { nil }
        subject(:annotate) { RecaptchaAnnotator.annotate(assessment_id:, reason:, analytics:) }

        it 'returns a hash describing annotation with a nil value for the optional argument' do
          expect(annotate).to eq(
            assessment_id:,
            reason:,
            annotation:,
          )
        end
      end

      context 'with nil assessment id' do
        let(:assessment_id) { nil }

        it 'does not submit annotation' do
          annotate

          expect(recaptcha_service).not_to have_received(:annotate_assessment)
        end

        it { expect(annotate).to be_nil }
      end
    end
  end

  describe '#submit_assessment' do
    subject(:result) { RecaptchaAnnotator.submit_assessment(assessment) }
    let(:reason) { RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR }
    let(:annotation) { RecaptchaAnnotator::Annotations::LEGITIMATE }
    let(:assessment) do
      create(:recaptcha_assessment, id: assessment_id, annotation:, annotation_reason: reason)
    end
    let(:recaptcha_service) { instance_double(RecaptchaService) }

    before do
      allow(RecaptchaService).to receive(:new).and_return(recaptcha_service)
      allow(recaptcha_service).to receive(:annotate_assessment)
        .with(assessment_id:, reason:, annotation:)
    end

    it 'submits annotation' do
      result

      expect(recaptcha_service).to have_received(:annotate_assessment)
    end

    context 'with an optional argument omitted' do
      let(:annotation) { nil }
      let(:assessment) do
        create(:recaptcha_assessment, id: assessment_id, annotation: nil, annotation_reason: reason)
      end

      it 'submits annotation' do
        result

        expect(recaptcha_service).to have_received(:annotate_assessment)
      end
    end
  end
end
