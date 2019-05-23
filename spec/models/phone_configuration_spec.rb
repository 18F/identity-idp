require 'rails_helper'

describe PhoneConfiguration do
  describe 'Associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to validate_presence_of(:user_id) }
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

  describe '#decorate' do
    it 'returns a PhoneConfigurationDecorator' do
      phone_configuration = build(:phone_configuration)

      expect(phone_configuration.decorate).to be_a(PhoneConfigurationDecorator)
    end
  end
end
