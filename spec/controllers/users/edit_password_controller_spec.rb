require 'rails_helper'

include Features::LocalizationHelper
include Features::MailerHelper

describe Users::EditPasswordController do
  describe '#update' do
    context 'form returns success' do
      it 'redirects to profile and sends a password change email' do
        stub_sign_in

        user = controller.current_user

        stub_analytics
        allow(@analytics).to receive(:track_event)

        email_notifier = instance_double(EmailNotifier)
        allow(EmailNotifier).to receive(:new).with(user).and_return(email_notifier)

        expect(email_notifier).to receive(:send_password_changed_email)

        params = { password: 'new password', current_password: ControllerHelper::VALID_PASSWORD }
        patch :update, update_user_password_form: params

        expect(@analytics).to have_received(:track_event).
          with(:password_change, success?: true, errors: [])
        expect(response).to redirect_to profile_url
        expect(flash[:notice]).to eq t('notices.password_changed')
      end
    end

    context 'form returns failure' do
      it 'renders edit' do
        stub_sign_in

        stub_analytics
        allow(@analytics).to receive(:track_event)

        expect(EmailNotifier).to_not receive(:new)

        params = { password: 'new', current_password: 'current password' }
        patch :update, update_user_password_form: params

        errors = [
          "Password #{t('errors.messages.too_short.other', count: Devise.password_length.first)}",
          "Current password #{t('errors.incorrect_password')}"
        ]

        expect(@analytics).to have_received(:track_event).
          with(:password_change, success?: false, errors: errors)
        expect(response).to render_template(:edit)
      end
    end
  end
end
