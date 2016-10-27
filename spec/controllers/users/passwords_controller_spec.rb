require 'rails_helper'

describe Users::PasswordsController, devise: true do
  describe '#edit' do
    context 'no user matches token' do
      it 'redirects to page where user enters email for password reset token' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        get :edit, reset_password_token: 'foo'

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_INVALID_TOKEN, token: 'foo')

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

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_TOKEN_EXPIRED, user_id: user.uuid)

        expect(response).to redirect_to new_user_password_path
        expect(flash[:error]).to eq t('devise.passwords.token_expired')
      end
    end

    context 'token is valid' do
      it 'displays the form to enter a new password' do
        stub_analytics

        user = instance_double('User', email: 'test@test1.com')
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

        params = { password: 'password', reset_password_token: 'foo' }

        user = instance_double('User', uuid: '123', email: 'test1@test.com')
        allow(User).to receive(:reset_password_by_token).with(params).and_return(user)
        allow(user).to receive(:reset_password_token).and_return('foo')
        allow(user).to receive(:errors).and_return(reset_password_token: 'token expired')

        put :update, password_form: params

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_TOKEN_EXPIRED, user_id: user.uuid)

        expect(response).to redirect_to new_user_password_path
        expect(flash[:error]).to eq t('devise.passwords.token_expired')
      end
    end

    context 'user submits invalid new password' do
      it 'renders edit' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        params = { password: 'pass', reset_password_token: 'foo' }

        user = instance_double('User', uuid: '123')
        allow(User).to receive(:reset_password_by_token).with(params).and_return(user)
        allow(user).to receive(:reset_password_token).and_return('foo')
        allow(user).to receive(:errors).and_return({})

        put :update, password_form: params

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_INVALID_PASSWORD, user_id: user.uuid)

        expect(response).to render_template(:edit)
      end
    end

    context 'LOA1 user submits valid new password' do
      it 'redirects to sign in page' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        password = 'a really long passw0rd'
        token = 'foo'
        params = { password: password, reset_password_token: token }

        user = User.new(reset_password_token: token)
        allow(User).to receive(:reset_password_by_token).with(params).and_return(user)
        allow(user).to receive(:active_profile).and_return(nil)

        stub_email_notifier(user)

        put :update, password_form: params

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_SUCCESSFUL, user_id: user.uuid)

        expect(response).to redirect_to new_user_session_path
        expect(flash[:notice]).to eq t('devise.passwords.updated_not_active')
      end
    end

    context 'LOA3 user submits valid new password' do
      it 'deactivates the active profile and redirects' do
        stub_analytics
        allow(@analytics).to receive(:track_event)

        password = 'a really long passw0rd'
        token = 'foo'
        params = { password: password, reset_password_token: token }

        profile = create(:profile, :active, :verified)
        user = profile.user
        user.reset_password_token = token

        stub_email_notifier(user)

        allow(User).to receive(:reset_password_by_token).with(params).and_return(user)

        put :update, password_form: params

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_SUCCESSFUL, user_id: user.uuid)
        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_RESET_DEACTIVATED_ACCOUNT, user_id: user.uuid)

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
          with(Analytics::PASSWORD_RESET_REQUEST,
               user_id: nonexistent_user.uuid, role: nonexistent_user.role)

        put :create, user: { email: 'nonexistent@example.com' }
      end
    end

    context 'matched email belongs to a tech support user' do
      it 'tracks event using tech user' do
        stub_analytics

        tech_user = build_stubbed(:user, :tech_support)
        allow(User).to receive(:find_by_email).with('tech@example.com').and_return(tech_user)

        expect(@analytics).to receive(:track_event).
          with(Analytics::PASSWORD_RESET_REQUEST, user_id: tech_user.uuid, role: 'tech')

        put :create, user: { email: 'TECH@example.com' }
      end
    end

    context 'matched email belongs to an admin user' do
      it 'tracks event using admin user' do
        stub_analytics

        admin = build_stubbed(:user, :admin)
        allow(User).to receive(:find_by_email).with('admin@example.com').and_return(admin)

        expect(@analytics).to receive(:track_event).
          with(Analytics::PASSWORD_RESET_REQUEST, user_id: admin.uuid, role: 'admin')

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
