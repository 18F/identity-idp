require 'rails_helper'

describe Users::ResetPasswordsController, devise: true do
  describe '#edit' do
    context 'no user matches token' do
      it 'redirects to page where user enters email for password reset token' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        get :edit, params: { reset_password_token: 'foo' }

        analytics_hash = {
          success: false,
          errors: { user: ['invalid_token'] },
          user_id: nil,
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_TOKEN, analytics_hash)

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
          user_id: '123',
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_TOKEN, analytics_hash)

        expect(response).to redirect_to new_user_password_path
        expect(flash[:error]).to eq t('devise.passwords.token_expired')
      end
    end

    context 'token is valid' do
      it 'displays the form to enter a new password' do
        stub_analytics

        user = instance_double('User', uuid: '123')
        allow(User).to receive(:with_reset_password_token).with('foo').and_return(user)
        allow(user).to receive(:reset_password_period_valid?).and_return(true)

        get :edit, params: { reset_password_token: 'foo' }

        expect(response).to render_template :edit
        expect(flash.keys).to be_empty
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
          reset_password_token: db_confirmation_token
        )

        params = { password: 'short', reset_password_token: raw_reset_token }

        put :update, params: { reset_password_form: params }

        analytics_hash = {
          success: false,
          errors: {
            password: ['is too short (minimum is 8 characters)'],
            reset_password_token: ['token_expired'],
          },
          user_id: user.uuid,
          active_profile: false,
          confirmed: true,
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_PASSWORD, analytics_hash)

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
          reset_password_sent_at: Time.zone.now
        )
        form_params = { password: 'short', reset_password_token: raw_reset_token }
        analytics_hash = {
          success: false,
          errors: { password: ['is too short (minimum is 8 characters)'] },
          user_id: user.uuid,
          active_profile: false,
          confirmed: true,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::PASSWORD_RESET_PASSWORD, analytics_hash)

        put :update, params: { reset_password_form: form_params }

        expect(response).to render_template(:edit)
      end
    end

    context 'LOA1 user submits valid new password' do
      it 'redirects to sign in page' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)

        Timecop.freeze(Time.zone.now) do
          user = create(
            :user,
            :signed_up,
            reset_password_token: db_confirmation_token,
            reset_password_sent_at: Time.zone.now
          )
          old_confirmed_at = user.reload.confirmed_at
          allow(user).to receive(:active_profile).and_return(nil)

          stub_email_notifier(user)

          password = 'a really long passw0rd'
          params = { password: password, reset_password_token: raw_reset_token }

          put :update, params: { reset_password_form: params }

          analytics_hash = {
            success: true,
            errors: {},
            user_id: user.uuid,
            active_profile: false,
            confirmed: true,
          }

          expect(@analytics).to have_received(:track_event).
            with(Analytics::PASSWORD_RESET_PASSWORD, analytics_hash)

          expect(response).to redirect_to new_user_session_path
          expect(flash[:notice]).to eq t('devise.passwords.updated_not_active')
          expect(user.reload.confirmed_at).to eq old_confirmed_at
        end
      end
    end

    context 'LOA3 user submits valid new password' do
      it 'deactivates the active profile and redirects' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)
        user = create(
          :user,
          reset_password_token: db_confirmation_token,
          reset_password_sent_at: Time.zone.now
        )
        _profile = create(:profile, :active, :verified, user: user)

        stub_email_notifier(user)

        password = 'a really long passw0rd'
        params = { password: password, reset_password_token: raw_reset_token }

        put :update, params: { reset_password_form: params }

        analytics_hash = {
          success: true,
          errors: {},
          user_id: user.uuid,
          active_profile: true,
          confirmed: true,
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_PASSWORD, analytics_hash)

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
          reset_password_sent_at: Time.zone.now
        )

        stub_email_notifier(user)

        password = 'a really long passw0rd'
        params = { password: password, reset_password_token: raw_reset_token }

        put :update, params: { reset_password_form: params }

        analytics_hash = {
          success: true,
          errors: {},
          user_id: user.uuid,
          active_profile: false,
          confirmed: false,
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_PASSWORD, analytics_hash)

        expect(user.reload.confirmed?).to eq true

        expect(response).to redirect_to new_user_session_path
      end
    end
  end

  describe '#create' do
    context 'no user matches email' do
      it 'redirects to forgot_password_path to prevent revealing account existence ' \
        'and tracks event using nonexistent user' do
        stub_analytics

        analytics_hash = {
          success: true,
          errors: {},
          user_id: 'nonexistent-uuid',
          role: 'nonexistent',
          confirmed: false,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::PASSWORD_RESET_EMAIL, analytics_hash)

        expect do
          put :create, params: {
            password_reset_email_form: { email: 'nonexistent@example.com' },
          }
        end.to_not(change { ActionMailer::Base.deliveries.count })

        expect(response).to redirect_to forgot_password_path
      end
    end

    context 'matched email belongs to a tech support user' do
      it 'tracks event using tech user' do
        stub_analytics

        tech_user = build_stubbed(:user, :tech_support)
        allow(User).to receive(:find_with_email).with(tech_user.email).and_return(tech_user)

        analytics_hash = {
          success: true,
          errors: {},
          user_id: tech_user.uuid,
          role: 'tech',
          confirmed: true,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::PASSWORD_RESET_EMAIL, analytics_hash)

        expect { put :create, params: { password_reset_email_form: { email: tech_user.email } } }.
          to change { ActionMailer::Base.deliveries.count }.by(0)

        expect(response).to redirect_to forgot_password_path
      end
    end

    context 'matched email belongs to an admin user' do
      it 'tracks event using admin user' do
        stub_analytics

        admin = build_stubbed(:user, :admin)
        allow(User).to receive(:find_with_email).with(admin.email).and_return(admin)

        analytics_hash = {
          success: true,
          errors: {},
          user_id: admin.uuid,
          role: 'admin',
          confirmed: true,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::PASSWORD_RESET_EMAIL, analytics_hash)

        expect { put :create, params: { password_reset_email_form: { email: admin.email } } }.
          to change { ActionMailer::Base.deliveries.count }.by(0)

        expect(response).to redirect_to forgot_password_path
      end
    end

    context 'user exists' do
      it 'sends password reset email to user and tracks event' do
        stub_analytics

        user = build(:user, :signed_up, role: :user, email: 'test@example.com')

        analytics_hash = {
          success: true,
          errors: {},
          user_id: user.uuid,
          role: 'user',
          confirmed: true,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::PASSWORD_RESET_EMAIL, analytics_hash)

        expect do
          put :create, params: { password_reset_email_form: { email: 'Test@example.com' } }
        end.to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(response).to redirect_to forgot_password_path
      end
    end

    context 'user exists but is unconfirmed' do
      it 'sends password reset email to user and tracks event' do
        stub_analytics

        user = create(:user, :unconfirmed, role: :user)

        analytics_hash = {
          success: true,
          errors: {},
          user_id: user.uuid,
          role: 'user',
          confirmed: false,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::PASSWORD_RESET_EMAIL, analytics_hash)

        expect { put :create, params: { password_reset_email_form: { email: user.email } } }.
          to change { ActionMailer::Base.deliveries.count }.by(1)

        expect(ActionMailer::Base.deliveries.last.subject).
          to eq t('devise.mailer.reset_password_instructions.subject')

        expect(response).to redirect_to forgot_password_path
      end
    end

    context 'email is invalid' do
      it 'displays an error and tracks event' do
        stub_analytics

        analytics_hash = {
          success: false,
          errors: { email: [t('valid_email.validations.email.invalid')] },
          user_id: 'nonexistent-uuid',
          role: 'nonexistent',
          confirmed: false,
        }

        expect(@analytics).to receive(:track_event).
          with(Analytics::PASSWORD_RESET_EMAIL, analytics_hash)

        expect { put :create, params: { password_reset_email_form: { email: 'foo' } } }.
          to change { ActionMailer::Base.deliveries.count }.by(0)

        expect(response).to render_template :new
      end
    end
  end

  def stub_email_notifier(user)
    notifier = instance_double(EmailNotifier)
    allow(EmailNotifier).to receive(:new).with(user).and_return(notifier)
    expect(notifier).to receive(:send_password_changed_email)
  end
end
