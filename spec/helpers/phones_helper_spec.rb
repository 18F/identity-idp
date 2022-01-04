require 'rails_helper'

RSpec.describe PhonesHelper do
  include PhonesHelper

  describe 'phones' do
    let(:user) { create(:user, :signed_up, with: { phone: '+1 (202) 555-1234' }) }

    it 'returns true if less than 5 phone numbers' do
      allow(helper).to receive(:current_user) { user }

      expect(helper.can_add_phone?).to eq(true)
    end

    it 'returns false if more than 5 phone numbers' do
      allow(helper).to receive(:current_user) { user }

      user.phone_configurations.create(encrypted_phone: '4105555555')
      user.phone_configurations.create(encrypted_phone: '4105555555')
      user.phone_configurations.create(encrypted_phone: '4105555555')
      user.phone_configurations.create(encrypted_phone: '4105555555')
      expect(helper.can_add_phone?).to eq(false)
    end
  end
end
