require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::Responses::Ddp::TrueIdResponse do
  let(:success_response_body) { LexisNexisFixtures.ddp_true_id_response_success }
  let(:failure_response_body) { LexisNexisFixtures.ddp_true_id_response_fail }
  let(:success_response) do
    instance_double(Faraday::Response, status: 200, body: success_response_body)
  end
  let(:failure_response) do
    instance_double(Faraday::Response, status: 200, body: failure_response_body)
  end
  let(:config) do
    DocAuth::LexisNexis::Config.new
  end
  let(:true_id_response) { nil }
  let(:front_image) { 'front_image_data' }
  let(:back_image) { 'back_image_data' }
  let(:selfie_image) { 'selfie_image_data' }
  let(:passport_image) { 'passport_image_data' }
  let(:liveness_checking_required) { false }
  let(:document_type_requested) { DocAuth::LexisNexis::DocumentTypes::DRIVERS_LICENSE }
  let(:applicant) do
    {
      email: 'person.name@email.test',
      uuid_prefix: 'test_prefix',
      uuid: 'test_uuid_12345',
      front_image:,
      back_image:,
      selfie_image:,
      passport_image:,
      document_type_requested:,
      liveness_checking_required:,
    }
  end

  let(:config) do
    Proofing::LexisNexis::Config.new(
      api_key: 'test_api_key',
      base_url: 'https://example.com',
      org_id: 'test_org_id',
    )
  end
  let(:request) do
    DocAuth::LexisNexis::Requests::Ddp::TrueIdRequest.new(
      config:,
      applicant:,
    )
  end
  let(:response) do
    described_class.new(
      http_response: true_id_response,
      config:,
      request:,
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return('org_id_str')
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_ddp_noliveness_policy)
      .and_return('default_auth_policy_pm')
  end

  context 'when the response is a success' do
    let(:true_id_response) { success_response }

    it 'is a successful result' do
      expect(response.successful_result?).to eq(true)
      expect(response.success?).to eq(true)
    end
  end

  context 'when the response is a failure' do
    let(:true_id_response) { failure_response }

    it 'is not a successful result' do
      expect(response.successful_result?).to eq(false)
      expect(response.success?).to eq(false)
    end
  end
end
