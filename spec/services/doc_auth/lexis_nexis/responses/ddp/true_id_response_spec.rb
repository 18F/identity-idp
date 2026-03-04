require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::Responses::Ddp::TrueIdResponse do
  let(:success_response_body) { LexisNexisFixtures.ddp_true_id_state_id_response_success }
  let(:failure_response_body) { LexisNexisFixtures.ddp_true_id_response_fail }
  let(:passport_failure_response_body) do
    LexisNexisFixtures.ddp_true_id_response_fail_passport
  end
  let(:unsupported_doc_type_response_body) do
    LexisNexisFixtures.ddp_true_id_response_fail_unsupported_doc_type
  end
  let(:liveness_success_response_body) do
    LexisNexisFixtures.ddp_true_id_liveness_response_success_state_id_card
  end
  let(:liveness_fail_response_body) do
    LexisNexisFixtures.ddp_true_id_liveness_response_fail_state_id_card
  end
  let(:liveness_fail_passport_response_body) do
    LexisNexisFixtures.ddp_true_id_liveness_response_fail_passport
  end
  let(:attention_with_barcode_response_body) do
    LexisNexisFixtures.ddp_true_id_attention_with_barcode_response_state_id_card
  end

  let(:ddp_response_body) { nil }
  let(:ddp_http_response) do
    instance_double(Faraday::Response, status: 200, body: ddp_response_body)
  end

  let(:config) do
    DocAuth::LexisNexis::Config.new
  end
  let(:passport_requested) { false }
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
      user_uuid: 'test_user_uuid',
      uuid_prefix: 'test_uuid_prefix',
    )
  end
  let(:response) do
    described_class.new(
      http_response: ddp_http_response,
      config:,
      request:,
      passport_requested:,
      liveness_checking_enabled: liveness_checking_required,
    )
  end

  let(:expected_pii) do
    Pii::StateId.new(
      first_name: 'FIRST',
      last_name: 'LAST',
      middle_name: 'MIDDLE',
      name_suffix: nil,
      address1: '123 MAIN ST',
      address2: nil,
      city: 'SEATTLE',
      zipcode: '12345',
      dob: '1999-01-01',
      sex: 'male',
      height: 105,
      weight: nil,
      eye_color: nil,
      state: 'WA',
      state_id_expiration: '2030-01-01',
      state_id_issued: '2022-01-01',
      state_id_jurisdiction: 'WA',
      state_id_number: 'WA0123456789',
      document_type_received: 'drivers_license',
      issuing_country_code: 'USA',
    )
  end

  let(:expected_pii_for_fail) do
    Pii::StateId.new(
      first_name: 'HAPPY',
      last_name: 'TRAVELER',
      middle_name: nil,
      name_suffix: nil,
      address1: '1300 W BENSON BLVD STE 900',
      address2: nil,
      city: 'ANCHORAGE',
      state: 'AK',
      zipcode: '99503',
      dob: '1978-12-13',
      sex: 'male',
      height: nil,
      weight: nil,
      eye_color: nil,
      state_id_expiration: '2021-04-28',
      state_id_issued: nil,
      state_id_jurisdiction: 'USA',
      state_id_number: nil,
      document_type_received: 'identification_card',
      issuing_country_code: 'USA',
    )
  end

  before do
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return('org_id_str')
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_ddp_noliveness_policy)
      .and_return('default_auth_policy_pm')
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_ddp_liveness_policy)
      .and_return('default_auth_policy_pm')
  end

  context 'when the response is a success' do
    let(:ddp_response_body) { success_response_body }

    it 'is a successful result' do
      expect(response.successful_result?).to eq(true)
      expect(response.success?).to eq(true)
      expect(response.pii_from_doc).to be_a(Pii::StateId)
      expect(response.pii_from_doc.to_h).to eq(expected_pii.to_h)
    end

    it 'has extra attributes' do
      extra_attributes = response.extra_attributes
      expect(extra_attributes).not_to be_empty
      expect(extra_attributes).to have_key(:reference)
    end

    it 'excludes pii fields from logging' do
      expect(response.extra_attributes.keys).to_not include(*described_class::PII_EXCLUDES)
    end

    it 'excludes unnecessary raw Alert data from logging' do
      expect(response.extra_attributes.keys.any? { |key| key.start_with?('Alert_') }).to eq(false)
    end
    context 'when liveness checking is enabled' do
      let(:liveness_checking_required) { true }
      let(:ddp_response_body) { liveness_success_response_body }

      it 'is a successful result' do
        expect(response.successful_result?).to eq(true)
        expect(response.success?).to eq(true)
        expect(response.pii_from_doc).to be_a(Pii::StateId)
        expect(response.pii_from_doc.to_h).to eq(expected_pii.to_h)
      end
    end

    context 'when the response has doc auth result of Attention with barcode' do
      let(:ddp_response_body) { attention_with_barcode_response_body }

      it 'is a successful result with attention and barcode set to true' do
        expect(response.successful_result?).to eq(true)
        expect(response.success?).to eq(true)
        expect(response.attention_with_barcode?).to eq(true)
        expect(response.pii_from_doc).to be_a(Pii::StateId)
      end
    end
  end

  context 'when the response is a failure' do
    let(:ddp_response_body) { failure_response_body }

    # There seems to be an issue with the fixture for a failing state id
    xit 'is not a successful result' do
      expect(response.successful_result?).to eq(false)
      expect(response.success?).to eq(false)
      expect(response.pii_from_doc).to be_a(Pii::StateId)
      expect(response.pii_from_doc.to_h).to eq(expected_pii_for_fail.to_h)
    end

    context 'passport failure is not a successful result' do
      let(:ddp_response_body) { passport_failure_response_body }
      let(:expected_passport_pii) do
        Pii::Passport.new(
          first_name: 'HAPPY',
          last_name: 'TRAVELER',
          middle_name: nil,
          dob: '1967-07-04',
          sex: 'female',
          passport_expiration: '2026-03-27',
          passport_issued: nil,
          document_type_received: 'passport',
          issuing_country_code: 'USA',
          document_number: '340400859',
          birth_place: nil,
          nationality_code: 'USA',
          mrz: 'FAKEMRZDATA1234567890',
        )
      end

      it 'is not a successful result' do
        expect(response.successful_result?).to eq(false)
        expect(response.success?).to eq(false)
        expect(response.pii_from_doc).to be_a(Pii::Passport)
        expect(response.pii_from_doc.to_h).to eq(expected_passport_pii.to_h)
      end
    end

    context 'when the document type is unsupported' do
      let(:ddp_response_body) { unsupported_doc_type_response_body }

      it 'is not a successful result' do
        expect(response.successful_result?).to eq(false)
        expect(response.success?).to eq(false)
      end
    end

    context 'when liveness checking is enabled' do
      let(:liveness_checking_required) { true }
      context 'when success response w no selfie status is returned' do
        let(:ddp_response_body) { success_response_body }

        it 'is not a successful result' do
          expect(response.successful_result?).to eq(false)
          expect(response.success?).to eq(false)
        end
      end
      context 'when liveness fail response is returned' do
        let(:ddp_response_body) { liveness_fail_response_body }

        it 'is not a successful result' do
          expect(response.successful_result?).to eq(false)
          expect(response.success?).to eq(false)
        end
      end
      context 'when liveness fail response is returned for passport' do
        let(:ddp_response_body) { liveness_fail_passport_response_body }

        it 'is not a successful result' do
          expect(response.successful_result?).to eq(false)
          expect(response.success?).to eq(false)
        end
      end
    end
  end

  context 'when passport is requested' do
    let(:passport_requested) { true }

    context 'when the received document type is a supported passport type' do
      let(:ddp_response_body) { LexisNexisFixtures.ddp_true_id_passport_response_success }

      it 'is a successful result' do
        expect(response.success?).to eq(true)
      end

      it 'has extra attributes' do
        extra_attributes = response.extra_attributes
        expect(extra_attributes).not_to be_empty
        expect(extra_attributes).to have_key(:reference)
      end

      it 'excludes pii fields from logging' do
        expect(response.extra_attributes.keys).to_not include(*described_class::PII_EXCLUDES)
      end

      it 'excludes unnecessary raw Alert data from logging' do
        expect(response.extra_attributes.keys.any? { |key| key.start_with?('Alert_') }).to eq(false)
      end
    end

    context 'when the received document type is a supported state ID type' do
      let(:ddp_response_body) { LexisNexisFixtures.ddp_true_id_state_id_response_success }

      it 'is not a successful result' do
        expect(response.success?).to eq(false)
      end
    end

    context 'when the received document type is an unsupported type' do
      let(:ddp_response_body) { LexisNexisFixtures.ddp_true_id_passport_card_response_success }

      it 'is not a successful result' do
        expect(response.success?).to eq(false)
      end
    end
  end

  context 'when passport is not requested' do
    let(:passport_requested) { false }

    context 'when the received document type is a supported passport type' do
      let(:ddp_response_body) { LexisNexisFixtures.ddp_true_id_passport_response_success }

      it 'is not a successful result' do
        expect(response.success?).to eq(false)
      end
    end

    context 'when the received document type is a supported state ID type' do
      let(:ddp_response_body) { LexisNexisFixtures.ddp_true_id_state_id_response_success }

      it 'is a successful result' do
        expect(response.success?).to eq(true)
      end
    end

    context 'when the received document type is an unsupported type' do
      let(:ddp_response_body) { LexisNexisFixtures.ddp_true_id_passport_card_response_success }

      it 'is not a successful result' do
        expect(response.success?).to eq(false)
      end
    end
  end
end
