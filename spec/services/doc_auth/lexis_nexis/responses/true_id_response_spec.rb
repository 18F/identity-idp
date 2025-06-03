require 'rails_helper'

RSpec.describe DocAuth::LexisNexis::Responses::TrueIdResponse do
  let(:success_response_body) { LexisNexisFixtures.true_id_response_success_3 }
  let(:success_response) do
    instance_double(Faraday::Response, status: 200, body: success_response_body)
  end
  # rubocop:disable Layout/LineLength
  let(:success_with_liveness_response) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_response_success_with_liveness)
  end
  let(:success_with_passport_response) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_response_passport)
  end
  let(:doc_auth_success_with_face_match_fail) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_response_with_face_match_fail)
  end
  let(:success_with_failed_to_ocr_dob) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_response_failed_to_ocr_dob)
  end
  let(:success_with_passport_failed_to_ocr_dob) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_response_passport_failed_to_ocr_dob)
  end
  let(:failure_response_face_match_fail) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_response_with_face_match_fail)
  end
  let(:failure_response_no_liveness) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_response_failure_no_liveness)
  end
  let(:failure_response_with_liveness) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_response_failure_with_liveness)
  end
  let(:failure_response_tampering) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_response_failure_tampering)
  end
  let(:failure_response_passport_tampering) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_response_passport_failure_tampering)
  end
  let(:failure_response_with_all_failures) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_response_failure_with_all_failures)
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
  let(:attention_barcode_read_with_face_match_fail) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_barcode_read_attention_with_face_match_fail)
  end
  let(:failure_response_no_liveness_low_dpi) do
    instance_double(Faraday::Response, status: 200, body: LexisNexisFixtures.true_id_response_failure_no_liveness_low_dpi)
  end
  # rubocop:enable Layout/LineLength

  let(:config) do
    DocAuth::LexisNexis::Config.new
  end
  let(:liveness_checking_enabled) { false }
  let(:workflow) { 'default_workflow' }
  let(:mrz) do
    'P<UTOSAMPLE<<COMPANY<<<<<<<<<<<<<<<<<<<<<<<<ACU1234P<5UTO0003067F4003065<<<<<<<<<<<<<<02'
  end
  let(:request_context) do
    {
      workflow: workflow,
    }
  end
  context 'when the response is a success' do
    let(:response) do
      described_class.new(success_response, config, liveness_checking_enabled, request_context)
    end

    it 'is a successful result' do
      expect(response.successful_result?).to eq(true)
      expect(response.selfie_status).to eq(:not_processed)
      expect(response.success?).to eq(true)
      expect(response.to_h[:vendor]).to eq('TrueID')
    end

    context 'when a portrait match is returned' do
      let(:liveness_checking_enabled) { true }
      context 'when selfie status is failed' do
        let(:response) do
          described_class.new(
            doc_auth_success_with_face_match_fail, config,
            liveness_checking_enabled, request_context
          )
        end
        it 'is a failed result' do
          expect(response.selfie_status).to eq(:fail)
          expect(response.success?).to eq(false)
          expect(response.to_h[:vendor]).to eq('TrueID')
        end
      end

      context 'when selfie status passes' do
        let(:response) do
          described_class.new(
            success_with_liveness_response, config, liveness_checking_enabled,
            request_context
          )
        end
        it 'is a successful result' do
          expect(response.selfie_status).to eq(:success)
          expect(response.success?).to eq(true)
          expect(response.to_h[:vendor]).to eq('TrueID')
        end
      end
    end

    it 'has no error messages' do
      expect(response.error_messages).to be_empty
    end
    it 'has extra attributes' do
      extra_attributes = response.extra_attributes
      expect(extra_attributes).not_to be_empty
      expect(extra_attributes[:classification_info]).to include(:Front, :Back)
      expect(extra_attributes).to have_key(:workflow)
      expect(extra_attributes).to have_key(:reference)
    end
    it 'has PII data' do
      expected_state_id_pii = Pii::StateId.new(
        first_name: 'DAVID',
        last_name: 'SAMPLE',
        middle_name: 'LICENSE',
        name_suffix: nil,
        address1: '123 ABC AVE',
        address2: 'APT 3E',
        city: 'ANYTOWN',
        state: 'MD',
        dob: '1986-07-01',
        sex: 'male',
        height: 69,
        weight: nil,
        eye_color: nil,
        state_id_expiration: '2099-10-15',
        state_id_issued: '2016-10-15',
        state_id_jurisdiction: 'MD',
        state_id_number: 'M555555555555',
        id_doc_type: 'drivers_license',
        zipcode: '12345',
        issuing_country_code: 'USA',
      )

      expect(response.pii_from_doc.to_h).to eq(expected_state_id_pii.to_h)
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
        request_id: a_kind_of(String),
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
        doc_auth_success: true,
        selfie_status: :not_processed,
        selfie_live: true,
        selfie_quality_good: true,
        liveness_enabled: false,
        workflow: anything,
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
      expect(response.pii_from_doc.address2).to eq('APT 3E')
      expect(response.to_h).to include(address_line2_present: true)
    end

    it 'mark doc type as supported' do
      expect(response.doc_type_supported?).to eq(true)
    end

    context 'when identification card issued by a library' do
      let(:success_response) do
        body = JSON.parse(LexisNexisFixtures.true_id_response_success_3).tap do |json|
          doc_class_node = json['Products'].first['ParameterDetails']
            .select { |f| f['Name'] == 'DocClassName' && f['Group'] == 'AUTHENTICATION_RESULT' }
          doc_class_node.first['Values'].first['Value'] = 'Identification Card'
          doc_issuer_type = json['Products'].first['ParameterDetails']
            .select { |f| f['Name'] == 'DocIssuerType' && f['Group'] == 'AUTHENTICATION_RESULT' }
          doc_issuer_type.first['Values'].first['Value'] = 'Library'
        end.to_json
        instance_double(Faraday::Response, status: 200, body: body)
      end
      it 'mark doc type as not supported' do
        expect(response.doc_type_supported?).to eq(false)
        expect(response.success?).to eq(false)
      end
    end

    context 'when height is present' do
      let(:success_response_body) { LexisNexisFixtures.true_id_response_success }

      it 'properly converts the height to inches' do
        pii_from_doc = response.pii_from_doc
        expect(pii_from_doc.height).to eq(68)
      end

      context 'when the height has a space in it' do
        # This fixture has the height returns as "5' 9\""
        let(:success_response_body) { LexisNexisFixtures.true_id_response_success_3 }

        it 'reads parses the height correctly' do
          pii_from_doc = response.pii_from_doc

          expect(pii_from_doc.height).to eq(69)
        end
      end
    end
  end

  context 'when the response is a success for passport' do
    let(:response) do
      described_class.new(
        success_with_passport_response,
        config,
        liveness_checking_enabled,
        request_context,
      )
    end

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
      expect(extra_attributes[:classification_info]).to include(:Front)
      expect(extra_attributes).to have_key(:workflow)
      expect(extra_attributes).to have_key(:reference)
    end
    it 'has PII data' do
      expected_passport_pii = Pii::Passport.new(
        first_name: 'DAVID',
        last_name: 'SAMPLE',
        middle_name: 'PASSPORT',
        dob: '1986-07-01',
        sex: 'male',
        birth_place: 'MY CITY. U.S.A.',
        passport_expiration: '2099-10-15',
        passport_issued: '2016-10-15',
        nationality_code: 'USA',
        issuing_country_code: 'USA',
        mrz: mrz,
        id_doc_type: 'passport',
        document_number: 'Z12345678',
      )

      expect(response.pii_from_doc.to_h).to eq(expected_passport_pii.to_h)
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
        request_id: a_kind_of(String),
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
        address_line2_present: false,
        alert_failure_count: a_kind_of(Numeric),
        portrait_match_results: nil,
        image_metrics: a_hash_including(:front),
        doc_auth_result: 'Passed',
        'ClassificationMode' => 'Automatic',
        'DocAuthResult' => 'Passed',
        'DocClass' => 'Passport',
        'DocClassCode' => 'Passport',
        'DocClassName' => 'Passport',
        'DocumentName' => 'United States (USA) Passport - STAR',
        'DocIssuerCode' => 'USA',
        'DocIssuerName' => 'United States',
        'DocIssue' => '2016',
        'DocIsGeneric' => 'false',
        'DocIssuerType' => 'StateProvince',
        'DocIssueType' => 'Passport - STAR',
        'OrientationChanged' => 'true',
        'PresentationChanged' => 'false',
        'DocAuthTamperResult' => 'Passed',
        'DocAuthTamperSensitivity' => 'Normal',
        classification_info: {
          Front: a_hash_including(:ClassName, :CountryCode, :IssuerType),
        },
        doc_auth_success: true,
        selfie_status: :not_processed,
        selfie_live: true,
        selfie_quality_good: true,
        liveness_enabled: false,
        workflow: anything,
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

    it 'mark doc type as supported' do
      expect(response.doc_type_supported?).to eq(true)
    end
  end

  context 'when the response is a failure for passport' do
    it 'produces appropriate errors with passport tampering' do
      response = described_class.new(failure_response_passport_tampering, config)
      output = response.to_h
      errors = output[:errors]
      expect(output.to_h[:log_alert_results]).to include(
        document_tampering_detection: { no_side: 'Failed' },
      )
      expect(output[:success]).to eq(false)
      expect(errors.keys).to contain_exactly(:general, :front, :back, :hints)
      # we dont have specific error for tampering yet
      expect(errors[:general]).to contain_exactly(DocAuth::Errors::GENERAL_ERROR)
      expect(errors[:front]).to contain_exactly(DocAuth::Errors::FALLBACK_FIELD_LEVEL)
      expect(errors[:hints]).to eq(true)
      expect(response.doc_auth_success?).to eq(false)
    end
  end

  context 'when there is no address line 2' do
    let(:success_response_no_line2) do
      body_no_line2 = JSON.parse(LexisNexisFixtures.true_id_response_success_3).tap do |json|
        json['Products'].first['ParameterDetails'] = json['Products'].first['ParameterDetails']
          .select { |f| f['Name'] != 'Fields_AddressLine2' }
      end.to_json
      instance_double(Faraday::Response, status: 200, body: body_no_line2)
    end

    let(:response) { described_class.new(success_response_no_line2, config) }

    it 'notes that address line 2 was not present' do
      expect(response.pii_from_doc.address2).to be_nil
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
      expected_state_id_pii = Pii::StateId.new(
        first_name: 'DAVID',
        last_name: 'SAMPLE',
        middle_name: 'LICENSE',
        name_suffix: nil,
        address1: '123 ABC AVE',
        address2: nil,
        city: 'ANYTOWN',
        state: 'MD',
        dob: '1986-10-13',
        sex: 'male',
        height: 70,
        weight: nil,
        eye_color: nil,
        state_id_expiration: '2099-10-15',
        state_id_issued: '2016-10-15',
        state_id_jurisdiction: 'MD',
        state_id_number: 'M555555555555',
        id_doc_type: 'drivers_license',
        zipcode: '12345',
        issuing_country_code: nil,
      )

      expect(response.pii_from_doc.to_h).to eq(expected_state_id_pii.to_h)
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
    context 'when liveness enabled' do
      let(:liveness_checking_enabled) { true }
      it 'returns Failed for visible_pattern when it gets passed and failed value ' do
        output = described_class.new(
          failure_response_no_liveness, config,
          liveness_checking_enabled
        ).to_h
        expect(output.to_h[:log_alert_results])
          .to match(a_hash_including(visible_pattern: { no_side: 'Failed' }))
      end

      it 'returns Failed for liveness failure' do
        response = described_class.new(
          failure_response_with_liveness, config,
          liveness_checking_enabled
        )
        output = response.to_h
        expect(output[:success]).to eq(false)
        expect(response.doc_auth_success?).to eq(false)
        expect(response.selfie_status).to eq(:fail)
      end

      it 'produces expected hash output' do
        output = described_class.new(
          failure_response_with_all_failures, config, liveness_checking_enabled,
          request_context
        ).to_h

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
          request_id: a_kind_of(String),
          reference: a_kind_of(String),
          vendor: 'TrueID',
          billed: true,
          log_alert_results: a_hash_including('2d_barcode_content': { no_side: 'Failed' }),
          transaction_status: 'failed',
          transaction_reason_code: 'failed_true_id',
          product_status: 'fail',
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
          doc_auth_success: false,
          selfie_status: :fail,
          selfie_live: true,
          selfie_quality_good: false,
          liveness_enabled: true,
          workflow: anything,
        )
      end
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
      output = described_class.new(
        failure_response_empty, config, liveness_checking_enabled,
        request_context
      ).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(
        general: [DocAuth::Errors::GENERAL_ERROR],
        hints: true,
      )
      expect(output).to include(:lexis_nexis_status, :lexis_nexis_info, :exception)
      expect(output[:vendor]).to eq('TrueID')
      expect(output[:reference]).to match(a_kind_of(String))
    end

    it 'produces reasonable output for a malformed TrueID response' do
      allow(NewRelic::Agent).to receive(:notice_error)
      output = described_class.new(
        failure_response_malformed, config, liveness_checking_enabled,
        request_context
      ).to_h

      expect(output[:success]).to eq(false)
      expect(output[:errors]).to eq(network: true)
      expect(output).to include(:backtrace)
      expect(output[:reference]).to be_truthy
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
    let(:response) { described_class.new(success_with_failed_to_ocr_dob, config) }

    it 'does not throw an exception when getting pii from doc' do
      expect(response.pii_from_doc.dob).to be_nil
    end
  end

  context 'when the dob is incorrectly parsed in passport' do
    let(:response) { described_class.new(success_with_passport_failed_to_ocr_dob, config) }

    it 'does not throw an exception when getting pii from doc' do
      expect(response.pii_from_doc.dob).to be_nil
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

    context 'with barcode attention error' do
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

      parameter = body[:Products]
        .first[:ParameterDetails]
        .find { |h| h[:Name] == 'DocAuthResult' }

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
        doc_class_node = json['Products'].first['ParameterDetails']
          .select { |f| f['Name'] == 'DocClassName' }
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
      let(:doc_class_name) { 'Non-Document-Type' }
      it 'identified as un supported doc type ' do
        is_expected.to eq(false)
      end
    end

    context 'when country code is not supported' do
      let(:success_response) do
        body = JSON.parse(LexisNexisFixtures.true_id_response_success_3).tap do |json|
          doc_country_node = json['Products'].first['ParameterDetails']
            .select { |f| f['Name'] == 'Fields_CountryCode' && f['Group'] == 'IDAUTH_FIELD_DATA' }
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
          doc_class_node = json['Products'].first['ParameterDetails']
            .select { |f| f['Name'] == 'DocClassName' && f['Group'] == 'AUTHENTICATION_RESULT' }
          doc_class_node.first['Values'].first['Value'] = 'Identification Card'
          doc_issuer_type = json['Products'].first['ParameterDetails']
            .select { |f| f['Name'] == 'DocIssuerType' && f['Group'] == 'AUTHENTICATION_RESULT' }
          doc_issuer_type.first['Values'].first['Value'] = 'National'
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
          doc_class_node = json['Products'].first['ParameterDetails']
            .select { |f| f['Name'] == 'DocClassName' && f['Group'] == 'AUTHENTICATION_RESULT' }
          doc_class_node.first['Values'].first['Value'] = 'Identification Card'
          doc_issuer_type = json['Products'].first['ParameterDetails']
            .select { |f| f['Name'] == 'DocIssuerType' && f['Group'] == 'AUTHENTICATION_RESULT' }
          doc_issuer_type.first['Values'].first['Value'] = 'National'

          image_metric_resolution = json['Products'].first['ParameterDetails']
            .select do |f|
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
  describe '#doc_auth_success?' do
    context 'when document validation is successful' do
      let(:response) { described_class.new(success_response, config) }
      it 'returns true' do
        expect(response.doc_auth_success?).to eq(true)
      end
    end
    context 'when document validation failed' do
      let(:response) { described_class.new(failure_response_tampering, config) }
      it 'returns false' do
        expect(response.doc_auth_success?).to eq(false)
      end
    end

    context 'when attention barcode read' do
      let(:response) { described_class.new(attention_barcode_read, config) }
      it 'returns true' do
        expect(response.doc_auth_success?).to eq(true)
      end
    end
  end

  describe '#selfie_status' do
    context 'when selfie check is disabled' do
      let(:response) { described_class.new(success_response, config, false) }
      it 'returns :not_processed' do
        expect(response.selfie_status).to eq(:not_processed)
      end
    end

    context 'when selfie check is enabled' do
      context 'when missing selfie result in response' do
        let(:request_context) do
          {
            workflow: 'selfie_workflow',
          }
        end
        let(:response) { described_class.new(success_response, config, true, request_context) }
        it 'returns :not_processed when missing selfie in response' do
          expect(response.selfie_status).to eq(:not_processed)
        end
        it 'includes workflow in extra_attributes' do
          expect(response.extra_attributes).to include(
            workflow: 'selfie_workflow',
          )
        end
      end
      context 'when selfie passed' do
        let(:response) { described_class.new(success_with_liveness_response, config, true) }
        it 'returns :success' do
          expect(response.selfie_status).to eq(:success)
        end
      end
      context 'when selfie failed' do
        let(:response) { described_class.new(failure_response_with_liveness, config, true) }
        it 'returns :fail' do
          expect(response.selfie_status).to eq(:fail)
        end
      end
    end
  end

  describe '#successful_result?' do
    context 'selfie check is disabled' do
      liveness_checking_enabled = false

      context 'when document validation is successful' do
        let(:response) { described_class.new(success_response, config) }
        it 'returns true' do
          expect(response.successful_result?).to eq(true)
        end
      end

      it 'returns true no matter what the value of selfie is' do
        response = described_class.new(
          doc_auth_success_with_face_match_fail, config, liveness_checking_enabled
        )

        expect(response.successful_result?).to eq(true)
      end
    end

    context 'selfie check is enabled' do
      let(:liveness_checking_enabled) { true }

      it 'returns true with a passing selfie' do
        response = described_class.new(
          success_with_liveness_response, config, liveness_checking_enabled
        )

        expect(response.successful_result?).to eq(true)
      end
      context 'when portrait match fails' do
        it 'returns false with a failing selfie' do
          response = described_class.new(
            doc_auth_success_with_face_match_fail, config, liveness_checking_enabled
          )

          expect(response.successful_result?).to eq(false)
        end
        context 'when attention with barcode' do
          let(:response) do
            described_class.new(
              attention_barcode_read_with_face_match_fail,
              config,
              liveness_checking_enabled,
            )
          end

          it 'returns false' do
            expect(response.doc_auth_success?).to eq(true)
            expect(response.selfie_passed?).to eq(false)
            expect(response.successful_result?).to eq(false)
          end
        end
      end
    end
  end
end
