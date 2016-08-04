require 'rails_helper'

describe TwilioSmsService do
  describe '#send_sms' do
    it 'sends an SMS from the number configured in the twilio_accounts config', twilio: true do
      expect(Twilio::REST::Client).
        to receive(:new).with(/sid(1|2)/, /token(1|2)/).and_call_original

      service = TwilioSmsService.new
      service.send_sms(
        to: '5555555555',
        body: '!!CODE1!!'
      )

      messages = MockTwilioClient.messages
      expect(messages.size).to eq(1)
      messages.each do |msg|
        expect(msg.from).to match(/(\+19999999999|\+12222222222)/)
        expect(msg.to).to eq('5555555555')
        expect(msg.body).to eq('!!CODE1!!')
      end
    end
  end
end
