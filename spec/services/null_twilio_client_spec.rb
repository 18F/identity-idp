require 'rails_helper'

describe NullTwilioClient do
  describe '#messages' do
    it 'returns self' do
      client = NullTwilioClient.new

      expect(client.messages).to eq client
    end
  end

  describe '#calls' do
    it 'returns self' do
      client = NullTwilioClient.new

      expect(client.calls).to eq client
    end
  end
end
