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

        params = { password: 'salty new password', current_password: user.password }
        patch :update, update_user_password_form: params

        expect(@analytics).to have_received(:track_event).
          with(:password_change, success?: true, errors: [])
        expect(response).to redirect_to profile_url
        expect(flash[:notice]).to eq t('notices.password_changed')
      end

      it 're-encrypts PII on active profile' do
        stub_sign_in

        user = controller.current_user
        profile = create(:profile, :active, user: user, pii: { ssn: '1234' })

        old_password = user.password
        new_password = 'salty new password'

        cacher = Pii::Cacher.new(user, controller.user_session)
        cacher.save(old_password, profile)

        email_notifier = instance_double(EmailNotifier)
        allow(EmailNotifier).to receive(:new).with(user).and_return(email_notifier)

        expect(email_notifier).to receive(:send_password_changed_email)

        params = { password: new_password, current_password: old_password }
        patch :update, update_user_password_form: params

        profile.reload

        expect(profile.decrypt_pii(new_password)).to be_a Pii::Attributes
        expect(profile.decrypt_pii(new_password).ssn).to eq '1234'

        pending('actual encryption')
        expect do
          profile.decrypt_pii(old_password)
        end.to raise_error Pii::EncryptionError
      end
    end

    context 'form returns failure' do
      it 'renders edit' do
        stub_sign_in

        stub_analytics
        allow(@analytics).to receive(:track_event)

        expect(EmailNotifier).to_not receive(:new)

        params = { password: 'new' }
        patch :update, update_user_password_form: params

        errors = [
          "Password #{t('errors.messages.too_short.other', count: Devise.password_length.first)}"
        ]

        expect(@analytics).to have_received(:track_event).
          with(:password_change, success?: false, errors: errors)
        expect(response).to render_template(:edit)
      end
    end
  end
end
