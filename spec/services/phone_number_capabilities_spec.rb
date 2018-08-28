require 'rails_helper'

describe PhoneNumberCapabilities do
  let(:phone) { '+1 (703) 555-5000' }
  subject { PhoneNumberCapabilities.new(phone) }

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

    context 'voice is supported for the international code' do
      let(:phone) { '+55 (555) 555-5000' }
      # pending while international voice is disabled for all international codes
      xit { expect(subject.sms_only?).to eq(false) }
    end

    context 'Morocco number' do
      let(:phone) { '+212 661-289325' }
      it { expect(subject.sms_only?).to eq(true) }
    end

    context "phonelib returns nil or a 2-letter country code that doesn't match our YAML" do
      let(:phone) { '703-555-1212' }
      it { expect(subject.sms_only?).to eq(true) }
    end
  end

  describe '#unsupported_location' do
    it 'returns the name of the unsupported country (Bahamas)' do
      locality = PhoneNumberCapabilities.new('+1 (242) 327-0143').unsupported_location
      expect(locality).to eq('Bahamas')
    end

    it 'returns the name of the unsupported country (Bermuda)' do
      locality = PhoneNumberCapabilities.new('+1 (441) 295-9644').unsupported_location
      expect(locality).to eq('Bermuda')
    end

    context 'phonelib returns nil' do
      it 'returns nil' do
        locality = PhoneNumberCapabilities.new('703-555-1212').unsupported_location
        expect(locality).to be_nil
      end
    end
  end
end
