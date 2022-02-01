require 'rails_helper'

describe PhoneConfiguration do
  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:encrypted_phone) }
  end

  let(:phone) { '+1 703 555 1212' }

  let(:phone_configuration) { create(:phone_configuration, phone: phone) }

  describe 'creation' do
    it 'stores an encrypted form of the phone number' do
      expect(phone_configuration.encrypted_phone).to_not be_blank
    end
  end

  describe 'encrypted attributes' do
    it 'decrypts phone' do
      expect(phone_configuration.phone).to eq phone
    end

    context 'with unnormalized phone' do
      let(:phone) { '  555 555 5555     ' }
      let(:normalized_phone) { '555 555 5555' }

      it 'normalizes phone' do
        expect(phone_configuration.phone).to eq normalized_phone
      end
    end
  end

  describe '#masked_phone' do
    it 'is the masked phone number' do
      expect(phone_configuration.masked_phone).to eq('***-***-1212')
    end

    context 'with a blank phone' do
      let(:phone) { '   ' }
      let(:phone_configuration) { build(:phone_configuration, phone: phone) }

      it 'is the empty string' do
        expect(phone_configuration.masked_phone).to eq('')
      end
    end
  end
end
