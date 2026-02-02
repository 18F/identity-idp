require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::Responses::Ddp::TrueIdResponse do
  let(:success_response_body) { LexisNexisFixtures.ddp_true_id_state_id_response_success }
  let(:failure_response_body) { LexisNexisFixtures.ddp_true_id_response_fail }
  let(:unsupported_doc_type_response_body) do
    LexisNexisFixtures.ddp_true_id_response_fail_unsupported_doc_type
  end
  let(:success_response) do
    instance_double(Faraday::Response, status: 200, body: success_response_body)
  end
  let(:failure_response) do
    instance_double(Faraday::Response, status: 200, body: failure_response_body)
  end
  let(:unsupported_doc_type_response) do
    instance_double(
      Faraday::Response,
      status: 200,
      body: unsupported_doc_type_response_body,
    )
  end
  let(:config) do
    DocAuth::LexisNexis::Config.new
  end
  let(:passport_requested) { false }
  let(:true_id_response) { success_response }
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
      passport_requested:,
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

    context 'when the document type is unsupported' do
      let(:true_id_response) { unsupported_doc_type_response }

      it 'is not a successful result' do
        expect(response.successful_result?).to eq(false)
        expect(response.success?).to eq(false)
      end
    end
  end

  context 'when passport is requested' do
    let(:passport_requested) { true }

    context 'when the received document type is a supported passport type' do
      let(:success_response_body) { LexisNexisFixtures.ddp_true_id_passport_response_success }

      it 'is a successful result' do
        expect(response.success?).to eq(true)
      end
    end

    context 'when the received document type is a supported state ID type' do
      let(:success_response_body) { LexisNexisFixtures.ddp_true_id_state_id_response_success }

      it 'is not a successful result' do
        expect(response.success?).to eq(false)
      end
    end

    context 'when the received document type is an unsupported type' do
      let(:success_response_body) { LexisNexisFixtures.ddp_true_id_passport_card_response_success }

      it 'is not a successful result' do
        expect(response.success?).to eq(false)
      end
    end
  end

  context 'when passport is not requested' do
    let(:passport_requested) { false }

    context 'when the received document type is a supported passport type' do
      let(:success_response_body) { LexisNexisFixtures.ddp_true_id_passport_response_success }

      it 'is not a successful result' do
        expect(response.success?).to eq(false)
      end
    end

    context 'when the received document type is a supported state ID type' do
      let(:success_response_body) { LexisNexisFixtures.ddp_true_id_state_id_response_success }

      it 'is a successful result' do
        expect(response.success?).to eq(true)
      end
    end

    context 'when the received document type is an unsupported type' do
      let(:success_response_body) { LexisNexisFixtures.ddp_true_id_passport_card_response_success }

      it 'is not a successful result' do
        expect(response.success?).to eq(false)
      end
    end
  end
end
