require 'rails_helper'

describe UspsConfirmationMaker do
  let(:otp) { '123ABC' }
  let(:issuer) { 'this-is-an-issuer' }
  let(:decrypted_attributes) do
    {
      address1: '123 main st', address2: '',
      city: 'Baton Rouge', state: 'Louisiana', zipcode: '12345',
      first_name: 'Robert', last_name: 'Robertson',
      otp: otp, issuer: issuer
    }
  end
  let(:pii) do
    attributes = Pii::Attributes.new
    decrypted_attributes.each do |key, value|
      next unless attributes.respond_to? key
      attributes[key] = value
    end
    attributes
  end
  let(:profile) { create(:profile) }

  subject { described_class.new(pii: pii, issuer: issuer, profile: profile) }

  describe '#perform' do
    before do
      allow(Base32::Crockford).to receive(:encode).and_return(otp)
    end

    it 'should create a UspsConfirmation with the encrypted attributes' do
      expect { subject.perform }.to change { UspsConfirmation.count }.from(0).to(1)

      usps_confirmation = UspsConfirmation.first
      expect(usps_confirmation.decrypted_entry.to_h).to eq decrypted_attributes
    end

    it 'should create a UspsConfrimationCode with the profile and the encrypted OTP' do
      expect { subject.perform }.to change { UspsConfirmationCode.count }.from(0).to(1)

      usps_confirmation_code = UspsConfirmationCode.first

      expect(usps_confirmation_code.profile).to eq profile
      expect(usps_confirmation_code.otp_fingerprint).to eq Pii::Fingerprinter.fingerprint(otp)
    end
  end

  describe '#otp' do
    it 'should return a normalized, 10 digit code' do
      otp = subject.otp

      expect(otp.length).to eq 10
      expect(Base32::Crockford.normalize(otp)).to eq otp
    end
  end
end
