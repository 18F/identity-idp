require 'rails_helper'

describe Test::TelephonyController do
  describe '#index' do
    it 'sets @messages and @calls and renders' do
      Telephony.send_authentication_otp(
        to: '(555) 555-5000',
        otp: '123456',
        expiration: 10,
        channel: :sms,
      )
      Telephony.send_authentication_otp(
        to: '(555) 555-5000',
        otp: '654321',
        expiration: 10,
        channel: :voice,
      )

      get :index

      expect(assigns(:messages).length).to eq(1)
      expect(assigns(:messages).first.body).to include('123456')

      expect(assigns(:calls).length).to eq(1)
      expect(assigns(:calls).first.body).to include('6, 5, 4, 3, 2, 1')
    end

    it '404s in production' do
      allow(Rails.env).to receive(:production?).and_return(true)

      get :index

      expect(response.status).to eq(404)
    end
  end
end
