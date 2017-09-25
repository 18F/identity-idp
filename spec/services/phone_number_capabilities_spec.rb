require 'rails_helper'

describe PhoneNumberCapabilities do
  let(:phone) { '+1 (555) 555-5000' }
  subject { PhoneNumberCapabilities.new(phone) }

  describe '#sms_only?' do
    context 'voice is supported' do
      it { expect(subject.sms_only?).to eq(false) }
    end

    context 'voice is not supported for the area code' do
      let(:phone) { '+1 (671) 555-5000' }
      it { expect(subject.sms_only?).to eq(true) }
    end

    context 'voice is supported for the international code' do
      let(:phone) { '+55 (555) 555-5000' }
      # pending while international voice is disabled for all international codes
      xit { expect(subject.sms_only?).to eq(false) }
    end

    context 'voice is not supported for the international code' do
      let(:phone) { '+212 1234 12345' }
      it { expect(subject.sms_only?).to eq(true) }
    end
  end

  describe '#unsupported_location' do
    it 'returns the name of the unsupported area code location' do
      locality = PhoneNumberCapabilities.new('+1 (671) 555-5000').unsupported_location
      expect(locality).to eq('Guam')
    end

    it 'returns the name of the unsupported international code location' do
      locality = PhoneNumberCapabilities.new('+212 1234 12345').unsupported_location
      expect(locality).to eq('Morocco')
    end
  end
end
