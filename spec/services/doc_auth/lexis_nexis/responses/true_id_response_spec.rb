require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::Responses::TrueIdResponse do
  let(:success_response_body) { LexisNexisFixtures.true_id_response_success_2 }
  let(:success_response) do
    instance_double(Faraday::Response, status: 200, body: success_response_body)
  end
  let(:failure_body_no_liveness) { LexisNexisFixtures.true_id_response_failure_no_liveness }
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
    let(:response) { described_class.new(success_response, config) }

    it 'is a successful result' do
      expect(response.successful_result?).to eq(true)
      expect(response.to_h[:vendor]).to eq('TrueID')
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
        dob: '1986-07-01',
        state: 'MD',
        state_id_type: 'drivers_license',
      }

      expect(response.pii_from_doc).to include(minimum_expected_hash)
    end
    it 'includes expiration' do
      expect(response.pii_from_doc).to include(state_id_expiration: '2099-10-15')
    end
    it 'includes issued date' do
      expect(response.pii_from_doc).to include(state_id_issued: '2016-10-15')
    end

    it 'excludes pii fields from logging' do
      expect(response.extra_attributes.keys).to_not include(*described_class::PII_EXCLUDES)
    end

    it 'excludes unnecessary raw Alert data from logging' do
      expect(response.extra_attributes.keys.any? { |key| key.start_with?('Alert_') }).to eq(false)
    end

    it 'produces expected hash output' do
      expect(response.to_h).to match(
        success: true,
        exception: nil,
        errors: {},
        attention_with_barcode: false,
        conversation_id: a_kind_of(String),
        reference: a_kind_of(String),
        vendor: 'TrueID',
        billed: true,
        log_alert_results: a_hash_including('2d_barcode_content': { no_side: 'Passed' }),
        transaction_status: 'passed',
        transaction_reason_code: 'trueid_pass',
        product_status: 'pass',
        doc_auth_result: 'Passed',
        processed_alerts: a_hash_including(:failed),
        alert_failure_count: a_kind_of(Numeric),
        portrait_match_results: nil,
        image_metrics: a_hash_including(:front, :back),
        'ClassificationMode' => 'Automatic',
        'DocAuthResult' => 'Passed',
        'DocClass' => 'DriversLicense',
        'DocClassCode' => 'DriversLicense',
        'DocClassName' => 'Drivers License',
        'DocIsGeneric' => 'false',
        'DocIssuerType' => 'StateProvince',
        'OrientationChanged' => 'true',
        'PresentationChanged' => 'false',
      )
    end
  end

  context 'when the barcode can not be read' do
    let(:response) do
      described_class.new(attention_barcode_read, config)
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
        state_id_type: 'drivers_license',
      }

      expect(response.pii_from_doc).to include(minimum_expected_hash)
    end
    it 'includes expiration' do
      expect(response.pii_from_doc).to include(state_id_expiration: '2099-10-15')
    end
    it 'includes issued date' do
      expect(response.pii_from_doc).to include(state_id_issued: '2016-10-15')
    end
  end

  context 'when response is not a success' do
    it 'produces appropriate errors without liveness' do
      output = described_class.new(failure_response_no_liveness, config).to_h
      errors = output[:errors]
      expect(output.to_h[:log_alert_results]).to eq(
        '2d_barcode_read': { no_side: 'Passed' },
        birth_date_crosscheck: { no_side: 'Passed' },
        birth_date_valid: { no_side: 'Passed' },
        document_classification: { no_side: 'Passed' },
        document_crosscheck_aggregation: { no_side: 'Passed' },
        document_number_crosscheck: { no_side: 'Passed' },
        expiration_date_crosscheck: { no_side: 'Passed' },
        expiration_date_valid: { no_side: 'Passed' },
        full_name_crosscheck: { no_side: 'Passed' },
        issue_date_crosscheck: { no_side: 'Passed' },
        issue_date_valid: { no_side: 'Passed' },
        layout_valid: { no_side: 'Passed' },
        sex_crosscheck: { no_side: 'Passed' },
        visible_color_response: { no_side: 'Passed' },
        visible_pattern: { no_side: 'Failed' },
        visible_photo_characteristics: { no_side: 'Passed' },
        '1d_control_number_valid': { no_side: 'Failed' },
        '2d_barcode_content': { no_side: 'Failed' },
        control_number_crosscheck: { no_side: 'Caution' },
        document_expired: { no_side: 'Attention' },
      )
      expect(output[:success]).to eq(false)
      expect(errors.keys).to contain_exactly(:general, :front, :back, :hints)
      expect(errors[:general]).to contain_exactly(DocAuth::Errors::GENERAL_ERROR_NO_LIVENESS)
      expect(errors[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(errors[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(errors[:hints]).to eq(true)
    end

    it 'returns Failed for visible_pattern when it gets passed and failed value ' do
      output = described_class.new(failure_response_no_liveness, config).to_h
      expect(output.to_h[:log_alert_results]).
        to match(a_hash_including(visible_pattern: { no_side: 'Failed' }))
    end

    it 'produces expected hash output' do
      output = described_class.new(failure_response_with_all_failures, config).to_h

      expect(output).to match(
        success: false,
        exception: nil,
        errors: {
          general: [DocAuth::Errors::GENERAL_ERROR_NO_LIVENESS],
          front: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
          back: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
          hints: true,
        },
        attention_with_barcode: false,
        conversation_id: a_kind_of(String),
        reference: a_kind_of(String),
        vendor: 'TrueID',
        billed: true,
        log_alert_results: a_hash_including('2d_barcode_content': { no_side: 'Failed' }),
        transaction_status: 'failed',
        transaction_reason_code: 'failed_true_id',
        product_status: 'pass',
        doc_auth_result: 'Failed',
        processed_alerts: a_hash_including(:passed, :failed),
        alert_failure_count: a_kind_of(Numeric),
        portrait_match_results: {
          'FaceMatchResult' => 'Fail',
          'FaceMatchScore' => '0',
          'FaceStatusCode' => '0',
          'FaceErrorMessage' => 'Liveness: PoorQuality',
        },
        image_metrics: a_hash_including(:front, :back),
        'ClassificationMode' => 'Automatic',
        'DocAuthResult' => 'Failed',
        'DocClass' => 'DriversLicense',
        'DocClassCode' => 'DriversLicense',
        'DocClassName' => 'Drivers License',
        'DocIsGeneric' => 'false',
        'OrientationChanged' => 'false',
        'PresentationChanged' => 'false',
      )
    end
  end

  context 'when response is unexpected' do
    it 'produces reasonable output for communications error' do
      output = described_class.new(communications_error_response, config).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(network: true)
      expect(output).to include(:lexis_nexis_status, :lexis_nexis_info)
      expect(output[:vendor]).to eq('TrueID')
    end

    it 'produces reasonable output for internal application error' do
      output = described_class.new(internal_application_error_response, config).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(network: true)
      expect(output).to include(:lexis_nexis_status, :lexis_nexis_info)
    end

    it 'produces reasonable output for a TrueID failure without details' do
      output = described_class.new(failure_response_empty, config).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(
        general: [DocAuth::Errors::GENERAL_ERROR_NO_LIVENESS],
        hints: true,
      )
      expect(output).to include(:lexis_nexis_status, :lexis_nexis_info, :exception)
      expect(output[:vendor]).to eq('TrueID')
    end

    it 'produces reasonable output for a malformed TrueID response' do
      output = described_class.new(failure_response_malformed, config).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(network: true)
      expect(output).to include(:backtrace)
    end

    it 'is not billed' do
      output = described_class.new(failure_response_empty, config).to_h

      expect(output[:billed]).to eq(false)
    end
  end

  context 'when front image HDPI is too low' do
    it 'returns an unsuccessful response with front DPI error' do
      output = described_class.new(failure_response_no_liveness_low_dpi, config).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(
        general: [DocAuth::Errors::DPI_LOW_ONE_SIDE],
        front: [DocAuth::Errors::DPI_LOW_FIELD],
        hints: false,
      )
      expect(output[:exception]).to be_nil
      expect(output[:doc_auth_result]).to eq('Failed')
    end
  end

  context 'when the dob is incorrectly parsed' do
    let(:response) { described_class.new(success_response, config) }
    let(:bad_pii) { { dob_year: 'OCR', dob_month: 'failed', dob_day: 'to parse' } }

    it 'does not throw an exception when getting pii from doc' do
      allow(response).to receive(:pii).and_return(bad_pii)
      expect { response.pii_from_doc }.not_to raise_error
    end
  end

  describe '#parse_date' do
    let(:response) { described_class.new(success_response, config) }

    it 'handles an invalid month' do
      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info).with(
        { event: 'Failure to parse TrueID date' }.to_json,
      ).once
      expect(response.send(:parse_date, year: 2022, month: 13, day: 1)).to eq(nil)
    end

    it 'handles an invalid leap day' do
      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info).with(
        { event: 'Failure to parse TrueID date' }.to_json,
      ).once
      expect(response.send(:parse_date, year: 2022, month: 2, day: 29)).to eq(nil)
    end

    it 'handles a day past the end of the month' do
      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:info).with(
        { event: 'Failure to parse TrueID date' }.to_json,
      ).once
      expect(response.send(:parse_date, year: 2022, month: 4, day: 31)).to eq(nil)
    end
  end

  describe '#attention_with_barcode?' do
    let(:response) { described_class.new(success_response, config) }
    subject(:attention_with_barcode) { response.attention_with_barcode? }

    it { expect(attention_with_barcode).to eq(false) }

    context 'with multiple errors including barcode attention' do
      let(:response) { described_class.new(failure_response_with_all_failures, config) }

      it { expect(attention_with_barcode).to eq(false) }
    end

    context 'with single barcode attention error' do
      let(:response) { described_class.new(attention_barcode_read, config) }

      it { expect(attention_with_barcode).to eq(true) }
    end
  end

  describe '#billed?' do
    subject(:billed?) do
      described_class.new(success_response, config).billed?
    end

    let(:success_response_body) do
      body = JSON.parse(super(), symbolize_names: true)

      parameter = body[:Products].
        first[:ParameterDetails].
        find { |h| h[:Name] == 'DocAuthResult' }

      parameter[:Values] = [{ Value: doc_auth_result }]

      body.to_json
    end

    context 'with no doc auth result' do
      let(:doc_auth_result) { nil }
      it { is_expected.to eq(false) }
    end

    context 'with doc auth result of Passed' do
      let(:doc_auth_result) { 'Passed' }
      it { is_expected.to eq(true) }
    end

    context 'with doc auth result of Attention' do
      let(:doc_auth_result) { 'Attention' }
      it { is_expected.to eq(true) }
    end

    context 'with doc auth result of Unknown' do
      let(:doc_auth_result) { 'Unknown' }
      it { is_expected.to eq(true) }
    end
  end
end
