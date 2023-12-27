require 'rails_helper'

RSpec.describe DocAuth::Mock::ResultResponse do
  let(:warn_notifier) { instance_double('Proc') }
  let(:selfie_check_performed) { false }

  subject(:response) do
    config = DocAuth::Mock::Config.new(
      dpi_threshold: 290,
      sharpness_threshold: 40,
      glare_threshold: 40,
      warn_notifier: warn_notifier,
    )
    described_class.new(input, selfie_check_performed, config)
  end

  context 'with an image file' do
    let(:input) { DocAuthImageFixtures.document_front_image }

    it 'returns a successful response with the default PII' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).
        to eq(Idp::Constants::MOCK_IDV_APPLICANT)
      expect(response.attention_with_barcode?).to eq(false)
    end
  end

  context 'with a yaml file containing PII' do
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
          dob: 1938-10-06
          state_id_number: '111111111'
          state_id_jurisdiction: ND
          state_id_type: drivers_license
      YAML
    end

    it 'returns a result with that PII' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq(
        first_name: 'Susan',
        middle_name: 'Q',
        last_name: 'Smith',
        address1: '1 Microsoft Way',
        address2: 'Apt 3',
        city: 'Bayside',
        state: 'NY',
        zipcode: '11364',
        dob: '1938-10-06',
        state_id_number: '111111111',
        state_id_jurisdiction: 'ND',
        state_id_type: 'drivers_license',
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
          state_id_type: drivers_license
      YAML
    end

    it 'returns a result with that PII' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to include(dob: '1938-10-06')
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
      expect(response.pii_from_doc).to eq({})
      expect(response.attention_with_barcode?).to eq(false)
    end
  end

  context 'with a yaml file containing barcode attention' do
    let(:input) do
      <<~YAML
        document:
          first_name: Susan
        failed_alerts:
          - name: 2D Barcode Read
            result: Attention
      YAML
    end

    it 'returns a successful result' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq({ first_name: 'Susan' })
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
      expect(response.pii_from_doc).to eq({})
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
      expect(response.pii_from_doc).
        to eq(Idp::Constants::MOCK_IDV_APPLICANT)
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
      expect(response.pii_from_doc).to eq({})
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
      expect(response.pii_from_doc).to eq({})
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
      expect(response.pii_from_doc).to eq({})
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
      described_class.new(input, selfie_check_performed, config)
    end

    let(:input) do
      <<~YAML
        document:
          type: license
          first_name: Susan
          last_name: Smith
          middle_name: Q
          address1: 1 Microsoft Way
          address2: Apt 3
          city: Bayside
          state: NY
          zipcode: '11364'
          dob: 10/06/1938
          phone: +1 314-555-1212
          state_id_number: '123456789'
          state_id_type: drivers_license
          state_id_jurisdiction: 'NY'
      YAML
    end

    it 'returns a passed result' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq(
        first_name: 'Susan',
        middle_name: 'Q',
        last_name: 'Smith',
        phone: '+1 314-555-1212',
        address1: '1 Microsoft Way',
        address2: 'Apt 3',
        city: 'Bayside',
        state: 'NY',
        state_id_jurisdiction: 'NY',
        state_id_number: '123456789',
        zipcode: '11364',
        dob: '1938-10-06',
        state_id_type: 'drivers_license',
        type: 'license',
      )
      expect(response.attention_with_barcode?).to eq(false)
      expect(response.extra).to eq(
        doc_auth_result: DocAuth::Acuant::ResultCodes::PASSED.name,
        billed: true,
        classification_info: {},
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
      expect(response.pii_from_doc).to eq({})
      expect(response.attention_with_barcode?).to eq(false)
      expect(response.extra).to eq(
        doc_auth_result: DocAuth::Acuant::ResultCodes::CAUTION.name,
        billed: true,
        classification_info: {},
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
      expect(response.pii_from_doc).to eq({})
      expect(response.attention_with_barcode?).to eq(false)
      expect(response.extra).to eq(
        doc_auth_result: DocAuth::Acuant::ResultCodes::FAILED.name,
        billed: true,
        classification_info: {},
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
          address1: 1 Microsoft Way
          address2: Apt 3
          city: Bayside
          state: NY
          zipcode: 11364
          dob: 1938-10-06
          state_id_number: '111111111'
          state_id_jurisdiction: ND
          state_id_type: drivers_license
      YAML
    end

    it 'returns a result with string zipcode' do
      expect(response.success?).to eq(true)
      expect(response.errors).to eq({})
      expect(response.exception).to eq(nil)
      expect(response.pii_from_doc).to eq(
        first_name: 'Susan',
        middle_name: 'Q',
        last_name: 'Smith',
        address1: '1 Microsoft Way',
        address2: 'Apt 3',
        city: 'Bayside',
        state: 'NY',
        zipcode: '11364',
        dob: '1938-10-06',
        state_id_number: '111111111',
        state_id_jurisdiction: 'ND',
        state_id_type: 'drivers_license',
      )
      expect(response.attention_with_barcode?).to eq(false)
      expect(response.extra).to eq(
        doc_auth_result: DocAuth::Acuant::ResultCodes::PASSED.name,
        billed: true,
        classification_info: {},
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
            IssuerType: Country
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
      expect(response.pii_from_doc.empty?).to eq(false)
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
    let(:input) { DocAuthImageFixtures.document_front_image }
    let(:selfie_check_performed) { true }

    it { expect(response.selfie_check_performed?).to eq(true) }
  end

  context 'when a selfie check is not performed' do
    let(:input) { DocAuthImageFixtures.document_front_image }
    let(:selfie_check_performed) { false }

    it { expect(response.selfie_check_performed?).to eq(false) }
  end
end
