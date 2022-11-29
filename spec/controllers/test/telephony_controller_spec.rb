require 'rails_helper'

describe Test::TelephonyController do
  describe '#index' do
    it 'sets @messages and @calls and renders' do
      Telephony.send_authentication_otp(
        to: '(555) 555-5000',
        otp: '123456',
        expiration: 10,
        channel: :sms,
        domain: IdentityConfig.store.domain_name,
        country_code: 'US',
        extra_metadata: {},
      )
      Telephony.send_authentication_otp(
        to: '(555) 555-5000',
        otp: '654321',
        expiration: 10,
        channel: :voice,
        domain: IdentityConfig.store.domain_name,
        country_code: 'US',
        extra_metadata: {},
      )

      get :index

      expect(assigns(:messages).length).to eq(1)
      expect(assigns(:messages).first.otp).to include('123456')

      expect(assigns(:calls).length).to eq(1)
      expect(assigns(:calls).first.otp).to eq('654321')
    end

    it '404s in production' do
      allow(Rails.env).to receive(:production?).and_return(true)

      get :index

      expect(response.status).to eq(404)
    end
  end

  describe '#destroy' do
    it 'clears messages and calls and redirects to index' do
      Telephony.send_authentication_otp(
        to: '(555) 555-5000',
        otp: '123456',
        expiration: 10,
        channel: :sms,
        domain: IdentityConfig.store.domain_name,
        country_code: 'US',
        extra_metadata: {},
      )
      Telephony.send_authentication_otp(
        to: '(555) 555-5000',
        otp: '654321',
        expiration: 10,
        channel: :voice,
        domain: IdentityConfig.store.domain_name,
        country_code: 'US',
        extra_metadata: {},
      )

      delete :destroy

      expect(Telephony::Test::Message.messages.length).to eq(0)
      expect(Telephony::Test::Call.calls.length).to eq(0)
      expect(response).to redirect_to(test_telephony_url)
    end
  end
end
