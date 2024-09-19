require 'rails_helper'

RSpec.describe IppHelper do
  include IppHelper

  describe '#scrub_body' do
    let(:message) { "This is a test message with sponsorID #{sponsor_id}" }
    let(:sponsor_id) { 1111111 }

    context 'when body is a String' do
      it 'scrubs the sponsorID from the message' do
        expect(scrub_body(message)).to eq('This is a test message with sponsorID [FILTERED]')
      end
    end

    context 'when body is a Hash' do
      it 'scrubs the responseMessage' do
        body = { responseMessage: message }
        expect(scrub_body(body)).to eq(
          'responseMessage' => 'This is a test message with sponsorID [FILTERED]',
        )
      end
    end

    context 'when body is nil' do
      it 'returns nil' do
        expect(scrub_body(nil)).to be_nil
      end
    end
  end
end
