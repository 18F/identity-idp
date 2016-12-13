require 'rails_helper'

describe Users::ResetPasswordsController, devise: true do
  describe '#edit' do
    context 'no user matches token' do
      it 'redirects to page where user enters email for password reset token' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        get :edit, reset_password_token: 'foo'

        analytics_hash = {
          success: false,
          error: 'invalid_token',
          user_id: nil
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

        get :edit, reset_password_token: 'foo'

        analytics_hash = {
          success: false,
          error: 'token_expired',
          user_id: '123'
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

        get :edit, reset_password_token: 'foo'

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

        user = create(
          :user,
          :signed_up,
          reset_password_sent_at: Time.current - Devise.reset_password_within - 1.hour
        )

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)
        user.update(reset_password_token: db_confirmation_token)

        params = { password: 'short', reset_password_token: raw_reset_token }

        put :update, reset_password_form: params

        analytics_hash = {
          success: false,
          errors: ['is too short (minimum is 8 characters)', 'token_expired'],
          user_id: user.uuid,
          active_profile: false
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
        allow(@analytics).to receive(:track_event)

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)
        user = create(
          :user,
          :signed_up,
          reset_password_token: db_confirmation_token,
          reset_password_sent_at: Time.current
        )

        params = { password: 'short', reset_password_token: raw_reset_token }
        put :update, reset_password_form: params

        analytics_hash = {
          success: false,
          errors: ['is too short (minimum is 8 characters)'],
          user_id: user.uuid,
          active_profile: false
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_PASSWORD, analytics_hash)

        expect(response).to render_template(:edit)
      end
    end

    context 'LOA1 user submits valid new password' do
      it 'redirects to sign in page' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)
        user = create(
          :user,
          :signed_up,
          reset_password_token: db_confirmation_token,
          reset_password_sent_at: Time.current
        )
        allow(user).to receive(:active_profile).and_return(nil)

        stub_email_notifier(user)

        password = 'a really long passw0rd'
        params = { password: password, reset_password_token: raw_reset_token }
        put :update, reset_password_form: params

        analytics_hash = {
          success: true,
          errors: [],
          user_id: user.uuid,
          active_profile: false
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_PASSWORD, analytics_hash)

        expect(response).to redirect_to new_user_session_path
        expect(flash[:notice]).to eq t('devise.passwords.updated_not_active')
      end
    end

    context 'LOA3 user submits valid new password' do
      it 'deactivates the active profile and redirects' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        raw_reset_token, db_confirmation_token =
          Devise.token_generator.generate(User, :reset_password_token)

        profile = create(:profile, :active, :verified)
        user = profile.user
        user.update(
          reset_password_token: db_confirmation_token,
          reset_password_sent_at: Time.current
        )

        stub_email_notifier(user)

        password = 'a really long passw0rd'
        params = { password: password, reset_password_token: raw_reset_token }

        put :update, reset_password_form: params

        analytics_hash = {
          success: true,
          errors: [],
          user_id: user.uuid,
          active_profile: true
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_PASSWORD, analytics_hash)

        expect(user.active_profile.present?).to eq false

        expect(response).to redirect_to new_user_session_path
      end
    end
  end

  describe '#create' do
    context 'no user matches email' do
      it 'tracks event using anonymous user' do
        stub_analytics

        nonexistent_user = instance_double(NonexistentUser, uuid: '123', role: 'nonexistent')
        allow(NonexistentUser).to receive(:new).and_return(nonexistent_user)

        expect(@analytics).to receive(:track_event).
          with(Analytics::PASSWORD_RESET_EMAIL,
               user_id: nonexistent_user.uuid, role: nonexistent_user.role)

        put :create, user: { email: 'nonexistent@example.com' }
      end
    end

    context 'matched email belongs to a tech support user' do
      it 'tracks event using tech user' do
        stub_analytics

        tech_user = build_stubbed(:user, :tech_support)
        fingerprint = Pii::Fingerprinter.fingerprint('tech@example.com')
        allow(User).to receive(:find_by).with(email_fingerprint: fingerprint).and_return(tech_user)

        expect(@analytics).to receive(:track_event).
          with(Analytics::PASSWORD_RESET_EMAIL, user_id: tech_user.uuid, role: 'tech')

        put :create, user: { email: 'TECH@example.com' }
      end
    end

    context 'matched email belongs to an admin user' do
      it 'tracks event using admin user' do
        stub_analytics

        admin = build_stubbed(:user, :admin)
        fingerprint = Pii::Fingerprinter.fingerprint('admin@example.com')
        allow(User).to receive(:find_by).with(email_fingerprint: fingerprint).and_return(admin)

        expect(@analytics).to receive(:track_event).
          with(Analytics::PASSWORD_RESET_EMAIL, user_id: admin.uuid, role: 'admin')

        put :create, user: { email: 'ADMIN@example.com' }
      end
    end
  end

  def stub_email_notifier(user)
    notifier = instance_double(EmailNotifier)
    allow(EmailNotifier).to receive(:new).with(user).and_return(notifier)
    expect(notifier).to receive(:send_password_changed_email)
  end
end
