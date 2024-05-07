require 'rails_helper'

RSpec.describe RecaptchaAnnotator do
  let(:recaptcha_enterprise_api_key) { 'recaptcha_enterprise_api_key' }
  let(:recaptcha_enterprise_project_id) { 'project_id' }
  let(:assessment_id) { "projects/#{recaptcha_enterprise_project_id}/assessments/assessment-id" }
  let(:analytics) { FakeAnalytics.new }
  let(:annotation_url) do
    format(
      '%{base_endpoint}/%{assessment_id}:annotate?key=%{api_key}',
      base_endpoint: RecaptchaAnnotator::BASE_ENDPOINT,
      assessment_id:,
      api_key: recaptcha_enterprise_api_key,
    )
  end

  describe '#annotate' do
    let(:reason) { RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR }
    let(:annotation) { RecaptchaAnnotator::Annotations::LEGITIMATE }
    subject(:annotate) { RecaptchaAnnotator.annotate(assessment_id:, reason:, annotation:) }

    context 'without recaptcha enterprise' do
      before do
        allow(FeatureManagement).to receive(:recaptcha_enterprise?).and_return(false)
      end

      it 'does not submit annotation' do
        annotate

        expect(WebMock).not_to have_requested(:post, annotation_url)
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

    context 'with recaptcha enterprise' do
      before do
        allow(FeatureManagement).to receive(:recaptcha_enterprise?).and_return(true)
        allow(IdentityConfig.store).to receive(:recaptcha_enterprise_project_id).
          and_return(recaptcha_enterprise_project_id)
        allow(IdentityConfig.store).to receive(:recaptcha_enterprise_api_key).
          and_return(recaptcha_enterprise_api_key)
        stub_request(:post, annotation_url).
          with do |req|
            parsed_body = JSON.parse(req.body)
            next if reason && parsed_body['reasons'] != [reason.to_s]
            next if !reason && parsed_body.key?('reasons')
            next if annotation && parsed_body['annotation'] != annotation.to_s
            true
          end.
          to_return(headers: { 'Content-Type': 'application/json' }, body: '{}')
      end

      it 'submits annotation' do
        annotate

        expect(WebMock).to have_requested(:post, annotation_url)
      end

      it 'logs analytics' do
        annotate

        expect(annotate).to eq(
          assessment_id:,
          reason:,
          annotation:,
        )
      end

      context 'with an optional argument omitted' do
        let(:annotation) { nil }
        subject(:annotate) { RecaptchaAnnotator.annotate(assessment_id:, reason:) }

        it 'submits only what is provided' do
          annotate

          expect(WebMock).to have_requested(:post, annotation_url).
            with(body: { reasons: [reason] }.to_json)
        end

        it 'returns a hash describing annotation' do
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

          expect(WebMock).not_to have_requested(:post, annotation_url)
        end

        it { expect(annotate).to be_nil }
      end

      context 'with connection error' do
        before do
          stub_request(:post, annotation_url).to_timeout
        end

        it 'fails gracefully' do
          annotate
        end

        it 'notices the error to NewRelic' do
          expect(NewRelic::Agent).to receive(:notice_error).with(Faraday::Error)

          annotate
        end
      end
    end
  end
end
