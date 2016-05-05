require 'rails_helper'

describe Devise::TwoFactorAuthenticationSetupController, devise: true do
  describe 'GET index' do
    context 'when signed out' do
      it 'redirects to sign in page' do
        get :index

        expect(response).to redirect_to(new_user_session_url)
      end
    end
  end

  describe 'PATCH set' do
    context 'when mobile number already exists' do
      it 'prompts to confirm the number', sms: true do
        user_with_mobile = create(:user, :with_mobile)
        user = create(:user)

        sign_in(user)

        patch(
          :set,
          user: { mobile: user_with_mobile.mobile }
        )

        expect(response).to redirect_to(user_two_factor_authentication_path)
        expect(flash[:success]).to eq t('devise.two_factor_authentication.please_confirm')
        expect(SmsSenderExistingMobileJob).to have_been_enqueued.with(global_id(user_with_mobile))
        expect(SmsSenderOtpJob).to_not have_been_enqueued.with(global_id(user_with_mobile))
        expect(SmsSenderOtpJob).to_not have_been_enqueued.with(global_id(user))
      end
    end
  end
end
