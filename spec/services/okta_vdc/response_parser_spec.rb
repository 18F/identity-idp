require 'rails_helper'

RSpec.describe OktaVdc::ResponseParser do
  describe '#parse' do
    context 'with valid mDL claims' do
      let(:raw_claims) do
        {
          'org.iso.18013.5.1' => {
            'given_name' => 'Fakey',
            'family_name' => 'McFakerson',
            'birth_date' => '1938-10-06',
            'resident_address' => '1 Fake Rd',
            'resident_city' => 'Great Falls',
            'resident_state' => 'MT',
            'resident_postal_code' => '59010-1234',
            'expiry_date' => '2099-12-31',
            'issue_date' => '2019-12-31',
            'issuing_authority' => 'ND',
          },
        }
      end

      subject(:parser) { described_class.new(raw_claims) }

      it 'parses successfully' do
        expect(parser.parse).to be true
        expect(parser.success?).to be true
        expect(parser.errors).to be_empty
      end

      it 'maps claims to Pii::StateId' do
        parser.parse
        pii = parser.to_pii

        expect(pii).to be_a(Pii::StateId)
        expect(pii.first_name).to eq('FAKEY')
        expect(pii.last_name).to eq('MCFAKERSON')
        expect(pii.dob).to eq('1938-10-06')
        expect(pii.address1).to eq('1 FAKE RD')
        expect(pii.city).to eq('GREAT FALLS')
        expect(pii.state).to eq('MT')
        expect(pii.zipcode).to eq('59010')
        expect(pii.state_id_expiration).to eq('2099-12-31')
        expect(pii.state_id_issued).to eq('2019-12-31')
        expect(pii.state_id_jurisdiction).to eq('ND')
        expect(pii.document_type_received).to eq('drivers_license')
        expect(pii.issuing_country_code).to eq('US')
      end
    end

    context 'with empty claims' do
      subject(:parser) { described_class.new({}) }

      it 'returns false and sets errors' do
        expect(parser.parse).to be false
        expect(parser.errors).to include('no mdl claims in response')
      end
    end

    context 'with nil claims' do
      subject(:parser) { described_class.new(nil) }

      it 'returns false' do
        expect(parser.parse).to be false
      end
    end
  end
end
