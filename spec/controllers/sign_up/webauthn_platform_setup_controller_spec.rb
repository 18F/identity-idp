require 'rails_helper'

RSpec.describe SignUp::WebauthnPlatformSetupController do
  describe 'before_actions' do
    it 'includes performs all actions' do
      expect(controller).to have_actions(
        :before,
        :confirm_user_authenticated_for_2fa_setup,
        :apply_secure_headers_override,
      )
    end

    describe '#new' do
      it 'logs analytics value' do
        stub_analytics
        get :new

        expect(@analytics).to have_logged_event(:webauthn_platform_signup_setup_visited)
      end
    end
  end
end
