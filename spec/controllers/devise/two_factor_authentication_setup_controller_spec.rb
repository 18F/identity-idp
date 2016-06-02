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
      let(:user) { create(:user) }
      let(:second_user) { create(:user, :signed_up) }

      it 'prompts to confirm the number' do
        sign_in(user)

        patch(
          :set,
          two_factor_setup_form: { mobile: second_user.mobile }
        )

        expect(response).to redirect_to(user_two_factor_authentication_path)
        expect(flash[:success]).to eq t('devise.two_factor_authentication.please_confirm')
        expect(user.reload.mobile).to be_nil
        expect(user.reload.unconfirmed_mobile).to eq second_user.mobile
      end

      it 'calls SmsSenderExistingMobileJob' do
        sign_in(user)

        expect(SmsSenderExistingMobileJob).to receive(:perform_later).
          with(second_user.mobile)

        patch(
          :set,
          two_factor_setup_form: { mobile: second_user.mobile }
        )
      end

      it 'does not call User#send_two_factor_authentication_code' do
        sign_in(user)

        expect(subject.current_user).to_not receive(:send_two_factor_authentication_code)

        patch(
          :set,
          two_factor_setup_form: { mobile: second_user.mobile }
        )
      end
    end
  end
end
