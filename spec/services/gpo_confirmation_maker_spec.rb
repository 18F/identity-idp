require 'rails_helper'

RSpec.describe GpoConfirmationMaker do
  let(:otp) { '123ABC' }
  let(:issuer) { 'this-is-an-issuer' }
  let(:service_provider) { build(:service_provider, issuer: issuer) }
  let(:zipcode) { '12345' }
  let(:decrypted_attributes) do
    {
      address1: '123 main st',
      address2: '',
      city: 'Baton Rouge',
      state: 'Louisiana',
      zipcode: zipcode,
      first_name: 'Robert',
      last_name: 'Robertson',
      otp: otp,
      issuer: issuer,
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

  [
    [nil, false],
    ['1234', false],
    ['12345+0', '12345'],
    ['12345 - 0', '12345'],
    ['12345- 0', '12345'],
    ['12345-0', '12345'],
    ['12345-6', '12345'],
    ['12345-67', '12345'],
    ['12345-678', '12345'],
    ['12345-6789', '12345-6789'],
  ].each do |input, expected|
    context "when zipcode = #{input.inspect}" do
      let(:zipcode) { input }
      describe '#perform' do
        if expected
          it 'accepts the zipcode' do
            expect { subject.perform }.not_to raise_error
          end
        else
          it 'raises an error' do
            expect { subject.perform }.to raise_error(GpoConfirmationMaker::InvalidEntryError)
          end
        end

        if expected.is_a?(String)
          it "formats the zipcode as #{expected.inspect}" do
            subject.perform
            gpo_confirmation = GpoConfirmation.first
            entry_hash = gpo_confirmation.entry
            expect(entry_hash[:zipcode]).to eq expected
          end
        end
      end
    end
  end
end
