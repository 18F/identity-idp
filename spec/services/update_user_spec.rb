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
  end
end
