require 'rails_helper'

describe SmsSenderExistingMobileJob, sms: true do
  let(:user) { build_stubbed(:user, :with_mobile, otp_secret_key: 'lzmh6ekrnc5i6aaq') }

  describe '.perform' do
    it 'sends existing mobile message to user.mobile' do
      SmsSenderExistingMobileJob.perform_now(user.mobile)

      expect(messages.size).to eq(1)
      msg = messages.first
      expect(msg.number).to eq(user.mobile)
      expect(msg.from).to eq('+19999999999')
      expect(msg.body).to include('This number is already set up to receive one-time passwords')
    end
  end
end
