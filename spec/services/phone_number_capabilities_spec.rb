require 'rails_helper'

describe PhoneNumberCapabilities do
  let(:phone) { '+1 (555) 555-5000' }
  subject { PhoneNumberCapabilities.new(phone) }

  describe '#sms_only?' do
    context 'voice is supported' do
      it { expect(subject.sms_only?).to eq(false) }
    end

    context 'voice is not supported for the area code' do
      let(:phone) { '+1 (242) 555-5000' }
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
      locality = PhoneNumberCapabilities.new('+1 (242) 555-5000').unsupported_location
      expect(locality).to eq('Bahamas')
    end

    it 'returns the name of the unsupported international code location' do
      locality = PhoneNumberCapabilities.new('+355 1234 12345').unsupported_location
      expect(locality).to eq('Albania')
    end
  end

  describe 'list of unsupported area codes' do
    it 'is up to date' do
      unsupported_area_codes = {
        '264' => 'Anguilla',
        '268' => 'Antigua and Barbuda',
        '242' => 'Bahamas',
        '246' => 'Barbados',
        '441' => 'Bermuda',
        '284' => 'British Virgin Islands',
        '345' => 'Cayman Islands',
        '767' => 'Dominica',
        '809' => 'Dominican Republic',
        '829' => 'Dominican Republic',
        '849' => 'Dominican Republic',
        '473' => 'Grenada',
        '876' => 'Jamaica',
        '664' => 'Montserrat',
        '869' => 'Saint Kitts and Nevis',
        '758' => 'Saint Lucia',
        '784' => 'Saint Vincent Grenadines',
        '868' => 'Trinidad and Tobago',
        '649' => 'Turks and Caicos Islands',
      }
      expect(PhoneNumberCapabilities::VOICE_UNSUPPORTED_US_AREA_CODES).to eq unsupported_area_codes
    end
  end
end
