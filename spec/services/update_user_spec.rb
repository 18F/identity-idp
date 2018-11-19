require 'rails_helper'

describe UpdateUser do
  describe '#call' do
    it 'updates the user with the passed in attributes' do
      user = build(:user, otp_delivery_preference: 'sms')
      attributes = { otp_delivery_preference: 'voice' }
      updater = UpdateUser.new(user: user, attributes: attributes)

      updater.call

      expect(user.otp_delivery_preference).to eq 'voice'
      expect(user.voice?).to eq true
    end

    context 'with a phone already configured' do
      let(:user) { create(:user, :with_phone) }

      it 'does not delete the phone configuration' do
        attributes = { phone: nil }
        updater = UpdateUser.new(user: user, attributes: attributes)
        updater.call
        expect(user.phone_configurations.reload).to_not be_empty
      end
    end

    context 'with no phone configured' do
      let(:user) { create(:user) }
      it 'creates a phone configuration' do
        confirmed_at = 1.day.ago.change(usec: 0)
        attributes = {
          otp_delivery_preference: 'voice',
          phone: '+1 222 333-4444',
          phone_confirmed_at: confirmed_at,
        }
        updater = UpdateUser.new(user: user, attributes: attributes)
        updater.call
        phone_configuration = user.phone_configurations.reload.first
        expect(phone_configuration.delivery_preference).to eq 'voice'
        expect(phone_configuration.confirmed_at).to eq confirmed_at
        expect(phone_configuration.phone).to eq '+1 222 333-4444'
      end
    end
  end
end
