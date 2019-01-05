require 'rails_helper'

describe Users::PasswordsController do
  include Features::LocalizationHelper
  include Features::MailerHelper

  describe '#update' do
    context 'form returns success' do
      it 'redirects to profile and sends a password change email' do
        stub_sign_in
        stub_analytics
        allow(@analytics).to receive(:track_event)

        params = { password: 'salty new password' }
        patch :update, params: { update_user_password_form: params }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_CHANGED, success: true, errors: {})
        expect(response).to redirect_to account_url
        expect(flash[:notice]).to eq t('notices.password_changed')
        expect(flash[:personal_key]).to be_nil
      end

      it 'calls UpdateUserPassword' do
        stub_sign_in
        updater = instance_double(UpdateUserPasswordForm)
        password = 'strong password'
        allow(UpdateUserPasswordForm).to receive(:new).
          with(subject.current_user, subject.user_session).
          and_return(updater)
        response = FormResponse.new(success: true, errors: {})
        allow(updater).to receive(:submit).and_return(response)
        personal_key = 'five random words for test'
        allow(updater).to receive(:personal_key).and_return(personal_key)
        allow(controller).to receive(:create_user_event)

        params = { password: password }
        patch :update, params: { update_user_password_form: params }

        expect(flash[:personal_key]).to eq personal_key
        expect(updater).to have_received(:submit)
        expect(updater).to have_received(:personal_key)
      end

      it 'creates a user Event for the password change' do
        stub_sign_in

        expect(controller).to receive(:create_user_event)

        params = { password: 'salty new password' }
        patch :update, params: { update_user_password_form: params }
      end
    end

    context 'form returns failure' do
      it 'renders edit' do
        stub_sign_in

        stub_analytics
        allow(@analytics).to receive(:track_event)

        params = { password: 'new' }
        patch :update, params: { update_user_password_form: params }

        errors = {
          password: [
            t('errors.messages.too_short.other', count: Devise.password_length.first),
          ],
        }

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_CHANGED, success: false, errors: errors)
        expect(response).to render_template(:edit)
      end

      it 'does not create a password_changed user Event' do
        stub_sign_in

        expect(controller).to_not receive(:create_user_event)

        params = { password: 'new' }
        patch :update, params: { update_user_password_form: params }
      end
    end
  end
end
