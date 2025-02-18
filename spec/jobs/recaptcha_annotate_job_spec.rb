require 'rails_helper'

RSpec.describe RecaptchaAnnotateJob do
  include ActiveJob::TestHelper

  subject(:instance) { described_class.new(assessment_id:, reason:, annotation:) }
  let(:recaptcha_enterprise_api_key) { 'recaptcha_enterprise_api_key' }
  let(:recaptcha_enterprise_project_id) { 'project_id' }
  let(:assessment_id) { "projects/#{recaptcha_enterprise_project_id}/assessments/assessment-id" }
  let(:reason) { RecaptchaAnnotator::AnnotationReasons::PASSED_TWO_FACTOR }
  let(:annotation) { RecaptchaAnnotator::Annotations::LEGITIMATE }
  let(:annotation_url) do
    format(
      '%{base_endpoint}/%{assessment_id}:annotate?key=%{api_key}',
      base_endpoint: RecaptchaAnnotator::BASE_ENDPOINT,
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

      initiate_instance = described_class.new(
        assessment_id:,
        reason: RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR,
        annotation:,
      )
      initiate_instance.enqueue
      instance.enqueue
      GoodJob.perform_inline

      requests_enum = WebMock::RequestRegistry.instance.requested_signatures.to_enum.each
      expect(requests_enum.next).to satisfy do |request, _order|
        expected_body = {
          annotation:,
          reasons: [RecaptchaAnnotator::AnnotationReasons::INITIATED_TWO_FACTOR],
        }.to_json
        request.uri == Addressable::URI.parse(annotation_url) &&
          request.method == :post &&
          request.body == expected_body
      end
      expect(requests_enum.next).to satisfy do |request, _order|
        expected_body = { annotation:, reasons: [reason] }.to_json
        request.uri == Addressable::URI.parse(annotation_url) &&
          request.method == :post &&
          request.body == expected_body
      end
      expect { requests_enum.peek }.to raise_error(StopIteration)
    end
  end
end
