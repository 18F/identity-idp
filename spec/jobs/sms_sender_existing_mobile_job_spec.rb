require 'rails_helper'

describe SmsSenderExistingMobileJob, sms: true do
  describe '.perform' do
    it 'sends existing mobile message to mobile number' do
      SmsSenderExistingMobileJob.perform_now('1234')

      expect(messages.size).to eq(1)
      msg = messages.first
      expect(msg.number).to eq('1234')
      expect(msg.body).to include('This number is already set up to receive one-time passwords')
    end
  end
end
