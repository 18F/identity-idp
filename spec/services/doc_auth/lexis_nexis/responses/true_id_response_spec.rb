require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::Responses::TrueIdResponse do
  let(:success_response_body) { LexisNexisFixtures.true_id_response_success_2 }
  let(:success_response) do
    instance_double(Faraday::Response, status: 200, body: success_response_body)
  end
  let(:failure_body_no_liveness) { LexisNexisFixtures.true_id_response_failure_no_liveness }
  let(:failure_body_with_liveness) { LexisNexisFixtures.true_id_response_failure_with_liveness }
  let(:failure_body_with_all_failures) do
    LexisNexisFixtures.true_id_response_failure_with_all_failures
  end
  let(:failure_body_no_liveness_low_dpi) do
    LexisNexisFixtures.true_id_response_failure_no_liveness_low_dpi
  end

  # rubocop:disable Layout/LineLength
  let(:failure_response_no_liveness) do
    instance_double(Faraday::Response, status: 200, body: failure_body_no_liveness)
  end
  let(:failure_response_with_liveness) do
    instance_double(Faraday::Response, status: 200, body: failure_body_with_liveness)
  end
  let(:failure_response_with_all_failures) do
    instance_double(Faraday::Response, status: 200, body: failure_body_with_all_failures)
  end
  let(:communications_error_response) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.communications_error)
  end
  let(:internal_application_error_response) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.internal_application_error)
  end
  let(:failure_response_empty) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_failure_empty)
  end
  let(:failure_response_malformed) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_response_malformed)
  end
  let(:attention_barcode_read) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_barcode_read_attention)
  end
  let(:failure_response_no_liveness_low_dpi) do
    instance_double(Faraday::Response, status: 200, body: failure_body_no_liveness_low_dpi)
  end
  # rubocop:enable Layout/LineLength

  let(:config) do
    DocAuth::LexisNexis::Config.new
  end

  context 'when the response is a success' do
    let(:response) { described_class.new(success_response, false, config) }

    it 'is a successful result' do
      expect(response.successful_result?).to eq(true)
    end
    it 'has no error messages' do
      expect(response.error_messages).to be_empty
    end
    it 'has extra attributes' do
      extra_attributes = response.extra_attributes
      expect(extra_attributes).not_to be_empty
    end
    it 'has PII data' do
      # This is the minimum expected by doc_pii_form in the core IDP
      minimum_expected_hash = {
        first_name: 'DAVID',
        last_name: 'SAMPLE',
        dob: '1986-10-13',
        state: 'MD',
      }

      expect(response.pii_from_doc).to include(minimum_expected_hash)
    end
    it 'includes expiration' do
      expect(response.pii_from_doc).to include(state_id_expiration: '2099-10-15')
    end
  end

  context 'when the barcode can not be read' do
    let(:response) do
      described_class.new(attention_barcode_read, false, config)
    end

    it 'is a successful result' do
      expect(response.successful_result?).to eq(true)
    end
    it 'has no error messages' do
      expect(response.error_messages).to be_empty
    end
    it 'has extra attributes' do
      extra_attributes = response.extra_attributes
      expect(extra_attributes).not_to be_empty
    end
    it 'has PII data' do
      # This is the minimum expected by doc_pii_form in the core IDP
      minimum_expected_hash = {
        first_name: 'DAVID',
        last_name: 'SAMPLE',
        dob: '1986-10-13',
        state: 'MD',
      }

      expect(response.pii_from_doc).to include(minimum_expected_hash)
    end
    it 'includes expiration' do
      expect(response.pii_from_doc).to include(state_id_expiration: '2099-10-15')
    end
  end

  context 'when response is not a success' do
    it 'it produces appropriate errors without liveness' do
      output = described_class.new(failure_response_no_liveness, false, config).to_h
      errors = output[:errors]

      expect(output[:success]).to eq(false)
      expect(errors.keys).to contain_exactly(:general)
      expect(errors[:general]).to contain_exactly(
        DocAuth::Errors::GENERAL_ERROR_NO_LIVENESS,
      )
    end

    it 'it produces appropriate errors with liveness' do
      output = described_class.new(failure_response_with_liveness, true, config).to_h
      errors = output[:errors]

      expect(output[:success]).to eq(false)
      expect(errors.keys).to contain_exactly(:general)
      expect(errors[:general]).to contain_exactly(
        DocAuth::Errors::GENERAL_ERROR_LIVENESS,
      )
    end

    it 'it produces appropriate errors with liveness and everything failing' do
      output = described_class.new(failure_response_with_all_failures, true, config).to_h
      errors = output[:errors]

      expect(output[:success]).to eq(false)
      expect(errors.keys).to contain_exactly(:general)
      expect(errors[:general]).to contain_exactly(
        DocAuth::Errors::GENERAL_ERROR_LIVENESS,
      )
    end
  end

  context 'when response is unexpected' do
    it 'it produces reasonable output for communications error' do
      output = described_class.new(communications_error_response, false, config).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(network: true)
      expect(output).to include(:lexis_nexis_status, :lexis_nexis_info)
    end

    it 'it produces reasonable output for internal application error' do
      output = described_class.new(internal_application_error_response, false, config).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(network: true)
      expect(output).to include(:lexis_nexis_status, :lexis_nexis_info)
    end

    it 'it produces reasonable output for a TrueID failure without details' do
      output = described_class.new(failure_response_empty, false, config).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(general: [DocAuth::Errors::GENERAL_ERROR_NO_LIVENESS])
      expect(output).to include(:lexis_nexis_status, :lexis_nexis_info, :exception)
    end

    it 'it produces reasonable output for a malformed TrueID response' do
      output = described_class.new(failure_response_malformed, false, config).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(network: true)
      expect(output).to include(:backtrace)
    end
  end

  context 'when front image HDPI is too low' do
    it 'returns an unsuccessful response with front DPI error' do
      output = described_class.new(failure_response_no_liveness_low_dpi, false, config).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(
        general: [DocAuth::Errors::DPI_LOW_ONE_SIDE],
      )
      expect(output[:exception]).to be_nil
      expect(output[:doc_auth_result]).to eq('Failed')
    end
  end
end
