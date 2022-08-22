require 'rails_helper'

describe Users::ResetPasswordsController, devise: true do
  let(:password_error_message) do
    "This password is too short (minimum is #{Devise.password_length.first} characters)"
  end
  describe '#edit' do
    context 'no user matches token' do
      it 'redirects to page where user enters email for password reset token' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        get :edit, params: { reset_password_token: 'foo' }

        analytics_hash = {
          success: false,
          errors: { user: ['invalid_token'] },
          error_details: { user: [:blank] },
          user_id: nil,
        }

        expect(@analytics).to have_received(:track_event).
          with('Password Reset: Token Submitted', analytics_hash)

        expect(response).to redirect_to new_user_password_path
        expect(flash[:error]).to eq t('devise.passwords.invalid_token')
      end
    end

    context 'token expired' do
      it 'redirects to page where user enters email for password reset token' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        user = instance_double('User', uuid: '123')
        allow(User).to receive(:with_reset_password_token).with('foo').and_return(user)
        allow(user).to receive(:reset_password_period_valid?).and_return(false)

        get :edit, params: { reset_password_token: 'foo' }

        analytics_hash = {
          success: false,
          errors: { user: ['token_expired'] },
          error_details: { user: ['token_expired'] },
          user_id: '123',
        }

        expect(@analytics).to have_received(:track_event).
          with('Password Reset: Token Submitted', analytics_hash)

        expect(response).to redirect_to new_user_password_path
        expect(flash[:error]).to eq t('devise.passwords.token_expired')
      end
    end

    context 'token is valid' do
      render_views

      it 'displays the form to enter a new password and disallows indexing' do
        stub_analytics

        user = instance_double('User', uuid: '123')
        email_address = instance_double('EmailAddress')
        allow(User).to receive(:with_reset_password_token).with('foo').and_return(user)
        allow(user).to receive(:reset_password_period_valid?).and_return(true)
        allow(user).to receive(:email_addresses).and_return([email_address])
        expect(email_address).to receive(:email).twice

        forbidden = instance_double(ForbiddenPasswords)
        allow(ForbiddenPasswords).to receive(:new).with(email_address.email).and_return(forbidden)
        expect(forbidden).to receive(:call)

        get :edit, params: { reset_password_token: 'foo' }

        expect(response).to render_template :edit
        expect(flash.keys).to be_empty
        expect(response.body).to match('<meta content="noindex,nofollow" name="robots" />')
      end
    end
  end

  describe '#update' do
    context 'user submits new password after token expires' do
      it 'redirects to page where user enters email for password reset token' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)
        user = create(
          :user,
          :signed_up,
          reset_password_sent_at: Time.zone.now - Devise.reset_password_within - 1.hour,
          reset_password_token: db_confirmation_token,
        )

        params = { password: 'short', reset_password_token: raw_reset_token }

        get :edit, params: { reset_password_token: raw_reset_token }
        put :update, params: { reset_password_form: params }

        analytics_hash = {
          success: false,
          errors: {
            password: [password_error_message],
            reset_password_token: ['token_expired'],
          },
          error_details: {
            password: [:too_short],
            reset_password_token: ['token_expired'],
          },
          user_id: user.uuid,
          profile_deactivated: false,
        }

        expect(@analytics).to have_received(:track_event).
          with('Password Reset: Password Submitted', analytics_hash)

        expect(response).to redirect_to new_user_password_path
        expect(flash[:error]).to eq t('devise.passwords.token_expired')
      end
    end

    context 'user submits invalid new password' do
      it 'renders edit' do
        stub_analytics

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)
        user = create(
          :user,
          :signed_up,
          reset_password_token: db_confirmation_token,
          reset_password_sent_at: Time.zone.now,
        )
        form_params = { password: 'short', reset_password_token: raw_reset_token }
        analytics_hash = {
          success: false,
          errors: {
            password: [password_error_message],
          },
          error_details: {
            password: [:too_short],
          },
          user_id: user.uuid,
          profile_deactivated: false,
        }

        expect(@analytics).to receive(:track_event).
          with('Password Reset: Password Submitted', analytics_hash)

        put :update, params: { reset_password_form: form_params }

        expect(assigns(:forbidden_passwords)).to all(be_a(String))
        expect(response).to render_template(:edit)
      end
    end

    context 'user submits the reset password form twice' do
      it 'shows an invalid token error' do
        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)
        create(
          :user,
          :unconfirmed,
          reset_password_token: db_confirmation_token,
          reset_password_sent_at: Time.zone.now,
        )
        form_params = { password: 'a really long passw0rd', reset_password_token: raw_reset_token }

        put :update, params: { reset_password_form: form_params }
        put :update, params: { reset_password_form: form_params }

        expect(response).to redirect_to new_user_password_path
        expect(flash[:error]).to eq t('devise.passwords.invalid_token')
      end
    end

    context 'IAL1 user submits valid new password' do
      it 'redirects to sign in page' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)

        freeze_time do
          user = create(
            :user,
            :signed_up,
            reset_password_token: db_confirmation_token,
            reset_password_sent_at: Time.zone.now,
          )
          old_confirmed_at = user.reload.confirmed_at
          allow(user).to receive(:active_profile).and_return(nil)

          security_event = PushNotification::PasswordResetEvent.new(user: user)
          expect(PushNotification::HttpPush).to receive(:deliver).with(security_event)

          stub_user_mailer(user)

          password = 'a really long passw0rd'
          params = { password: password, reset_password_token: raw_reset_token }

          get :edit, params: { reset_password_token: raw_reset_token }
          put :update, params: { reset_password_form: params }

          analytics_hash = {
            success: true,
            errors: {},
            user_id: user.uuid,
            profile_deactivated: false,
          }

          expect(@analytics).to have_received(:track_event).
            with('Password Reset: Password Submitted', analytics_hash)

          expect(user.events.password_changed.size).to be 1

          expect(response).to redirect_to new_user_session_path
          expect(flash[:info]).to eq t('devise.passwords.updated_not_active')
          expect(user.reload.confirmed_at).to eq old_confirmed_at
        end
      end
    end

    context 'ial2 user submits valid new password' do
      it 'deactivates the active profile and redirects' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)
        user = create(
          :user,
          reset_password_token: db_confirmation_token,
          reset_password_sent_at: Time.zone.now,
        )
        _profile = create(:profile, :active, :verified, user: user)

        security_event = PushNotification::PasswordResetEvent.new(user: user)
        expect(PushNotification::HttpPush).to receive(:deliver).with(security_event)

        stub_user_mailer(user)

        get :edit, params: { reset_password_token: raw_reset_token }
        password = 'a really long passw0rd'
        params = { password: password, reset_password_token: raw_reset_token }

        put :update, params: { reset_password_form: params }

        analytics_hash = {
          success: true,
          errors: {},
          user_id: user.uuid,
          profile_deactivated: true,
        }

        expect(@analytics).to have_received(:track_event).
          with('Password Reset: Password Submitted', analytics_hash)

        expect(user.active_profile.present?).to eq false

        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'unconfirmed user submits valid new password' do
      it 'confirms the user' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)

        user = create(
          :user,
          :unconfirmed,
          reset_password_token: db_confirmation_token,
          reset_password_sent_at: Time.zone.now,
        )

        security_event = PushNotification::PasswordResetEvent.new(user: user)
        expect(PushNotification::HttpPush).to receive(:deliver).with(security_event)

        stub_user_mailer(user)

        password = 'a really long passw0rd'
        params = { password: password, reset_password_token: raw_reset_token }

        get :edit, params: { reset_password_token: raw_reset_token }
        put :update, params: { reset_password_form: params }

        analytics_hash = {
          success: true,
          errors: {},
          user_id: user.uuid,
          profile_deactivated: false,
        }

        expect(@analytics).to have_received(:track_event).
          with('Password Reset: Password Submitted', analytics_hash)

        expect(user.reload.confirmed?).to eq true

        expect(response).to redirect_to new_user_session_path
      end
    end
  end

  describe '#create' do
    context 'no user matches email' do
      let(:email) { 'nonexistent@example.com' }

      it 'send an email to tell the user they do not have an account yet' do
        stub_analytics
        stub_attempts_tracker
        allow(@irs_attempts_api_tracker).to receive(:track_event)

        expect do
          put :create, params: {
            password_reset_email_form: { email: email },
          }
        end.to(change { ActionMailer::Base.deliveries.count }.by(1))

        analytics_hash = {
          success: true,
          errors: {},
          user_id: 'nonexistent-uuid',
          confirmed: false,
          active_profile: false,
        }

        expect(@analytics).to have_logged_event('Password Reset: Email Submitted', analytics_hash)

        analytics_hash = {
          success: true,
          throttled: false,
          errors: {},
          email_already_exists: false,
          user_id: User.find_with_email(email).uuid,
          domain_name: 'example.com',
        }
        expect(@analytics).to have_logged_event(
          'User Registration: Email Submitted',
          analytics_hash,
        )
        expect(@irs_attempts_api_tracker).to have_received(:track_event).with(
          :user_registration_email_submitted,
          email: email,
          success: true,
          failure_reason: nil,
        )

        expect(response).to redirect_to forgot_password_path
      end
    end

    context 'user exists' do
      let(:email) { 'test@example.com' }

      it 'sends password reset email to user and tracks event' do
        stub_analytics
        stub_attempts_tracker
        allow(@irs_attempts_api_tracker).to receive(:track_event)

        user = create(:user, :signed_up, email: email)

        analytics_hash = {
          success: true,
          errors: {},
          user_id: user.uuid,
          confirmed: true,
          active_profile: false,
        }

        expect(@analytics).to receive(:track_event).
          with('Password Reset: Email Submitted', analytics_hash)

        expect do
          put :create, params: { password_reset_email_form: { email: email } }
        end.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(@irs_attempts_api_tracker).to have_received(:track_event).with(
          :forgot_password_email_sent,
          email: email,
          success: true,
          failure_reason: nil,
        )

        expect(response).to redirect_to forgot_password_path
      end
    end

    context 'user exists but is unconfirmed' do
      it 'sends password reset email to user and tracks event' do
        stub_analytics
        stub_attempts_tracker
        allow(@irs_attempts_api_tracker).to receive(:track_event)

        user = create(:user, :unconfirmed)

        analytics_hash = {
          success: true,
          errors: {},
          user_id: user.uuid,
          confirmed: false,
          active_profile: false,
        }

        expect(@analytics).to receive(:track_event).
          with('Password Reset: Email Submitted', analytics_hash)

        params = { password_reset_email_form: { email: user.email } }
        expect { put :create, params: params }.
          to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(ActionMailer::Base.deliveries.last.subject).
          to eq t('user_mailer.reset_password_instructions.subject')

        expect(@irs_attempts_api_tracker).to have_received(:track_event).with(
          :forgot_password_email_sent,
          email: user.email,
          success: true,
          failure_reason: nil,
        )

        expect(response).to redirect_to forgot_password_path
      end
    end

    context 'user is verified' do
      it 'captures in analytics that the user was verified' do
        stub_analytics
        stub_attempts_tracker
        allow(@irs_attempts_api_tracker).to receive(:track_event)

        user = create(:user, :signed_up)
        create(:profile, :active, :verified, user: user)

        analytics_hash = {
          success: true,
          errors: {},
          user_id: user.uuid,
          confirmed: true,
          active_profile: true,
        }

        expect(@analytics).to receive(:track_event).
          with('Password Reset: Email Submitted', analytics_hash)

        params = { password_reset_email_form: { email: user.email } }
        put :create, params: params

        expect(@irs_attempts_api_tracker).to have_received(:track_event).with(
          :forgot_password_email_sent,
          email: user.email,
          success: true,
          failure_reason: nil,
        )
      end
    end

    context 'email is invalid' do
      it 'displays an error and tracks event' do
        stub_analytics

        analytics_hash = {
          success: false,
          errors: { email: [t('valid_email.validations.email.invalid')] },
          error_details: { email: [:invalid] },
          user_id: 'nonexistent-uuid',
          confirmed: false,
          active_profile: false,
        }

        expect(@analytics).to receive(:track_event).
          with('Password Reset: Email Submitted', analytics_hash)

        params = { password_reset_email_form: { email: 'foo' } }
        expect { put :create, params: params }.
          to change { ActionMailer::Base.deliveries.count }.by(0)

        expect(response).to render_template :new
      end
    end

    it 'renders new if email is nil' do
      expect do
        post :create, params: { password_reset_email_form: { resend: false } }
      end.to change { ActionMailer::Base.deliveries.count }.by(0)

      expect(response).to render_template :new
    end

    it 'renders new if email is a Hash' do
      post :create, params: { password_reset_email_form: { email: { foo: 'bar' } } }

      expect(response).to render_template(:new)
    end
  end

  describe '#new' do
    it 'logs visit to analytics' do
      stub_analytics

      expect(@analytics).to receive(:track_event).with('Password Reset: Email Form Visited')

      get :new
    end
  end

  def stub_user_mailer(user)
    mailer = instance_double(ActionMailer::MessageDelivery, deliver_now_or_later: true)
    user.email_addresses.each do |email_address|
      allow(UserMailer).to receive(:password_changed).
        with(user, email_address, disavowal_token: instance_of(String)).
        and_return(mailer)
    end
  end
end
