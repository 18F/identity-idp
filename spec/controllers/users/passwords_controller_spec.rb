require 'rails_helper'

RSpec.describe Users::PasswordsController do
  context 'user visits add an email address page' do
    let(:user) { create(:user) }
    before do
      stub_sign_in(user)
      stub_analytics
    end
    it 'renders the index view' do
      get :edit
      expect(@analytics).to have_logged_event('Edit Password Page Visited')
    end
  end

  describe '#update' do
    context 'form returns success' do
      it 'redirects to profile and sends a password change email' do
        stub_sign_in
        stub_analytics
        stub_attempts_tracker
        allow(@analytics).to receive(:track_event)

        expect(@irs_attempts_api_tracker).to receive(:logged_in_password_change).
          with(success: true)

        params = {
          password: 'salty new password',
          password_confirmation: 'salty new password',
        }
        patch :update, params: { update_user_password_form: params }

        expect(@analytics).to have_received(:track_event).with(
          'Password Changed',
          success: true,
          errors: {},
          pending_profile_present: false,
          active_profile_present: false,
          user_id: subject.current_user.uuid,
        )
        expect(response).to redirect_to account_url
        expect(flash[:info]).to eq t('notices.password_changed')
        expect(flash[:personal_key]).to be_nil
      end

      it 'updates the user password and regenerates personal key' do
        user = create(:user, :proofed)
        stub_sign_in(user)
        Pii::Cacher.new(user, controller.user_session).save_decrypted_pii(
          Pii::Attributes.new(ssn: '111-222-3333'),
        )

        params = {
          password: 'strong password',
          password_confirmation: 'strong password',
        }

        expect do
          patch :update, params: { update_user_password_form: params }
        end.to(
          change { user.reload.encrypted_password_digest }.and(
            change { user.reload.encrypted_recovery_code_digest },
          ),
        )

        expect(flash[:personal_key]).to eq(assigns(:update_user_password_form).personal_key)
        expect(flash[:personal_key]).to be_present
      end

      it 'creates a user Event for the password change' do
        stub_sign_in(create(:user))

        params = { password: 'salty new password' }
        patch :update, params: { update_user_password_form: params }
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
    end

    context 'form returns failure' do
      let(:password) { 'new' }
      let(:params) do
        {
          password: password,
          password_confirmation: password,
        }
      end

      it 'does not create a password_changed user Event' do
        stub_sign_in

        expect(controller).to_not receive(:create_user_event)

        patch :update, params: { update_user_password_form: params }
      end

      context 'when password is too short' do
        before do
          stub_sign_in
          stub_analytics
          stub_attempts_tracker
          allow(@analytics).to receive(:track_event)
        end

        it 'renders edit' do
          expect(@irs_attempts_api_tracker).to receive(:logged_in_password_change).with(
            success: false,
          )

          patch :update, params: { update_user_password_form: params }

          expect(@analytics).to have_received(:track_event).with(
            'Password Changed',
            success: false,
            errors: {
              password: [
                t(
                  'errors.attributes.password.too_short.other',
                  count: Devise.password_length.first,
                ),
              ],
              password_confirmation: [t(
                'errors.messages.too_short.other',
                count: Devise.password_length.first,
              )],
            },
            error_details: {
              password: { too_short: true },
              password_confirmation: { too_short: true },
            },
            pending_profile_present: false,
            active_profile_present: false,
            user_id: subject.current_user.uuid,
          )
          expect(response).to render_template(:edit)
        end
      end

      context 'when passwords do not match' do
        let(:password) { 'salty pickles' }
        let(:password_confirmation) { 'salty pickles2' }

        let(:params) do
          {
            password: password,
            password_confirmation: password_confirmation,
          }
        end

        before do
          stub_sign_in
          stub_analytics
          stub_attempts_tracker
          allow(@analytics).to receive(:track_event)
        end

        it 'renders edit' do
          expect(@irs_attempts_api_tracker).to receive(:logged_in_password_change).with(
            success: false,
          )

          patch :update, params: { update_user_password_form: params }

          expect(@analytics).to have_received(:track_event).with(
            'Password Changed',
            success: false,
            errors: {
              password_confirmation: [t('errors.messages.password_mismatch')],
            },
            error_details: {
              password_confirmation: { mismatch: true },
            },
            pending_profile_present: false,
            active_profile_present: false,
            user_id: subject.current_user.uuid,
          )
          expect(response).to render_template(:edit)
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
        controller.user_session[:decrypted_pii] = pii.to_json

        get :edit

        expect(response).to render_template(:edit)
      end
    end
  end
end
