require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::Responses::TrueIdResponse do
  let(:success_response_body) { LexisNexisFixtures.true_id_response_success_3 }
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

  let(:failure_body_tampering) do
    LexisNexisFixtures.true_id_response_failure_tampering
  end

  # rubocop:disable Layout/LineLength
  let(:failure_response_no_liveness) do
    instance_double(Faraday::Response, status: 200, body: failure_body_no_liveness)
  end
  let(:failure_response_with_liveness) do
    instance_double(Faraday::Response, status: 200, body: failure_body_with_liveness)
  end
  let(:failure_response_tampering) do
    instance_double(Faraday::Response, status: 200, body: failure_body_tampering)
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
      expect(extra_attributes[:classification_info]).to include(:Front, :Back)
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
      response_hash = response.to_h
      expect(response_hash).to match(
        success: true,
        exception: nil,
        errors: {},
        attention_with_barcode: false,
        conversation_id: a_kind_of(String),
        doc_type_supported: true,
        reference: a_kind_of(String),
        vendor: 'TrueID',
        billed: true,
        log_alert_results: a_hash_including('2d_barcode_content': { no_side: 'Passed' }),
        transaction_status: 'passed',
        transaction_reason_code: 'trueid_pass',
        product_status: 'pass',
        decision_product_status: 'pass',
        processed_alerts: a_hash_including(:failed),
        address_line2_present: true,
        alert_failure_count: a_kind_of(Numeric),
        portrait_match_results: nil,
        image_metrics: a_hash_including(:front, :back),
        doc_auth_result: 'Passed',
        'ClassificationMode' => 'Automatic',
        'DocAuthResult' => 'Passed',
        'DocClass' => 'DriversLicense',
        'DocClassCode' => 'DriversLicense',
        'DocClassName' => 'Drivers License',
        'DocumentName' => "Maryland (MD) Driver's License - STAR",
        'DocIssuerCode' => 'MD',
        'DocIssuerName' => 'Maryland',
        'DocIssue' => '2016',
        'DocIsGeneric' => 'false',
        'DocIssuerType' => 'StateProvince',
        'DocIssueType' => "Driver's License - STAR",
        'OrientationChanged' => 'true',
        'PresentationChanged' => 'false',
        'DocAuthTamperResult' => 'Passed',
        'DocAuthTamperSensitivity' => 'Normal',
        classification_info: {
          Front: a_hash_including(:ClassName, :CountryCode, :IssuerType),
          Back: a_hash_including(:ClassName, :CountryCode, :IssuerType),
        },
      )
      passed_alerts = response_hash.dig(:processed_alerts, :passed)
      passed_alerts.each do |alert|
        expect(alert).to have_key(:disposition)
      end
      alerts_with_mode_etc = passed_alerts.select do |alert|
        alert[:model].present? && alert[:region].present? && alert[:region_ref].present?
      end
      expect(alerts_with_mode_etc).not_to be_empty
      alerts_with_mode_etc.each do |alert|
        alert[:region_ref].each do |region_ref|
          expect(region_ref).to include(:side, :key)
        end
      end
    end

    it 'notes that address line 2 was present' do
      expect(response.pii_from_doc).to include(address2: 'APT 3E')
      expect(response.to_h).to include(address_line2_present: true)
    end

    it 'mark doc type as supported' do
      expect(response.doc_type_supported?).to eq(true)
    end

    context 'when identification card issued by a country' do
      let(:success_response) do
        body = JSON.parse(LexisNexisFixtures.true_id_response_success_3).tap do |json|
          doc_class_node = json['Products'].first['ParameterDetails'].
            select { |f| f['Name'] == 'DocClassName' && f['Group'] == 'AUTHENTICATION_RESULT' }
          doc_class_node.first['Values'].first['Value'] = 'Identification Card'
          doc_issuer_type = json['Products'].first['ParameterDetails'].
            select { |f| f['Name'] == 'DocIssuerType' && f['Group'] == 'AUTHENTICATION_RESULT' }
          doc_issuer_type.first['Values'].first['Value'] = 'Country'
        end.to_json
        instance_double(Faraday::Response, status: 200, body: body)
      end
      it 'mark doc type as not supported' do
        expect(response.doc_type_supported?).to eq(false)
        expect(response.success?).to eq(false)
      end
    end
  end

  context 'when there is no address line 2' do
    let(:success_response_no_line2) do
      body_no_line2 = JSON.parse(LexisNexisFixtures.true_id_response_success_3).tap do |json|
        json['Products'].first['ParameterDetails'] = json['Products'].first['ParameterDetails'].
          select { |f| f['Name'] != 'Fields_AddressLine2' }
      end.to_json
      instance_double(Faraday::Response, status: 200, body: body_no_line2)
    end

    let(:response) { described_class.new(success_response_no_line2, config) }

    it 'notes that address line 2 was not present' do
      expect(response.pii_from_doc[:address2]).to be_nil
      expect(response.to_h).to include(address_line2_present: false)
    end
  end

  context 'when True_ID response does not contain a decision product status' do
    let(:true_id_response_success_3) { JSON.parse(LexisNexisFixtures.true_id_response_success_3) }
    describe 'when a True_ID Decision product is not present in the response' do
      it 'excludes decision_product_status from logging' do
        body_no_decision = true_id_response_success_3.tap do |json|
          json['Products'].delete_if { |products| products['ProductType'] == 'TrueID_Decision' }
        end.to_json

        decision_product = get_decision_product(true_id_response_success_3)
        expect(decision_product).to be_nil
        success_response_no_decision = instance_double(
          Faraday::Response, status: 200,
                             body: body_no_decision
        )
        response = described_class.new(success_response_no_decision, config)

        expect(response.to_h[:decision_product_status]).to be_nil
      end
    end

    describe 'when a True_ID_Decision does not contain a status' do
      it 'excludes decision_product_status from logging' do
        decision_product = get_decision_product(true_id_response_success_3)
        body_no_decision_status = decision_product.tap do |json|
          json.delete('ProductStatus')
        end.to_json

        expect(decision_product['ProductStatus']).to be_nil
        success_response_no_decision_status = instance_double(
          Faraday::Response, status: 200,
                             body: body_no_decision_status
        )
        response = described_class.new(success_response_no_decision_status, config)

        expect(response.to_h[:decision_product_status]).to be_nil
      end
    end

    def get_decision_product(resp)
      resp['Products'].find { |product| product['ProductType'] == 'TrueID_Decision' }
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
      expect(errors[:general]).to contain_exactly(DocAuth::Errors::GENERAL_ERROR)
      expect(errors[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(errors[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(errors[:hints]).to eq(true)
    end

    it 'returns Failed for visible_pattern when it gets passed and failed value ' do
      output = described_class.new(failure_response_no_liveness, config).to_h
      expect(output.to_h[:log_alert_results]).
        to match(a_hash_including(visible_pattern: { no_side: 'Failed' }))
    end

    it 'returns Failed for liveness failure' do
      output = described_class.new(failure_response_with_liveness, config).to_h
      expect(output[:success]).to eq(false)
    end

    it 'produces expected hash output' do
      output = described_class.new(failure_response_with_all_failures, config).to_h

      expect(output).to match(
        success: false,
        exception: nil,
        errors: {
          general: [DocAuth::Errors::GENERAL_ERROR],
          front: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
          back: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
          hints: true,
        },
        attention_with_barcode: false,
        doc_type_supported: true,
        conversation_id: a_kind_of(String),
        reference: a_kind_of(String),
        vendor: 'TrueID',
        billed: true,
        log_alert_results: a_hash_including('2d_barcode_content': { no_side: 'Failed' }),
        transaction_status: 'failed',
        transaction_reason_code: 'failed_true_id',
        product_status: 'pass',
        decision_product_status: 'fail',
        doc_auth_result: 'Failed',
        processed_alerts: a_hash_including(:passed, :failed),
        address_line2_present: false,
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
        'DocumentName' => 'Connecticut (CT) Driver License',
        'DocIssuerCode' => 'CT',
        'DocIssuerType' => 'StateProvince',
        'DocIssuerName' => 'Connecticut',
        'DocIssue' => '2009',
        'DocIssueType' => 'Driver License',
        'DocIsGeneric' => 'false',
        'OrientationChanged' => 'false',
        'PresentationChanged' => 'false',
        classification_info: {
          Front: a_hash_including(:ClassName, :CountryCode, :IssuerType),
          Back: a_hash_including(:ClassName, :CountryCode, :IssuerType),
        },
      )
    end
    it 'produces appropriate errors with document tampering' do
      output = described_class.new(failure_response_tampering, config).to_h
      errors = output[:errors]
      expect(output.to_h[:log_alert_results]).to include(
        document_tampering_detection: { no_side: 'Failed' },
      )
      expect(output[:success]).to eq(false)
      expect(errors.keys).to contain_exactly(:general, :front, :back, :hints)
      # we dont have specific error for tampering yet
      expect(errors[:general]).to contain_exactly(DocAuth::Errors::GENERAL_ERROR)
      expect(errors[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(errors[:back]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(errors[:hints]).to eq(true)
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
        general: [DocAuth::Errors::GENERAL_ERROR],
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

  describe '#doc_type_supported?' do
    let(:doc_class_name) { 'Drivers License' }
    let(:success_response) do
      response = JSON.parse(LexisNexisFixtures.true_id_response_success_3).tap do |json|
        doc_class_node = json['Products'].first['ParameterDetails'].
          select { |f| f['Name'] == 'DocClassName' }
        doc_class_node.first['Values'].first['Value'] = doc_class_name
      end.to_json
      instance_double(Faraday::Response, status: 200, body: response)
    end

    subject(:doc_type_supported?) do
      described_class.new(success_response, config).doc_type_supported?
    end
    it { is_expected.to eq(true) }

    context 'when doc class is unknown' do
      let(:doc_class_name) { 'Unknown' }
      it 'identified as supported doc type ' do
        is_expected.to eq(true)
      end
    end

    context 'when doc class is identified but not supported' do
      let(:doc_class_name) { 'Passport' }
      it 'identified as un supported doc type ' do
        is_expected.to eq(false)
      end
    end

    context 'when country code is not supported' do
      let(:success_response) do
        body = JSON.parse(LexisNexisFixtures.true_id_response_success_3).tap do |json|
          doc_country_node = json['Products'].first['ParameterDetails'].
            select { |f| f['Name'] == 'Fields_CountryCode' && f['Group'] == 'IDAUTH_FIELD_DATA' }
          doc_country_node.first['Values'].first['Value'] = 'CAN'
        end.to_json
        instance_double(Faraday::Response, status: 200, body: body)
      end
      it 'identify as unsupported doc type' do
        is_expected.to eq(false)
      end
    end

    context 'when id is federal identification card' do
      let(:success_response) do
        body = JSON.parse(LexisNexisFixtures.true_id_response_success_3).tap do |json|
          doc_class_node = json['Products'].first['ParameterDetails'].
            select { |f| f['Name'] == 'DocClassName' && f['Group'] == 'AUTHENTICATION_RESULT' }
          doc_class_node.first['Values'].first['Value'] = 'Identification Card'
          doc_issuer_type = json['Products'].first['ParameterDetails'].
            select { |f| f['Name'] == 'DocIssuerType' && f['Group'] == 'AUTHENTICATION_RESULT' }
          doc_issuer_type.first['Values'].first['Value'] = 'Country'
        end.to_json
        instance_double(Faraday::Response, status: 200, body: body)
      end
      it 'identify as unsupported doc type' do
        is_expected.to eq(false)
      end
    end

    context 'when id is federal ID and image dpi is low' do
      let(:error_response) do
        body = JSON.parse(LexisNexisFixtures.true_id_response_success_3).tap do |json|
          doc_class_node = json['Products'].first['ParameterDetails'].
            select { |f| f['Name'] == 'DocClassName' && f['Group'] == 'AUTHENTICATION_RESULT' }
          doc_class_node.first['Values'].first['Value'] = 'Identification Card'
          doc_issuer_type = json['Products'].first['ParameterDetails'].
            select { |f| f['Name'] == 'DocIssuerType' && f['Group'] == 'AUTHENTICATION_RESULT' }
          doc_issuer_type.first['Values'].first['Value'] = 'Country'

          image_metric_resolution = json['Products'].first['ParameterDetails'].
            select do |f|
            f['Group'] == 'IMAGE_METRICS_RESULT' &&
              f['Name'] == 'HorizontalResolution'
          end
          image_metric_resolution.first['Values'].first['Value'] = 50
        end.to_json
        instance_double(Faraday::Response, status: 200, body: body)
      end
      it 'mark doc type as not supported' do
        response = described_class.new(error_response, config)
        expect(response.doc_type_supported?).to eq(false)
      end
    end
  end
end
