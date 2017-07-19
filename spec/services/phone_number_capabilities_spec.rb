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
  end

  describe '#unsupported_location' do
    it 'returns the name of the unsupported locality' do
      locality = PhoneNumberCapabilities.new('+1 (671) 555-5000').unsupported_location
      expect(locality).to eq('Guam')
    end
  end
end
