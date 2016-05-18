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
      it 'prompts to confirm the number' do
        user_with_mobile = create(:user, :with_mobile)
        user = create(:user)

        sign_in(user)

        patch(
          :set,
          user: { mobile: user_with_mobile.mobile }
        )

        expect(response).to redirect_to(user_two_factor_authentication_path)
        expect(flash[:success]).to eq t('devise.two_factor_authentication.please_confirm')
      end

      it 'calls UserProfileUpdater#send_notifications' do
        user_with_mobile = create(:user, :with_mobile)
        user = create(:user)

        flash = instance_double(ActionDispatch::Flash::FlashHash)
        allow(subject).to receive(:flash).and_return(flash)

        sign_in(user)

        updater = instance_double(UserProfileUpdater)
        allow(UserProfileUpdater).to receive(:new).with(user, flash).
          and_return(updater)

        expect(updater).to receive(:attribute_already_taken?).and_return(true)
        expect(updater).to receive(:send_notifications)

        expect(flash).to receive(:[]=).
          with(:success, t('devise.two_factor_authentication.please_confirm'))

        patch(
          :set,
          user: { mobile: user_with_mobile.mobile }
        )
      end

      it 'does not call User#send_two_factor_authentication_code' do
        user_with_mobile = create(:user, :with_mobile)
        user = create(:user)

        sign_in(user)

        expect(subject.current_user).to_not receive(:send_two_factor_authentication_code)

        patch(
          :set,
          user: { mobile: user_with_mobile.mobile }
        )
      end
    end
  end
end
