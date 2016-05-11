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
      end

      it 'calls UserProfileUpdater#send_notifications' do
        sign_in(user)

        form = instance_double(TwoFactorSetupForm)
        allow(TwoFactorSetupForm).to receive(:new).with(user).and_return(form)
        expect(form).to receive(:submit).with(mobile: second_user.mobile)

        updater = instance_double(UserProfileUpdater)
        allow(UserProfileUpdater).to receive(:new).with(form).
          and_return(updater)

        expect(updater).to receive(:attribute_already_taken?).and_return(true)
        expect(updater).to receive(:send_notifications)

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
