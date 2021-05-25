require 'rails_helper'

describe PhoneNumberCapabilities do
  let(:phone) { '+1 (703) 555-5000' }
  let(:confirmed) { false }
  subject(:capabilities) { PhoneNumberCapabilities.new(phone, confirmed) }

  describe '#sms_only?' do
    context 'voice is supported' do
      it { expect(subject.sms_only?).to eq(false) }
    end

    context 'Bahamas number' do
      let(:phone) { '+1 (242) 327-0143' }
      it { expect(subject.sms_only?).to eq(true) }
    end

    context 'Bermuda number' do
      let(:phone) { '+1 (441) 295-9644' }
      it { expect(subject.sms_only?).to eq(true) }
    end

    context 'Morocco number' do
      let(:phone) { '+212 661-289325' }
      it { expect(subject.sms_only?).to eq(true) }
    end

    context "phonelib returns nil or a 2-letter country code that doesn't match our YAML" do
      let(:phone) { '703-555-1212' }
      it { expect(subject.sms_only?).to eq(false) }
    end
  end

  describe '#supports_sms?' do
    subject(:supports_sms?) { capabilities.supports_sms? }

    context 'US number' do
      let(:phone) { '+1 (703) 555-5000' }
      it { is_expected.to eq(true) }
    end

    context 'Bermuda number' do
      let(:phone) { '+1 (441) 295-9644' }
      it { is_expected.to eq(true) }
    end
  end

  describe '#supports_voice?' do
    subject(:supports_sms?) { capabilities.supports_voice? }

    context 'US number' do
      let(:phone) { '+1 (703) 555-5000' }
      it { is_expected.to eq(true) }
    end

    context 'Bermuda number' do
      let(:phone) { '+1 (441) 295-9644' }
      it { is_expected.to eq(false) }
    end

    context 'Philippines number that is confirmed' do
      let(:confirmed) { true }
      let(:phone) { '+63 (703) 555-5000' }
      it { is_expected.to eq(true) }
    end

    context 'Philippines number that is unconfirmed' do
      let(:confirmed) { false }
      let(:phone) { '+63 (703) 555-5000' }
      it { is_expected.to eq(false) }
    end
  end

  describe '#unsupported_location' do
    it 'returns the name of the unsupported country (Bahamas)' do
      locality = PhoneNumberCapabilities.new('+1 (242) 327-0143', false).unsupported_location
      expect(locality).to eq('Bahamas')
    end

    it 'returns the name of the unsupported country (Bermuda)' do
      locality = PhoneNumberCapabilities.new('+1 (441) 295-9644', false).unsupported_location
      expect(locality).to eq('Bermuda')
    end

    context 'phonelib returns default country' do
      it 'returns the default country' do
        locality = PhoneNumberCapabilities.new('703-555-1212', false).unsupported_location
        expect(locality).to eq('United States')
      end
    end
  end

  it 'has valid configuration' do
    # we should never have supports_voice as false and supports_voice_unconfirmed as true

    PhoneNumberCapabilities::INTERNATIONAL_CODES.each do |country, support|
      expect(support['supports_voice']).to eq true if support['supports_voice_unconfirmed']
    end
  end
end
