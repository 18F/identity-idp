require 'rails_helper'

describe 'SMS receiving' do
  let(:username) { 'auth_username' }
  let(:password) { 'auth_password' }
  let(:access_denied) { 'HTTP Basic: Access denied' }
  let(:credentials) { "Basic #{Base64.encode64("#{username}:#{password}")}" }
  let(:help_message) { 'help' }
  let(:invalid_message) { 'blargh' }

  describe 'HTTP Basic Authentication' do
    context 'without required credentials' do
      it 'returns unauthorized status' do
        post api_sms_receive_path

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include(access_denied)
      end
    end

    context 'with required credentials' do
      it 'returns authorized status' do
        allow(Figaro.env).to(
          receive(:twilio_http_basic_auth_username).and_return(username),
        )
        allow(Figaro.env).to(
          receive(:twilio_http_basic_auth_password).and_return(password),
        )
        allow_any_instance_of(Twilio::Security::RequestValidator).to(
          receive(:validate).and_return(true),
        )

        post_message(help_message)

        expect(response).to have_http_status(:accepted)
      end
    end
  end

  describe 'receiving messages' do
    before do
      allow(Figaro.env).to(
        receive(:twilio_http_basic_auth_username).and_return(username),
      )
      allow(Figaro.env).to(
        receive(:twilio_http_basic_auth_password).and_return(password),
      )
    end

    context 'when failing' do
      it 'does not send a reply and 403s when signature is invalid' do
        allow_any_instance_of(Twilio::Security::RequestValidator).to(
          receive(:validate).and_return(false),
        )

        post_message(help_message)

        expect(response).to have_http_status(:forbidden)
        expect(Telephony::Test::Message.messages.length).to eq(0)
      end

      it 'responds with a 200 status when signature is valid' do
        allow_any_instance_of(Twilio::Security::RequestValidator).to(
          receive(:validate).and_return(true),
        )

        post_message(invalid_message)

        expect(response).to have_http_status(:ok)
        expect(Telephony::Test::Message.messages.length).to eq(0)
      end
    end

    context 'when successful' do
      it 'sends a reply' do
        allow_any_instance_of(Twilio::Security::RequestValidator).to(
          receive(:validate).and_return(true),
        )

        expect(Telephony).to receive(:send_help_keyword_response)

        post_message(help_message)

        expect(response).to have_http_status(:accepted)
      end
    end
  end

  private

  def post_message(body)
    post(
      api_sms_receive_path,
      params: { Body: body },
      headers: { 'HTTP_AUTHORIZATION': credentials },
    )
  end
end
