require 'rails_helper'

describe SmsSenderConfirmationJob, sms: true do
  describe '.perform' do
    it 'sends a message containing the confirmation code to the mobile number' do
      SmsSenderConfirmationJob.perform_now('1234', '555-5555')

      expect(messages.size).to eq(1)
      msg = messages.first
      expect(msg.number).to eq('555-5555')
      expect(msg.body).to include('phone confirmation code is: 1234')
    end
  end
end
