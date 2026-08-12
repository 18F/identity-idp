require 'rails_helper'

RSpec.describe Users::PasswordsController do
  context 'user visits edit password page' do
    let(:user) { create(:user) }
    before do
      stub_sign_in(user)
      stub_analytics
    end
    it 'renders the index view' do
      get :edit
      expect(@analytics).to have_logged_event('Edit Password Page Visited')
    end

    context 'redirect_to_change_password is set to true' do
      before do
        stub_sign_in(user)
        session[:redirect_to_change_password] = true
      end

      it 'renders password compromised with required_password_change set to true' do
        get :edit
        expect(response).to render_template(:edit)
      end

      it 'logs analytics for password compromised visited' do
        get :edit
        expect(@analytics).to have_logged_event(
          'Edit Password Page Visited',
          required_password_change: true,
        )
      end
    end
  end

  describe '#update' do
    context 'form returns success' do
      it 'redirects to profile and sends a password change email' do
        stub_sign_in
        stub_analytics
        stub_attempts_tracker

        params = {
          password: 'salty new password',
          password_confirmation: 'salty new password',
        }

        expect(@attempts_api_tracker).to receive(:logged_in_password_change).with(
          success: true,
          failure_reason: nil,
        )
        patch :update, params: { update_user_password_form: params }

        expect(@analytics).to have_logged_event(
          'Password Changed',
          success: true,
          pending_profile_present: false,
          active_profile_present: false,
          user_id: subject.current_user.uuid,
          required_password_change: false,
        )
        expect(response).to redirect_to account_url
        expect(flash[:info]).to eq t('notices.password_changed')
        expect(controller.user_session[:personal_key]).to be_nil
      end

      it 'updates the user password and regenerates personal key' do
        user = create(:user, :proofed)
        stub_sign_in(user)
        Pii::Cacher.new(user, controller.user_session).save_decrypted_pii(
          Pii::Attributes.new(ssn: '111-222-3333'),
          user.active_profile.id,
        )

        params = {
          password: 'strong password',
          password_confirmation: 'strong password',
        }

        expect do
          patch :update, params: { update_user_password_form: params }
        end.to(
          change { user.reload.encrypted_password_digest_multi_region }.and(
            change { user.reload.encrypted_recovery_code_digest_multi_region },
          ),
        )

        expect(controller.user_session[:personal_key]).to eq(
          assigns(:update_user_password_form).personal_key,
        )
        expect(response).to redirect_to manage_personal_key_url
      end

      it 'creates a user Event for the password change' do
        user = stub_sign_in

        params = {
          password: 'salty new password',
          password_confirmation: 'salty new password',
        }

        expect do
          patch :update, params: { update_user_password_form: params }
        end.to change { user.events.password_changed.size }.by 1
      end

      it 'sends a security event' do
        user = create(:user)
        stub_sign_in(user)
        security_event = PushNotification::PasswordResetEvent.new(user: user)
        expect(PushNotification::HttpPush).to receive(:deliver).with(security_event)

        params = {
          password: 'salty new password',
          password_confirmation: 'salty new password',
        }
        patch :update, params: { update_user_password_form: params }
      end

      it 'sends the user an email' do
        user = create(:user)

        stub_sign_in(user)

        params = {
          password: 'salty new password',
          password_confirmation: 'salty new password',
        }
        patch :update, params: { update_user_password_form: params }

        expect_delivered_email_count(1)
        expect_delivered_email(
          to: [user.email_addresses.first.email],
          subject: t('devise.mailer.password_updated.subject'),
        )
      end

      context 'redirect_to_change_password is set to true' do
        let(:user) { create(:user) }
        let(:password) { 'salty new password' }
        let(:params) do
          {
            password: password,
            password_confirmation: password,
          }
        end

        before do
          stub_sign_in(user)
          stub_analytics
          stub_attempts_tracker
          session[:redirect_to_change_password] = true
        end

        it 'updates the user password and logs analytic event' do
          patch :update, params: { update_user_password_form: params }

          expect(@analytics).to have_logged_event(
            'Password Changed',
            success: true,
            pending_profile_present: false,
            active_profile_present: false,
            user_id: subject.current_user.uuid,
            required_password_change: true,
          )
          expect(response).to redirect_to account_url
          expect(flash[:info]).to eq t('notices.password_changed')
        end

        it 'sends email notifying user of password change' do
          patch :update, params: { update_user_password_form: params }
          expect_delivered_email_count(1)
        end

        it 'sends a security event' do
          security_event = PushNotification::PasswordResetEvent.new(user: user)
          expect(PushNotification::HttpPush).to receive(:deliver).with(security_event)

          patch :update, params: { update_user_password_form: params }
        end

        it 'tracks the attempts event' do
          expect(@attempts_api_tracker).to receive(:logged_in_password_change).with(
            success: true,
            failure_reason: nil,
          )

          patch :update, params: { update_user_password_form: params }
        end
      end
    end

    context 'form returns failure' do
      let(:password) { 'new' }
      let(:params) do
        {
          password:,
          password_confirmation: password,
        }
      end

      before do
        stub_analytics
        stub_attempts_tracker
      end

      it 'does not create a password_changed user Event' do
        stub_sign_in

        expect(controller).to_not receive(:create_user_event)

        patch :update, params: { update_user_password_form: params }
      end

      context 'redirect_to_change_password is set to true' do
        let(:user) { create(:user) }
        let(:password) { 'false' }
        let(:params) do
          {
            password: password,
            password_confirmation: 'false',
          }
        end

        before do
          stub_sign_in(user)
          session[:redirect_to_change_password] = true
        end

        it 'renders edit' do
          patch :update, params: { update_user_password_form: params }

          expect(@analytics).to have_logged_event(
            'Password Changed',
            success: false,
            error_details: {
              password: { too_short: true },
              password_confirmation: { too_short: true },
            },
            pending_profile_present: false,
            active_profile_present: false,
            user_id: subject.current_user.uuid,
            required_password_change: true,
          )
          expect(response).to render_template(:edit)
        end

        it 'tracks the attempts event' do
          expect(@attempts_api_tracker).to receive(:logged_in_password_change).with(
            success: false,
            failure_reason: {
              password: [:too_short],
              password_confirmation: [:too_short],
            },
          )

          patch :update, params: { update_user_password_form: params }
        end
      end

      context 'when password is too short' do
        before do
          stub_sign_in
        end

        it 'renders edit' do
          patch :update, params: { update_user_password_form: params }

          expect(@analytics).to have_logged_event(
            'Password Changed',
            success: false,
            error_details: {
              password: { too_short: true },
              password_confirmation: { too_short: true },
            },
            pending_profile_present: false,
            active_profile_present: false,
            user_id: subject.current_user.uuid,
            required_password_change: false,
          )
          expect(response).to render_template(:edit)
        end

        it 'tracks the attempts event' do
          expect(@attempts_api_tracker).to receive(:logged_in_password_change).with(
            success: false,
            failure_reason: {
              password: [:too_short],
              password_confirmation: [:too_short],
            },
          )

          patch :update, params: { update_user_password_form: params }
        end
      end

      context 'when passwords do not match' do
        let(:password) { 'salty pickles' }
        let(:password_confirmation) { 'salty pickles2' }

        let(:params) do
          {
            password:,
            password_confirmation:,
          }
        end

        before do
          stub_sign_in
        end

        it 'renders edit' do
          patch :update, params: { update_user_password_form: params }

          expect(@analytics).to have_logged_event(
            'Password Changed',
            success: false,
            error_details: {
              password_confirmation: { mismatch: true },
            },
            pending_profile_present: false,
            active_profile_present: false,
            user_id: subject.current_user.uuid,
            required_password_change: false,
          )
          expect(response).to render_template(:edit)
        end

        it 'tracks the attempts event' do
          expect(@attempts_api_tracker).to receive(:logged_in_password_change).with(
            success: false,
            failure_reason: {
              password_confirmation: [:mismatch],
            },
          )

          patch :update, params: { update_user_password_form: params }
        end
      end
    end
  end

  describe '#edit' do
    context 'user has a profile with PII' do
      let(:pii) { { first_name: 'Jane' } }
      before do
        user = create(:user)
        create(:profile, :active, :verified, user: user, pii: pii)
        stub_sign_in(user)
      end

      it 'redirects to capture password if PII is not decrypted' do
        get :edit

        expect(response).to redirect_to capture_password_path
      end

      it 'renders form if PII is decrypted' do
        Pii::Cacher.new(
          controller.current_user,
          controller.user_session,
        ).save_decrypted_pii(pii, 123)

        get :edit

        expect(response).to render_template(:edit)
      end
    end
  end
end
