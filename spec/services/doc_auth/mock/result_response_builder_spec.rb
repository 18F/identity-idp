require 'rails_helper'

describe DocAuth::Mock::ResultResponseBuilder do
  describe '#call' do
    context 'with an image file' do
      it 'returns a successful response with the default PII' do
        builder = described_class.new(DocAuthImageFixtures.document_front_image)

        response = builder.call

        expect(response.success?).to eq(true)
        expect(response.errors).to eq({})
        expect(response.exception).to eq(nil)
        expect(response.pii_from_doc).to eq(
          first_name: 'FAKEY',
          middle_name: nil,
          last_name: 'MCFAKERSON',
          address1: '1 FAKE RD',
          address2: nil,
          city: 'GREAT FALLS',
          state: 'MT',
          zipcode: '59010',
          dob: '10/06/1938',
          state_id_number: '1111111111111',
          state_id_jurisdiction: 'ND',
          state_id_type: 'drivers_license',
          phone: nil,
        )
      end
    end

    context 'with a yaml file containing PII' do
      let(:successful_result_yaml) do
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
        builder = described_class.new(successful_result_yaml)

        response = builder.call

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
          dob: '10/06/1938',
          state_id_number: '111111111',
          state_id_jurisdiction: 'ND',
          state_id_type: 'drivers_license',
        )
      end
    end

    context 'with a yaml file containing an error' do
      let(:error_result_yaml) do
        <<~YAML
          friendly_error: This is a test error
        YAML
      end

      it 'returns a result with that error' do
        builder = described_class.new(error_result_yaml)

        response = builder.call

        expect(response.success?).to eq(false)
        expect(response.errors).to eq(results: ['This is a test error'])
        expect(response.exception).to eq(nil)
        expect(response.pii_from_doc).to eq({})
      end
    end
  end
end
