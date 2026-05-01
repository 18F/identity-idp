require 'rails_helper'

RSpec.describe Mattr::ResponseParser do
  let(:credential) do
    {
      'docType' => 'org.iso.18013.5.1.mDL',
      'verificationResult' => { 'verified' => true },
      'claims' => {
        'org.iso.18013.5.1' => {
          'given_name' => { 'value' => 'Fakey' },
          'family_name' => { 'value' => 'McFakerson' },
          'birth_date' => { 'value' => '1938-10-06' },
          'resident_address' => { 'value' => '1 Fake Rd' },
          'resident_city' => { 'value' => 'Great Falls' },
          'resident_state' => { 'value' => 'MT' },
          'resident_postal_code' => { 'value' => '59010-1234' },
          'document_number' => { 'value' => 'D123456' },
          'expiry_date' => { 'value' => '2099-12-31' },
          'issue_date' => { 'value' => '2019-12-31' },
          'issuing_authority' => { 'value' => 'ND' },
        },
      },
    }
  end

  subject(:parser) { described_class.new(credential) }

  describe '#parse' do
    context 'with a valid verified credential' do
      it 'parses successfully' do
        expect(parser.parse).to be true
        expect(parser.success?).to be true
        expect(parser.errors).to be_empty
      end
    end

    context 'when verificationResult.verified is false' do
      before { credential['verificationResult'] = { 'verified' => false } }

      it 'returns false and reports the failure' do
        expect(parser.parse).to be false
        expect(parser.errors).to include('credential not verified')
      end
    end

    context 'when verificationResult is missing' do
      before { credential.delete('verificationResult') }

      it 'returns false' do
        expect(parser.parse).to be false
      end
    end

    context 'when the credential is nil' do
      subject(:parser) { described_class.new(nil) }

      it 'returns false' do
        expect(parser.parse).to be false
      end
    end

    context 'when claims for the mDL namespace are empty' do
      before { credential['claims'] = { 'org.iso.18013.5.1' => {} } }

      it 'returns false with no pii' do
        expect(parser.parse).to be false
        expect(parser.errors).to include('no mdl claims in response')
      end
    end
  end

  describe '#to_pii' do
    before { parser.parse }

    it 'maps mDoc claims to Pii::StateId' do
      pii = parser.to_pii

      expect(pii).to be_a(Pii::StateId)
      expect(pii.first_name).to eq('FAKEY')
      expect(pii.last_name).to eq('MCFAKERSON')
      expect(pii.dob).to eq('1938-10-06')
      expect(pii.address1).to eq('1 FAKE RD')
      expect(pii.city).to eq('GREAT FALLS')
      expect(pii.state).to eq('MT')
      expect(pii.zipcode).to eq('59010')
      expect(pii.state_id_number).to eq('D123456')
      expect(pii.state_id_expiration).to eq('2099-12-31')
      expect(pii.state_id_issued).to eq('2019-12-31')
      expect(pii.state_id_jurisdiction).to eq('ND')
      expect(pii.document_type_received).to eq('drivers_license')
      expect(pii.issuing_country_code).to eq('US')
    end

    it 'leaves unmapped fields nil' do
      pii = parser.to_pii

      expect(pii.middle_name).to be_nil
      expect(pii.name_suffix).to be_nil
      expect(pii.address2).to be_nil
      expect(pii.sex).to be_nil
      expect(pii.height).to be_nil
      expect(pii.weight).to be_nil
      expect(pii.eye_color).to be_nil
    end
  end
end
