require 'rails_helper'

describe ForgotPasswordShow do
  describe '#email' do
    it 'returns the session email and deletes the session value' do
      email = 'test@test.com'
      session = { email: email }

      view_model = ForgotPasswordShow.new(session: session, resend: false)
      view_model_email = view_model.email

      expect(view_model_email).to eq email
      expect(session[:email]).to eq nil
    end
  end
end
