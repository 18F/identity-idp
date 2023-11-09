require 'rails_helper'

RSpec.describe Users::ResetPasswordsController, devise: true do
  let(:password_error_message) do
    t('errors.attributes.password.too_short.other', count: Devise.password_length.first)
  end
  let(:success_properties) { { success: true, failure_reason: nil } }
  describe '#edit' do
    let(:user) { instance_double('User', uuid: '123') }
    let(:email_address) { instance_double('EmailAddress') }
    before do
      stub_analytics
      stub_attempts_tracker
      allow(@analytics).to receive(:track_event)
    end

    context 'when token isnt stored in session' do
      it 'redirects to the clean edit password url with token stored in session' do
        get :edit, params: { reset_password_token: 'foo' }
        expect(response).to redirect_to(edit_user_password_url)
        expect(session[:reset_password_token]).to eq('foo')
      end
    end

    context 'no user matches token' do
      let(:token) { 'foo' }
      before do
        session[:reset_password_token] = token
      end
      let(:analytics_hash) do
        {
          success: false,
          errors: { user: ['invalid_token'] },
          error_details: { user: { blank: true } },
          user_id: nil,
        }
      end

      it 'redirects to page where user enters email for password reset token' do
        expect(@irs_attempts_api_tracker).to receive(:forgot_password_email_confirmed).with(
          success: false,
          failure_reason: { user: { blank: true } },
        )

        get :edit

        expect(@analytics).to have_received(:track_event).
          with('Password Reset: Token Submitted', analytics_hash)
        expect(response).to redirect_to new_user_password_path
        expect(flash[:error]).to eq t('devise.passwords.invalid_token')
      end
    end

    context 'token expired' do
      let(:token) { 'foo' }
      before do
        session[:reset_password_token] = token
      end
      let(:analytics_hash) do
        {
          success: false,
          errors: { user: ['token_expired'] },
          error_details: { user: { token_expired: true } },
          user_id: '123',
        }
      end
      let(:user) { instance_double('User', uuid: '123') }

      before do
        allow(User).to receive(:with_reset_password_token).with(token).and_return(user)
        allow(User).to receive(:with_reset_password_token).with('bar').and_return(nil)
        allow(user).to receive(:reset_password_period_valid?).and_return(false)
      end

      context 'no user matches token' do
        let(:analytics_hash) do
          {
            success: false,
            errors: { user: ['invalid_token'] },
            error_details: { user: { blank: true } },
            user_id: nil,
          }
        end

        before do
          session[:reset_password_token] = 'bar'
        end

        it 'redirects to page where user enters email for password reset token' do
          expect(@irs_attempts_api_tracker).to receive(:forgot_password_email_confirmed).with(
            success: false,
            failure_reason: { user: { blank: true } },
          )

          get :edit

          expect(@analytics).to have_received(:track_event).
            with('Password Reset: Token Submitted', analytics_hash)
          expect(response).to redirect_to new_user_password_path
          expect(flash[:error]).to eq t('devise.passwords.invalid_token')
        end
      end

      context 'token expired' do
        let(:analytics_hash) do
          {
            success: false,
            errors: { user: ['token_expired'] },
            error_details: { user: { token_expired: true } },
            user_id: '123',
          }
        end
        let(:user) { instance_double('User', uuid: '123') }

        before do
          allow(User).to receive(:with_reset_password_token).with('foo').and_return(user)
          allow(user).to receive(:reset_password_period_valid?).and_return(false)
        end

        it 'redirects to page where user enters email for password reset token' do
          expect(@irs_attempts_api_tracker).to receive(:forgot_password_email_confirmed).with(
            success: false,
            failure_reason: { user: { token_expired: true } },
          )

          get :edit

          expect(@analytics).to have_received(:track_event).
            with('Password Reset: Token Submitted', analytics_hash)
          expect(response).to redirect_to new_user_password_path
          expect(flash[:error]).to eq t('devise.passwords.token_expired')
        end
      end

      context 'token is valid' do
        render_views
        let(:user) { instance_double('User', uuid: '123') }
        let(:email_address) { instance_double('EmailAddress') }

        before do
          stub_analytics
          allow(User).to receive(:with_reset_password_token).with('foo').and_return(user)
          allow(user).to receive(:reset_password_period_valid?).and_return(true)
          allow(user).to receive(:email_addresses).and_return([email_address])
        end

        it 'displays the form to enter a new password and disallows indexing' do
          expect(email_address).to receive(:email).twice

          forbidden = instance_double(ForbiddenPasswords)
          allow(ForbiddenPasswords).to receive(:new).with(email_address.email).and_return(forbidden)
          expect(forbidden).to receive(:call)

          expect(@irs_attempts_api_tracker).to receive(:forgot_password_email_confirmed).with(
            success_properties,
          )

          get :edit

          expect(response).to render_template :edit
          expect(flash.keys).to be_empty
          expect(response.body).to match('<meta content="noindex,nofollow" name="robots" />')
        end
      end
    end

    context 'when token is valid' do
      before do
        allow(User).to receive(:with_reset_password_token).with('foo').and_return(user)
        allow(user).to receive(:reset_password_period_valid?).and_return(true)
        allow(user).to receive(:email_addresses).and_return([email_address])
        session[:reset_password_token] = 'foo'
      end
      it 'renders the template to the clean edit password url with token stored in session' do
        expect(email_address).to receive(:email).twice

        forbidden = instance_double(ForbiddenPasswords)
        allow(ForbiddenPasswords).to receive(:new).
          with(email_address.email).and_return(forbidden)
        expect(forbidden).to receive(:call)

        get :edit
        expect(response).to render_template :edit
        expect(flash.keys).to be_empty
      end
    end
  end

  describe '#update' do
    context 'user submits new password after token expires' do
      it 'redirects to page where user enters email for password reset token' do
        stub_analytics
        stub_attempts_tracker
        allow(@analytics).to receive(:track_event)

        expect(@irs_attempts_api_tracker).to receive(:forgot_password_new_password_submitted).with(
          success: false,
          failure_reason: {
            password: { too_short: true },
            password_confirmation: { too_short: true },
            reset_password_token: { token_expired: true },
          },
        )

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)
        user = create(
          :user,
          :fully_registered,
          reset_password_sent_at: Time.zone.now - Devise.reset_password_within - 1.hour,
          reset_password_token: db_confirmation_token,
        )

        params = {
          password: 'short',
          password_confirmation: 'short',
          reset_password_token: raw_reset_token,
        }

        get :edit, params: { reset_password_token: raw_reset_token }
        put :update, params: { reset_password_form: params }

        analytics_hash = {
          success: false,
          errors: {
            password: [password_error_message],
            password_confirmation: [t(
              'errors.messages.too_short.other',
              count: Devise.password_length.first,
            )],
            reset_password_token: ['token_expired'],
          },
          error_details: {
            password: { too_short: true },
            password_confirmation: { too_short: true },
            reset_password_token: { token_expired: true },
          },
          user_id: user.uuid,
          profile_deactivated: false,
          pending_profile_invalidated: false,
          pending_profile_pending_reasons: '',
        }

        expect(@analytics).to have_received(:track_event).
          with('Password Reset: Password Submitted', analytics_hash)
        expect(response).to redirect_to new_user_password_path
        expect(flash[:error]).to eq t('devise.passwords.token_expired')
      end
    end

    context 'user submits invalid new password' do
      let(:password) { 'short' }
      let(:password_confirmation) { 'short' }

      it 'renders edit' do
        stub_analytics
        stub_attempts_tracker

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)
        user = create(
          :user,
          :fully_registered,
          reset_password_token: db_confirmation_token,
          reset_password_sent_at: Time.zone.now,
        )
        form_params = {
          password: password,
          password_confirmation: password_confirmation,
          reset_password_token: raw_reset_token,
        }
        analytics_hash = {
          success: false,
          errors: {
            password: [password_error_message],
            password_confirmation: [t(
              'errors.messages.too_short.other',
              count: Devise.password_length.first,
            )],
          },
          error_details: {
            password: { too_short: true },
            password_confirmation: { too_short: true },
          },
          user_id: user.uuid,
          profile_deactivated: false,
          pending_profile_invalidated: false,
          pending_profile_pending_reasons: '',
        }

        expect(@analytics).to receive(:track_event).
          with('Password Reset: Password Submitted', analytics_hash)
        expect(@irs_attempts_api_tracker).to receive(:forgot_password_new_password_submitted).with(
          success: false,
          failure_reason: {
            password: { too_short: true },
            password_confirmation: { too_short: true },
          },
        )

        put :update, params: { reset_password_form: form_params }

        expect(assigns(:forbidden_passwords)).to all(be_a(String))
        expect(response).to render_template(:edit)
      end
    end

    context 'user submits password confirmation that does not match' do
      let(:password) { 'salty pickles' }
      let(:password_confirmation) { 'salty pickles2' }

      it 'renders edit' do
        stub_analytics
        stub_attempts_tracker

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)
        user = create(
          :user,
          :fully_registered,
          reset_password_token: db_confirmation_token,
          reset_password_sent_at: Time.zone.now,
        )
        form_params = {
          password: password,
          password_confirmation: password_confirmation,
          reset_password_token: raw_reset_token,
        }
        analytics_hash = {
          success: false,
          errors: {
            password_confirmation: [t('errors.messages.password_mismatch')],
          },
          error_details: {
            password_confirmation: { mismatch: true },
          },
          user_id: user.uuid,
          profile_deactivated: false,
          pending_profile_invalidated: false,
          pending_profile_pending_reasons: '',
        }

        expect(@analytics).to receive(:track_event).
          with('Password Reset: Password Submitted', analytics_hash)
        expect(@irs_attempts_api_tracker).to receive(:forgot_password_new_password_submitted).with(
          success: false,
          failure_reason: {
            password_confirmation: { mismatch: true },
          },
        )

        put :update, params: { reset_password_form: form_params }

        expect(assigns(:forbidden_passwords)).to all(be_a(String))
        expect(response).to render_template(:edit)
      end
    end

    context 'user submits the reset password form twice' do
      let(:password) { 'a really long passw0rd' }

      it 'shows an invalid token error' do
        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)
        create(
          :user,
          :unconfirmed,
          reset_password_token: db_confirmation_token,
          reset_password_sent_at: Time.zone.now,
        )
        form_params = {
          password: password,
          password_confirmation: password,
          reset_password_token: raw_reset_token,
        }

        put :update, params: { reset_password_form: form_params }
        put :update, params: { reset_password_form: form_params }

        expect(response).to redirect_to new_user_password_path
        expect(flash[:error]).to eq t('devise.passwords.invalid_token')
      end
    end

    context 'IAL1 user submits valid new password' do
      let(:password) { 'a really long passw0rd' }

      it 'redirects to sign in page' do
        stub_analytics
        stub_attempts_tracker
        allow(@analytics).to receive(:track_event)

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)

        freeze_time do
          user = create(
            :user,
            :fully_registered,
            reset_password_token: db_confirmation_token,
            reset_password_sent_at: Time.zone.now,
          )
          old_confirmed_at = user.reload.confirmed_at
          allow(user).to receive(:active_profile).and_return(nil)

          security_event = PushNotification::PasswordResetEvent.new(user: user)
          expect(PushNotification::HttpPush).to receive(:deliver).with(security_event)

          stub_user_mailer(user)

          expect(@irs_attempts_api_tracker).to receive(
            :forgot_password_new_password_submitted,
          ).with(success_properties)

          params = {
            password: password,
            password_confirmation: password,
            reset_password_token: raw_reset_token,
          }

          get :edit, params: { reset_password_token: raw_reset_token }
          put :update, params: { reset_password_form: params }

          analytics_hash = {
            success: true,
            errors: {},
            user_id: user.uuid,
            profile_deactivated: false,
            pending_profile_invalidated: false,
            pending_profile_pending_reasons: '',
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
      let(:password) { 'a really long passw0rd' }

      it 'deactivates the active profile and redirects' do
        stub_analytics
        stub_attempts_tracker
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

        expect(@irs_attempts_api_tracker).to receive(:forgot_password_new_password_submitted).with(
          success_properties,
        )

        get :edit, params: { reset_password_token: raw_reset_token }
        params = {
          password: password,
          password_confirmation: password,
          reset_password_token: raw_reset_token,
        }

        put :update, params: { reset_password_form: params }

        analytics_hash = {
          success: true,
          errors: {},
          user_id: user.uuid,
          profile_deactivated: true,
          pending_profile_invalidated: false,
          pending_profile_pending_reasons: '',
        }

        expect(@analytics).to have_received(:track_event).
          with('Password Reset: Password Submitted', analytics_hash)
        expect(user.active_profile.present?).to eq false
        expect(response).to redirect_to new_user_session_path
      end
    end

    context 'unconfirmed user submits valid new password' do
      let(:password) { 'a really long passw0rd' }

      it 'confirms the user' do
        stub_analytics
        stub_attempts_tracker
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

        expect(@irs_attempts_api_tracker).to receive(:forgot_password_new_password_submitted).with(
          success_properties,
        )

        params = {
          password: password,
          password_confirmation: password,
          reset_password_token: raw_reset_token,
        }

        get :edit, params: { reset_password_token: raw_reset_token }
        put :update, params: { reset_password_form: params }

        analytics_hash = {
          success: true,
          errors: {},
          user_id: user.uuid,
          profile_deactivated: false,
          pending_profile_invalidated: false,
          pending_profile_pending_reasons: '',
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

        expect(@irs_attempts_api_tracker).to receive(:user_registration_email_submitted).with(
          email: email,
          **success_properties,
        )

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
          rate_limited: false,
          errors: {},
          email_already_exists: false,
          user_id: User.find_with_email(email).uuid,
          domain_name: 'example.com',
        }
        expect(@analytics).to have_logged_event(
          'User Registration: Email Submitted',
          analytics_hash,
        )
        expect(response).to redirect_to forgot_password_path
      end
    end

    context 'user exists' do
      let(:email) { 'test@example.com' }
      let(:email_param) { { email: email } }
      let!(:user) { create(:user, :fully_registered, **email_param) }
      let(:analytics_hash) do
        {
          success: true,
          errors: {},
          user_id: user.uuid,
          confirmed: true,
          active_profile: false,
        }
      end

      before do
        stub_analytics
        stub_attempts_tracker
        allow(@analytics).to receive(:track_event)
      end

      it 'sends password reset email to user and tracks event' do
        expect(@irs_attempts_api_tracker).to receive(:forgot_password_email_sent).with(
          **email_param,
        )

        expect do
          put :create, params: { password_reset_email_form: email_param }
        end.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(@analytics).to have_received(:track_event).
          with('Password Reset: Email Submitted', analytics_hash)
        expect(response).to redirect_to forgot_password_path
      end
    end

    context 'user exists but is unconfirmed' do
      let(:user) { create(:user, :unconfirmed) }
      let(:analytics_hash) do
        {
          success: true,
          errors: {},
          user_id: user.uuid,
          confirmed: false,
          active_profile: false,
        }
      end
      let(:params) do
        {
          password_reset_email_form: {
            email: user.email,
          },
        }
      end

      before do
        stub_analytics
        stub_attempts_tracker
        allow(@analytics).to receive(:track_event)
      end

      it 'sends password reset email to user and tracks event' do
        expect(@irs_attempts_api_tracker).to receive(:forgot_password_email_sent).with(
          email: user.email,
        )

        expect { put :create, params: params }.
          to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(@analytics).to have_received(:track_event).
          with('Password Reset: Email Submitted', analytics_hash)

        expect(ActionMailer::Base.deliveries.last.subject).
          to eq t('user_mailer.reset_password_instructions.subject')
        expect(response).to redirect_to forgot_password_path
      end
    end

    context 'user is verified' do
      it 'captures in analytics that the user was verified' do
        stub_analytics
        stub_attempts_tracker

        user = create(:user, :fully_registered)
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
        expect(@irs_attempts_api_tracker).to receive(:forgot_password_email_sent).with(
          email: user.email,
        )

        params = { password_reset_email_form: { email: user.email } }
        put :create, params: params
      end
    end

    context 'email is invalid' do
      it 'displays an error and tracks event' do
        stub_analytics

        analytics_hash = {
          success: false,
          errors: { email: [t('valid_email.validations.email.invalid')] },
          error_details: { email: { invalid: true } },
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
