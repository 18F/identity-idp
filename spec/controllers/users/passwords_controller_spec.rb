require 'rails_helper'

include Features::LocalizationHelper
include Features::MailerHelper

describe Users::PasswordsController do
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
        updater = instance_double(UpdateUserPassword)
        password = 'strong password'
        allow(UpdateUserPassword).to receive(:new).
          with(user: subject.current_user, user_session: subject.user_session, password: password).
          and_return(updater)
        response = FormResponse.new(success: true, errors: {})
        allow(updater).to receive(:call).and_return(response)
        personal_key = 'five random words for test'
        allow(updater).to receive(:personal_key).and_return(personal_key)

        params = { password: password }
        patch :update, params: { update_user_password_form: params }

        expect(flash[:personal_key]).to eq personal_key
        expect(updater).to have_received(:call)
        expect(updater).to have_received(:personal_key)
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
    end
  end
end
