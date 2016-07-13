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

    context 'when mobile number does not already exist' do
      it 'prompts to confirm the number' do
        user = create(:user)
        sign_in(user)

        stub_analytics(user)
        expect(@analytics).to receive(:track_event).with('2FA setup: valid phone number')

        patch(
          :set,
          two_factor_setup_form: { mobile: '703-555-0100' }
        )

        expect(response).to redirect_to(user_two_factor_authentication_path)
      end
    end
  end

  describe 'before_actions' do
    it 'includes the appropriate before_actions' do
      expect(subject).to have_filters(
        :before,
        :authenticate_scope!,
        :authorize_otp_setup
      )
    end
  end

  describe '#authorize_otp_setup' do
    context 'when the user is fully authenticated' do
      it 'redirects to root url' do
        user = create(:user, :signed_up)
        sign_in(user)

        get :index

        expect(response).to redirect_to(root_url)
      end
    end

    context 'when the user is two_factor_enabled but not fully authenticated' do
      it 'prompts to enter OTP' do
        sign_in_before_2fa

        get :index

        expect(response).to redirect_to(user_two_factor_authentication_path)
      end
    end
  end
end
