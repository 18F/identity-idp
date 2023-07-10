require 'rails_helper'

RSpec.describe Telephony::BasicSender do
  let(:configured_adapter) { :test }
  let(:recipient) { '+1 (202) 555-5000' }
  let(:message) { 'test test' }
  before do
    allow(Telephony.config).to receive(:adapter).and_return(configured_adapter)
    Telephony::Test::Message.clear_messages
  end

  describe 'send raw message notification' do
    it 'sends the correct message' do
      subject.send_notification(to: recipient, message: message, country_code: 'US')

      last_message = Telephony::Test::Message.messages.last
      expect(last_message.to).to eq(recipient)
      expect(last_message.body).to eq(message)
    end
  end
end
