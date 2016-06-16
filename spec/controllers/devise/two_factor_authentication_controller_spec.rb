require 'rails_helper'

describe Devise::TwoFactorAuthenticationController, devise: true do
  describe 'before_actions' do
    it 'includes the appropriate before_actions' do
      expect(subject).to have_filters(
        :before,
        :authenticate_scope!,
        :verify_user_is_not_second_factor_locked,
        :handle_two_factor_authentication,
        :check_already_authenticated
      )
    end
  end

  describe '#check_already_authenticated' do
    controller do
      before_filter :check_already_authenticated

      def index
        render text: 'Hello'
      end
    end

    context 'when the user is already fully signed in' do
      let(:user) { create(:user, :signed_up) }

      before do
        sign_in user
      end

      it 'redirects to the dashboard' do
        get :index

        expect(response).to redirect_to(dashboard_index_url)
      end

      it 'does not redirect if the user has an unconfirmed mobile' do
        subject.current_user.unconfirmed_mobile = '123'
        get :index

        expect(response).not_to redirect_to(dashboard_index_url)
        expect(response.code).to eq('200')
      end
    end

    context 'when the user if not fully signed in' do
      before do
        sign_in_before_2fa
      end

      it 'does not redirect to the dashboard' do
        get :index

        expect(response).not_to redirect_to(dashboard_index_url)
        expect(response.code).to eq('200')
      end
    end
  end

  describe '#update' do
    let(:user) { create(:user, :signed_up) }

    context 'when user has not changed their number' do
      it 'does not perform SmsSenderNumberChangeJob' do
        sign_in user
        user.send_new_otp

        expect(SmsSenderNumberChangeJob).
          to_not receive(:perform_later).with(user)

        patch :update, code: user.direct_otp
      end
    end

    context 'when resource is no longer OTP locked out' do
      before do
        sign_in_before_2fa
        subject.current_user.send_new_otp
        subject.current_user.update(
          second_factor_locked_at: Time.zone.now - Devise.direct_otp_valid_for - 1.seconds,
          second_factor_attempts_count: 3
        )
      end

      it 'resets attempts count when user submits bad code' do
        patch :update, code: '12345'

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 'resets second_factor_locked_at when user submits correct code' do
        patch :update, code: subject.current_user.direct_otp

        expect(subject.current_user.reload.second_factor_locked_at).to be_nil
      end
    end
  end

  describe '#show' do
    context 'when resource is not fully authenticated yet' do
      it 'renders the show view' do
        sign_in_before_2fa
        get :show

        expect(response).to_not be_redirect
        expect(response).to render_template(:show)
      end
    end

    context 'when resource is fully authenticated but has unconfirmed mobile' do
      it 'renders the show view' do
        user = create(:user, :signed_up, unconfirmed_mobile: '202-555-1212')
        sign_in user
        get :show

        expect(response).to render_template(:show)
      end
    end
  end
end
