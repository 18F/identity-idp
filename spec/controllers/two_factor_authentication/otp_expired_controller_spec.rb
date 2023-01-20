require 'rails_helper'

describe TwoFactorAuthentication::OtpExpiredController do
  describe '#show' do
    it 'renders the page' do
      sign_in_before_2fa

      get :show

      expect(response).to render_template(:show)
    end
  end
end
