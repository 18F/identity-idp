require 'rails_helper'

describe SmsSenderNumberChangeJob, sms: true do
  describe '.perform' do
    it 'sends number change message to the mobile number' do
      SmsSenderNumberChangeJob.perform_now('1234')

      expect(messages.size).to eq(1)
      msg = messages.first
      expect(msg.number).to eq('1234')
      expect(msg.body).to include('You have changed the phone number')
    end
  end
end
