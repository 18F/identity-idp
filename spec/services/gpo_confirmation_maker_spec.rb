require 'rails_helper'

describe GpoConfirmationMaker do
  context "happy path" do
    let(:otp) { '123ABC' }
    let(:issuer) { 'this-is-an-issuer' }
    let(:service_provider) { build(:service_provider, issuer: issuer) }
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

    subject { described_class.new(pii: pii, service_provider: service_provider, profile: profile) }

    describe '#perform' do
      before do
        allow(Base32::Crockford).to receive(:encode).and_return(otp)
      end

      it 'should create a GpoConfirmation with the encrypted attributes' do
        expect { subject.perform }.to change { GpoConfirmation.count }.from(0).to(1)

        gpo_confirmation = GpoConfirmation.first
        entry_hash = gpo_confirmation.entry
        expect(entry_hash).to eq decrypted_attributes
      end

      it 'should create a GpoConfirmationCode with the profile and the encrypted OTP' do
        expect { subject.perform }.to change { GpoConfirmationCode.count }.from(0).to(1)

        gpo_confirmation_code = GpoConfirmationCode.first

        expect(gpo_confirmation_code.profile).to eq profile
        expect(gpo_confirmation_code.otp_fingerprint).to eq Pii::Fingerprinter.fingerprint(otp)
      end
    end

    describe '#otp' do
      it 'should return a normalized, 10 digit code' do
        otp = subject.otp

        expect(otp.length).to eq 10
        expect(Base32::Crockford.normalize(otp)).to eq otp
      end

      it 'filters out profane words' do
        profane = Base32::Crockford.decode('FART')
        not_profane = Base32::Crockford.decode('ABCD')

        expect(SecureRandom).to receive(:random_number).
          and_return(profane, not_profane)

        expect(subject.otp).to eq('000000ABCD')
      end
    end
  end

  context "with a (bogus) zip+1" do
    let(:otp) { '123ABC' }
    let(:issuer) { 'this-is-an-issuer' }
    let(:service_provider) { build(:service_provider, issuer: issuer) }
    let(:decrypted_attributes) do
      {
        address1: '123 main st', address2: '',
        city: 'Baton Rouge', state: 'Louisiana', zipcode: '12345+0',
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

    subject { described_class.new(pii: pii, service_provider: service_provider, profile: profile) }

    describe '#perform' do
      before do
        allow(Base32::Crockford).to receive(:encode).and_return(otp)
      end

      it 'strips the +0 from the zipcode' do
        expect { subject.perform }.to change { GpoConfirmation.count }.from(0).to(1)

        gpo_confirmation = GpoConfirmation.first
        entry_hash = gpo_confirmation.entry
        expect(entry_hash[:zipcode]).to eq "12345"
      end
    end
  end
end
