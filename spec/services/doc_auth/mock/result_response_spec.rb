require 'rails_helper'

RSpec.describe DocAuth::Mock::ResultResponse do
  let(:warn_notifier) { instance_double('Proc') }
  let(:selfie_required) { false }
  subject(:response) do
    config = DocAuth::Mock::Config.new(
      dpi_threshold: 290,
      sharpness_threshold: 40,
      glare_threshold: 40,
      warn_notifier: warn_notifier,
    )
    described_class.new(input, config, selfie_required)
  end

  context 'with an image file' do
    let(:input) { DocAuthImageFixtures.document_front_image }
    let(:selfie_required) { true }
    it 'returns a successful response with the default PII' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc.to_h)
        .to eq(Idp::Constants::MOCK_IDV_APPLICANT)
      expect(response.attention_with_barcode?).to eq(false)
      expect(response.selfie_status).to eq(:success)
    end
  end

  context 'with a yaml file containing PII' do
    let(:input) do
      <<~YAML
        document:
          first_name: Susan
          last_name: Smith
          middle_name: Q
          name_suffix:
          address1: 1 Microsoft Way
          address2: Apt 3
          city: Bayside
          state: NY
          zipcode: '11364'
          dob: 1938-10-06
          sex: female
          height: 66
          state_id_number: '111111111'
          state_id_jurisdiction: ND
          id_doc_type: drivers_license
          state_id_expiration: '2089-12-31'
          state_id_issued: '2009-12-31'
          issuing_country_code: 'CA'
      YAML
    end

    it 'returns a result with that PII' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq(
        Pii::StateId.new(
          first_name: 'Susan',
          middle_name: 'Q',
          last_name: 'Smith',
          name_suffix: nil,
          address1: '1 Microsoft Way',
          address2: 'Apt 3',
          city: 'Bayside',
          state: 'NY',
          zipcode: '11364',
          dob: '1938-10-06',
          sex: 'female',
          height: 66,
          weight: nil,
          eye_color: nil,
          state_id_number: '111111111',
          state_id_jurisdiction: 'ND',
          id_doc_type: 'drivers_license',
          state_id_expiration: '2089-12-31',
          state_id_issued: '2009-12-31',
          issuing_country_code: 'CA',
        ),
      )
      expect(response.attention_with_barcode?).to eq(false)
    end
  end

  context 'with a yaml file containing PII and an american-style date' do
    let(:input) do
      <<~YAML
        document:
          first_name: Susan
          last_name: Smith
          middle_name: Q
          address1: 1 Microsoft Way
          address2: Apt 3
          city: Bayside
          state: NY
          zipcode: '11364'
          dob: 10/06/1938
          state_id_number: '111111111'
          state_id_jurisdiction: ND
          id_doc_type: drivers_license
      YAML
    end

    it 'returns a result with that PII' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc.dob).to eq('1938-10-06')
      expect(response.attention_with_barcode?).to eq(false)
    end
  end

  context 'with a yaml file containing a failed alert' do
    let(:input) do
      <<~YAML
        failed_alerts:
          - name: 1D Control Number Valid
            result: Failed
          - name: 2D Barcode Read
            result: Attention
      YAML
    end

    it 'returns a result with that error' do
      expect(response.success?).to eq(false)
      expect(response.errors).to eq(
        general: [DocAuth::Errors::MULTIPLE_BACK_ID_FAILURES],
        back: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
        hints: true,
      )
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq(nil)
      expect(response.attention_with_barcode?).to eq(true)
    end
  end

  context 'with a yaml file containing barcode attention' do
    let(:input) do
      <<~YAML
        document:
          first_name: Susan
          last_name: null
        failed_alerts:
          - name: 2D Barcode Read
            result: Attention
      YAML
    end

    it 'returns a successful result' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq(
        back: ['fallback_field_level'],
        general: ['barcode_read_check'], hints: true
      )
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc.first_name).to eq('Susan')
      expect(response.pii_from_doc.last_name).to eq(nil)
      expect(response.attention_with_barcode?).to eq(true)
    end
  end

  context 'with a yaml file containing an unknown alert' do
    let(:input) do
      <<~YAML
        failed_alerts:
          - name: Some Made Up Error
      YAML
    end

    it 'calls the warn_notifier' do
      expect(warn_notifier).to receive(:call).with(hash_including(:message, :response_info)).twice

      expect(response.success?).to eq(false)
      expect(response.attention_with_barcode?).to eq(false)
    end
  end

  context 'with a yaml file containing a failed alert' do
    let(:input) do
      <<~YAML
        image_metrics:
          back:
            HorizontalResolution: 2
      YAML
    end

    it 'returns a result with that error' do
      expect(response.success?).to eq(false)
      expect(response.errors).to eq(
        general: [DocAuth::Errors::DPI_LOW_ONE_SIDE],
        back: [DocAuth::Errors::DPI_LOW_FIELD],
        hints: false,
      )
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq(nil)
      expect(response.attention_with_barcode?).to eq(false)
    end
  end

  context 'with a data URI' do
    let(:input) do
      <<~STR
        data:image/gif;base64,R0lGODlhyAAiALM...DfD0QAADs=
      STR
    end

    it 'returns a successful response with the default PII' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc.to_h)
        .to eq(Idp::Constants::MOCK_IDV_APPLICANT)
      expect(response.attention_with_barcode?).to eq(false)
    end
  end

  context 'with URI that is not a data URI' do
    let(:input) do
      <<~STR
        https://example.com
      STR
    end

    it 'returns an error response that explains it should have been a data URI' do
      expect(response.success?).to eq(false)
      expect(response.errors).to eq(general: ['parsed URI, but scheme was https (expected data)'])
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq(nil)
      expect(response.attention_with_barcode?).to eq(false)
    end
  end

  context 'with string data that is not a URI or a hash' do
    let(:input) do
      <<~STR
        something that is definitely not a URI
      STR
    end

    it 'returns an error response that explains it should have been a hash' do
      expect(response.success?).to eq(false)
      expect(response.errors).to eq(general: ['YAML data should have been a hash, got String'])
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq(nil)
      expect(response.attention_with_barcode?).to eq(false)
    end
  end

  context 'with a malformed yaml file' do
    let(:input) do
      # the lack of a space after the "phone" key makes this invalid
      <<~YAML
        document:
          dob: 2000-01-01
          phone:+1 234-567-8901
      YAML
    end

    it 'returns a result with the appopriate error' do
      expect(response.success?).to eq(false)
      expect(response.errors).to eq(general: ['invalid YAML file'])
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq(nil)
      expect(response.attention_with_barcode?).to eq(false)
    end
  end

  context 'with a yaml file containing a passing result' do
    subject(:response) do
      config = DocAuth::Mock::Config.new(
        {
          dpi_threshold: 290,
          sharpness_threshold: 40,
          glare_threshold: 40,
        },
      )
      described_class.new(input, config)
    end

    let(:input) do
      <<~YAML
        document:
          first_name: Susan
          last_name: Smith
          middle_name: Q
          name_suffix:
          address1: 1 Microsoft Way
          address2: Apt 3
          city: Bayside
          state: NY
          zipcode: '11364'
          dob: 10/06/1938
          sex: female
          height: 66
          state_id_number: '123456789'
          id_doc_type: drivers_license
          state_id_jurisdiction: 'NY'
          state_id_expiration: '2089-12-31'
          state_id_issued: '2009-12-31'
          issuing_country_code: 'CA'
      YAML
    end

    it 'returns a passed result' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq(
        Pii::StateId.new(
          first_name: 'Susan',
          middle_name: 'Q',
          last_name: 'Smith',
          name_suffix: nil,
          address1: '1 Microsoft Way',
          address2: 'Apt 3',
          city: 'Bayside',
          state: 'NY',
          state_id_jurisdiction: 'NY',
          state_id_number: '123456789',
          zipcode: '11364',
          dob: '1938-10-06',
          sex: 'female',
          height: 66,
          weight: nil,
          eye_color: nil,
          id_doc_type: 'drivers_license',
          state_id_expiration: '2089-12-31',
          state_id_issued: '2009-12-31',
          issuing_country_code: 'CA',
        ),
      )
      expect(response.attention_with_barcode?).to eq(false)
      expect(response.extra).to eq(
        transaction_status: 'passed',
        doc_auth_result: DocAuth::LexisNexis::ResultCodes::PASSED.name,
        billed: true,
        classification_info: {},
        workflow: 'test_non_liveness_workflow',
        liveness_checking_required: false,
        passport_check_result: {},
        portrait_match_results: nil,
      )
      expect(response.doc_auth_success?).to eq(true)
      expect(response.selfie_status).to eq(:not_processed)
    end
  end

  context 'with a yaml file that does not contain all PII fields' do
    subject(:response) do
      config = DocAuth::Mock::Config.new(
        {
          dpi_threshold: 290,
          sharpness_threshold: 40,
          glare_threshold: 40,
        },
      )
      described_class.new(input, config)
    end

    let(:input) do
      <<~YAML
        document:
          first_name: Susan
      YAML
    end

    it 'returns default values for the missing fields' do
      expect(response.success?).to eq(true)
      expect(response.pii_from_doc).to eq(
        Pii::StateId.new(
          first_name: 'Susan',
          middle_name: nil,
          last_name: 'DEBAK',
          name_suffix: '',
          address1: '514 EAST AVE',
          address2: '',
          city: 'SOUTH CHARLESTON',
          state: 'WV',
          zipcode: '25309-1104',
          dob: '1976-10-18',
          sex: 'female',
          height: 72,
          weight: nil,
          eye_color: nil,
          state_id_number: '1111111111111',
          state_id_jurisdiction: 'ND',
          id_doc_type: 'drivers_license',
          state_id_expiration: '2099-12-31',
          state_id_issued: '2019-12-31',
          issuing_country_code: 'US',
        ),
      )
    end
  end

  context 'with a yaml file containing a read error' do
    let(:input) do
      <<~YAML
        image_metrics:
          back:
            HorizontalResolution: 100
      YAML
    end

    it 'returns caution result' do
      expect(response.success?).to eq(false)
      expect(response.errors).to eq(
        general: [DocAuth::Errors::DPI_LOW_ONE_SIDE],
        back: [DocAuth::Errors::DPI_LOW_FIELD],
        hints: false,
      )
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq(nil)
      expect(response.attention_with_barcode?).to eq(false)
      expect(response.extra).to eq(
        doc_auth_result: DocAuth::LexisNexis::ResultCodes::FAILED.name,
        transaction_status: 'failed',
        billed: true,
        classification_info: nil,
        liveness_checking_required: false,
        workflow: 'test_non_liveness_workflow',
        portrait_match_results: nil,
        alert_failure_count: 1,
        liveness_enabled: false,
        passport_check_result: nil,
        vendor: 'Mock',
        processed_alerts: {
          failed: [{ name: '2D Barcode Read', result: 'Failed' }],
          passed: [],
        },
        image_metrics: {
          back: {
            'GlareMetric' => 100,
            'HorizontalResolution' => 100,
            'SharpnessMetric' => 100,
            'VerticalResolution' => 600,
          },
          front: {
            'GlareMetric' => 100,
            'HorizontalResolution' => 600,
            'SharpnessMetric' => 100,
            'VerticalResolution' => 600,
          },
        },
      )
    end
  end

  context 'with a yaml file containing a failed result' do
    let(:input) do
      <<~YAML
        doc_auth_result: Failed
      YAML
    end

    it 'returns a failed result' do
      expect(response.success?).to eq(false)
      expect(response.errors).to eq(
        general: [DocAuth::Errors::BARCODE_READ_CHECK],
        back: [DocAuth::Errors::FALLBACK_FIELD_LEVEL],
        hints: true,
      )
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq(nil)
      expect(response.attention_with_barcode?).to eq(false)
      expect(response.extra).to eq(
        transaction_status: 'failed',
        doc_auth_result: DocAuth::LexisNexis::ResultCodes::FAILED.name,
        billed: true,
        classification_info: nil,
        liveness_checking_required: false,
        workflow: 'test_non_liveness_workflow',
        portrait_match_results: nil,
        alert_failure_count: 1,
        liveness_enabled: false,
        passport_check_result: nil,
        vendor: 'Mock',
        processed_alerts: {
          failed: [{ name: '2D Barcode Read', result: 'Failed' }],
          passed: [],
        },
        image_metrics: {
          back: {
            'GlareMetric' => 100,
            'HorizontalResolution' => 600,
            'SharpnessMetric' => 100,
            'VerticalResolution' => 600,
          },
          front: {
            'GlareMetric' => 100,
            'HorizontalResolution' => 600,
            'SharpnessMetric' => 100,
            'VerticalResolution' => 600,
          },
        },
      )
    end
  end

  context 'with a yaml file containing integer zipcode' do
    let(:input) do
      <<~YAML
        document:
          first_name: Susan
          last_name: Smith
          middle_name: Q
          name_suffix:
          address1: 1 Microsoft Way
          address2: Apt 3
          city: Bayside
          state: NY
          zipcode: 11364
          dob: 1938-10-06
          sex: female
          height: 66
          state_id_number: '111111111'
          state_id_jurisdiction: ND
          id_doc_type: drivers_license
          state_id_expiration: '2089-12-31'
          state_id_issued: '2009-12-31'
          issuing_country_code: 'CA'
      YAML
    end

    it 'returns a result with string zipcode' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq(
        Pii::StateId.new(
          first_name: 'Susan',
          middle_name: 'Q',
          last_name: 'Smith',
          name_suffix: nil,
          address1: '1 Microsoft Way',
          address2: 'Apt 3',
          city: 'Bayside',
          state: 'NY',
          zipcode: '11364',
          dob: '1938-10-06',
          sex: 'female',
          height: 66,
          weight: nil,
          eye_color: nil,
          state_id_number: '111111111',
          state_id_jurisdiction: 'ND',
          id_doc_type: 'drivers_license',
          state_id_expiration: '2089-12-31',
          state_id_issued: '2009-12-31',
          issuing_country_code: 'CA',
        ),
      )
      expect(response.attention_with_barcode?).to eq(false)
      expect(response.extra).to eq(
        transaction_status: 'passed',
        doc_auth_result: DocAuth::LexisNexis::ResultCodes::PASSED.name,
        billed: true,
        classification_info: {},
        liveness_checking_required: false,
        workflow: 'test_non_liveness_workflow',
        passport_check_result: {},
        portrait_match_results: nil,
      )
    end
  end
  context 'with a yaml file missing classification info' do
    let(:input) do
      <<~YAML
        doc_auth_result: Failed
      YAML
    end
    it 'returns doc type as supported' do
      expect(response.doc_type_supported?).to eq(true)
    end
  end
  context 'with a yaml file containing classification info and known unsupported doc type' do
    let(:input) do
      <<~YAML
        doc_auth_result: Failed
        classification_info:
          Front:
            ClassName: Tribal Identification
      YAML
    end
    it 'returns doc type as not supported' do
      expect(response.doc_type_supported?).to eq(false)
    end
  end
  context 'with a yaml file containing classification info and known supported doc type' do
    let(:input) do
      <<~YAML
        doc_auth_result: Failed
        classification_info:
          Front:
            ClassName: Identification Card
      YAML
    end
    it 'returns doc type as supported' do
      expect(response.doc_type_supported?).to eq(true)
    end
  end
  context 'with a yaml file containing classification info and unknown doc type' do
    let(:input) do
      <<~YAML
        doc_auth_result: Failed
        classification_info:
          Front:
            ClassName: Unknown
      YAML
    end
    it 'returns doc type as supported' do
      expect(response.doc_type_supported?).to eq(true)
    end
  end
  context 'with a yaml file with supported side and unknown side' do
    let(:input) do
      <<~YAML
        doc_auth_result: Failed
        classification_info:
          Front:
            ClassName: Drivers License
          Back:
            ClassName: Unknown
      YAML
    end
    it 'returns doc type as supported' do
      expect(response.doc_type_supported?).to eq(true)
    end
  end
  context 'with a yaml file with both supported and and unknown doc type' do
    let(:input) do
      <<~YAML
        doc_auth_result: Failed
        classification_info:
          Front:
            ClassName: Drivers License
          Back:
            ClassName: Military Identification
      YAML
    end
    it 'returns doc type as not supported' do
      expect(response.doc_type_supported?).to eq(false)
    end
  end
  context 'with a yaml file with a supported classname and country' do
    let(:input) do
      <<~YAML
        doc_auth_result: Failed
        classification_info:
          Front:
            ClassName: Drivers License
            CountryCode: US
          Back:
            ClassName: Drivers License
            CountryCode: US
      YAML
    end
    it 'returns doc type as supported' do
      expect(response.doc_type_supported?).to eq(true)
    end
  end
  context 'with a yaml file with a supported classname and not supported country' do
    let(:input) do
      <<~YAML
        doc_auth_result: Failed
        classification_info:
          Front:
            ClassName: Drivers License
            CountryCode: UK
          Back:
            ClassName: Drivers License
            CountryCode: UK
      YAML
    end
    it 'returns doc type as not supported' do
      expect(response.doc_type_supported?).to eq(false)
      expect(response.errors).to eq(
        general: [DocAuth::Errors::DOC_TYPE_CHECK],
        front: [DocAuth::Errors::CARD_TYPE],
        back: [DocAuth::Errors::CARD_TYPE],
        hints: true,
      )
    end
  end

  context 'with a passed yaml file containing unsupported doc type and bad image metrics' do
    let(:input) do
      <<~YAML
        doc_auth_result: Passed
        classification_info:
          Front:
            ClassName: Identification Card
            CountryCode: USA
            IssuerType: Forgery
          Back:
            ClassName: Identification Card
            CountryCode: USA
            IssuerType: StateProvince
        image_metrics:
          front:
            HorizontalResolution: 50
            VerticalResolution: 300
            SharpnessMetric: 50
            GlareMetric: 50
          back:
            HorizontalResolution: 300
            VerticalResolution: 300,
            SharpnessMetric: 50,
            GlareMetric: 50
      YAML
    end
    it 'returns doc type as not supported and generate errors for doc type' do
      expect(response.doc_type_supported?).to eq(false)
      expect(response.errors).to eq(
        general: [DocAuth::Errors::DOC_TYPE_CHECK],
        front: [DocAuth::Errors::CARD_TYPE],
        hints: true,
      )
      expect(response.exception).to be_nil
      expect(response.success?).to eq(false)
    end
  end

  context 'with a yaml file that does not include classification info' do
    let(:input) do
      <<~YAML
        document:
          first_name: Jane
          last_name: Doe
          middle_name: Q
          city: Bayside
          state: NY
          zipcode: '11364'
          dob: 10/06/1938
          phone: +1 314-555-1212
          state_id_jurisdiction: 'ND'
      YAML
    end
    it 'successfully extracts PII' do
      expect(response.pii_from_doc).to_not be_blank
    end
  end
  context 'with a yaml file that includes classification info' do
    let(:input) do
      <<~YAML
        document:
          first_name: Jane
          last_name: Doe
          middle_name: Q
          city: Bayside
          state: NY
          zipcode: '11364'
          dob: 10/06/1938
          phone: +1 314-555-1212
          state_id_jurisdiction: 'ND'
        classification_info:
          Front:
            ClassName: Drivers License
            CountryCode: USA
          Back:
            ClassName: Drivers License
            CountryCode: USA
      YAML
    end
    it 'successfully extracts classification info' do
      classification_info = response.extra[:classification_info].deep_symbolize_keys
      expect(classification_info).to eq(
        {
          Front: { ClassName: 'Drivers License',
                   CountryCode: 'USA' },
          Back: { ClassName: 'Drivers License', CountryCode: 'USA' },
        },
      )
    end
  end
  context 'with a yaml file that includes classification info but missing pii' do
    let(:input) do
      <<~YAML
        transaction_status: passed
        doc_auth_result: Passed
        document:
          city: Bayside
          state: NY
          zipcode: '11364'
          dob: 10/06/1938
          phone: +1 314-555-1212
          state_id_jurisdiction: 'ND'
        failed_alerts: []
        classification_info:
          Front:
            ClassName: Drivers License
            CountryCode: USA
          Back:
            ClassName: Drivers License
            CountryCode: USA
      YAML
    end
    it 'successfully extracts classification info' do
      classification_info = response.extra[:classification_info].deep_symbolize_keys
      expect(classification_info).to eq(
        {
          Front: { ClassName: 'Drivers License',
                   CountryCode: 'USA' },
          Back: { ClassName: 'Drivers License', CountryCode: 'USA' },
        },
      )
    end
  end

  context 'when a selfie check is performed' do
    describe 'and it is successful' do
      let(:input) do
        <<~YAML
          transaction_status: passed
          portrait_match_results:
            FaceMatchResult: Pass
            FaceErrorMessage: 'Successful. Liveness: Live'
          doc_auth_result: Passed
          failed_alerts: []
        YAML
      end
      let(:selfie_required) { true }

      it 'returns the expected values' do
        selfie_results = {
          FaceMatchResult: 'Pass',
          FaceErrorMessage: 'Successful. Liveness: Live',
        }

        expect(response.selfie_check_performed?).to eq(true)
        expect(response.success?).to eq(true)
        expect(response.extra[:portrait_match_results]).to eq(selfie_results)
        expect(response.doc_auth_success?).to eq(true)
        expect(response.selfie_status).to eq(:success)
      end
    end

    # TODO update this test, looks like the same problem as in error_generator_spec.rb
    describe 'and it is not successful' do
      let(:input) do
        <<~YAML
          portrait_match_results:
            FaceMatchResult: Fail
            FaceErrorMessage: 'Successful. Liveness: Live'
          doc_auth_result: Passed
          failed_alerts: []
        YAML
      end
      let(:selfie_required) { true }

      it 'returns the expected values' do
        selfie_results = {
          FaceMatchResult: 'Fail',
          FaceErrorMessage: 'Successful. Liveness: Live',
        }

        expect(response.selfie_check_performed?).to eq(true)
        expect(response.success?).to eq(false)
        expect(response.extra[:portrait_match_results]).to eq(selfie_results)
        expect(response.doc_auth_success?).to eq(true)
        expect(response.selfie_status).to eq(:fail)
        expect(response.extra[:liveness_checking_required]).to eq(true)
      end
    end
  end

  context 'when a selfie check is not performed' do
    let(:input) { DocAuthImageFixtures.document_front_image }
    let(:selfie_required) { false }

    it 'returns the expected values' do
      expect(response.selfie_check_performed?).to eq(false)
      expect(response.extra[:portrait_match_results]).to be_nil
      expect(response.doc_auth_success?).to eq(true)
      expect(response.selfie_status).to eq(:not_processed)
      expect(response.extra[:liveness_checking_required]).to eq(false)
    end
  end
end
