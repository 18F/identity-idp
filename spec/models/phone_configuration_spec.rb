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
    it 'stores an encrypted form of the password' do
      expect(phone_configuration.encrypted_phone).to_not be_blank
    end
  end
end
