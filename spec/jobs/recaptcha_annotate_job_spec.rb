require 'rails_helper'

RSpec.describe RecaptchaAnnotateJob do
  include ActiveJob::TestHelper

  subject(:instance) { described_class.new }
  let(:recaptcha_enterprise_api_key) { 'recaptcha_enterprise_api_key' }
  let(:recaptcha_enterprise_project_id) { 'project_id' }
  let(:assessment_id) { "projects/#{recaptcha_enterprise_project_id}/assessments/assessment-id" }
  let(:reason) { RecaptchaAnnotator::AnnotationReasons::PASSED_TWO_FACTOR }
  let(:annotation) { RecaptchaAnnotator::Annotations::LEGITIMATE }
  let(:annotation_url) do
    format(
      '%{base_endpoint}/%{assessment_id}:annotate?key=%{api_key}',
      base_endpoint: RecaptchaAnnotateJob::BASE_ENDPOINT,
      assessment_id:,
      api_key: recaptcha_enterprise_api_key,
    )
  end

  before do
    allow(FeatureManagement).to receive(:recaptcha_enterprise?).and_return(true)
    allow(IdentityConfig.store).to receive(:recaptcha_enterprise_project_id)
      .and_return(recaptcha_enterprise_project_id)
    allow(IdentityConfig.store).to receive(:recaptcha_enterprise_api_key)
      .and_return(recaptcha_enterprise_api_key)
    stub_request(:post, annotation_url)
      .to_return(headers: { 'Content-Type': 'application/json' }, body: '{}')
  end

  describe '#perform' do
    subject(:result) { instance.perform(assessment_id:, reason:, annotation:) }

    it 'processes in order' do
      ActiveJob::Base.queue_adapter = :good_job

      RecaptchaAnnotateJob.set(wait: 10.minutes).perform_later(assessment_id:, reason:, annotation:)
      RecaptchaAnnotateJob.set(wait: 5.minutes).perform_later(
        assessment_id:,
        reason: RecaptchaAnnotator::AnnotationReasons::FAILED_TWO_FACTOR,
        annotation:,
      )
      RecaptchaAnnotateJob.perform_later(
        assessment_id:,
        reason: RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR,
        annotation:,
      )

      expect(WebMock).not_to have_requested(:post, annotation_url)

      travel_to 11.minutes.from_now do
        GoodJob.perform_inline
        expect(WebMock).to have_requested(:post, annotation_url).once
        expect(WebMock).to have_requested(:post, annotation_url)
          .with(body: { annotation:, reasons: [reason] }.to_json)
      end
    end

    context 'with an optional argument omitted' do
      let(:annotation) { nil }

      it 'submits only what is provided' do
        result

        expect(WebMock).to have_requested(:post, annotation_url)
          .with(body: { reasons: [reason] }.to_json)
      end
    end

    context 'with connection error' do
      before do
        stub_request(:post, annotation_url).to_timeout
      end

      it 'fails gracefully' do
        result
      end

      it 'notices the error to NewRelic' do
        expect(NewRelic::Agent).to receive(:notice_error).with(Faraday::Error)

        result
      end
    end
  end
end
