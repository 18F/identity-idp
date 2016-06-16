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

    context 'when the user is fully authenticated' do
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
    context 'when the user enters an invalid OTP' do
      before do
        sign_in_before_2fa
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
        expect(subject.current_user).to receive(:authenticate_otp).and_return(false)
        patch :update, code: '12345'
      end

      it 'increments second_factor_attempts_count' do
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
      end

      it 're-renders the OTP entry screen' do
        expect(response).to render_template(:show)
      end

      it 'displays flash error message' do
        expect(flash[:error]).to eq t('devise.two_factor_authentication.attempt_failed')
      end
    end

    context 'when the user enters a valid OTP' do
      before do
        sign_in_before_2fa
        subject.current_user.send_new_otp
        expect(subject.current_user).to receive(:authenticate_otp).and_return(true)
        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end

      it 'redirects to the dashboard' do
        patch :update, code: subject.current_user.reload.direct_otp

        expect(response).to redirect_to dashboard_index_path
      end

      it 'resets the second_factor_attempts_count' do
        subject.current_user.update(second_factor_attempts_count: 1)
        patch :update, code: subject.current_user.reload.direct_otp

        expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
      end
    end

    context 'when user has not changed their number' do
      it 'does not perform SmsSenderNumberChangeJob' do
        user = create(:user, :signed_up)
        sign_in user
        user.send_new_otp

        expect(SmsSenderNumberChangeJob).to_not receive(:perform_later).with(user)

        patch :update, code: user.direct_otp
      end
    end

    context 'when the user lockout period expires' do
      before do
        sign_in_before_2fa
        subject.current_user.send_new_otp
        subject.current_user.update(
          second_factor_locked_at: Time.zone.now - Devise.direct_otp_valid_for - 1.seconds,
          second_factor_attempts_count: 3
        )
      end

      describe 'when user submits a bad code' do
        before do
          patch :update, code: '12345'
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 1
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end

      describe 'when user submits a correct code' do
        before do
          patch :update, code: subject.current_user.direct_otp
        end

        it 'resets attempts count' do
          expect(subject.current_user.reload.second_factor_attempts_count).to eq 0
        end

        it 'resets second_factor_locked_at' do
          expect(subject.current_user.reload.second_factor_locked_at).to eq nil
        end
      end
    end
  end

  describe '#show' do
    context 'when resource is not fully authenticated yet' do
      it 'renders the :show view' do
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

  describe '#new' do
    before do
      sign_in_before_2fa
    end

    it 'redirects to :show' do
      get :new

      expect(response).to redirect_to(action: :show)
    end

    it 'sends a new OTP' do
      old_otp = subject.current_user.direct_otp
      allow(SmsSenderOtpJob).to receive(:perform_later)
      get :new

      expect(SmsSenderOtpJob).to have_received(:perform_later).
        with(subject.current_user.direct_otp, subject.current_user.mobile)
      expect(subject.current_user.direct_otp).not_to eq(old_otp)
      expect(subject.current_user.direct_otp).not_to be_nil
    end
  end
end
