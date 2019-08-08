require 'rails_helper'

describe Telephony::Twilio::TwilioVoiceController do
  describe '#show' do
    context 'with nothing in the params' do
      it 'renders an error' do
        expect(NewRelic::Agent).to receive(:notice_error)

        get :show, format: :xml

        expect(response).to have_http_status(400)
      end
    end

    context 'with a callback URL' do
      it 'renders the twiml' do
        message = Telephony::Twilio::ProgrammableVoiceMessage.new(message: 'this is a test message')

        params = Rack::Utils.parse_nested_query URI.parse(message.callback_url).query

        get :show, params: params, format: :xml

        expect(response.body).to include('this is a test message')
      end
    end
  end
end
