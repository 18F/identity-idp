require 'rails_helper'

include Features::LocalizationHelper
include Features::MailerHelper

describe Users::EditPasswordController do
  def stub_email_notifier(user)
    email_notifier = instance_double(EmailNotifier)
    allow(EmailNotifier).to receive(:new).with(user).and_return(email_notifier)

    expect(email_notifier).to receive(:send_password_changed_email)
  end

  describe '#update' do
    context 'form returns success' do
      it 'redirects to profile and sends a password change email' do
        stub_sign_in

        user = controller.current_user

        stub_analytics
        allow(@analytics).to receive(:track_event)

        stub_email_notifier(user)

        params = { password: 'salty new password', current_password: user.password }
        patch :update, update_user_password_form: params

        expect(@analytics).to have_received(:track_event).
          with(Analytics::PASSWORD_CHANGED, success: true, errors: [])
        expect(response).to redirect_to profile_url
        expect(flash[:notice]).to eq t('notices.password_changed')
      end

      it 're-encrypts PII on active profile' do
        user = stub_sign_in
        profile = build(:profile, :active, user: user, pii: { ssn: '1234' })
        allow(user).to receive(:active_profile).and_return(profile)

        new_password = 'salty new password'
        old_password = user.password
        old_user_access_key = user.unlock_user_access_key(old_password)

        cacher = Pii::Cacher.new(user, controller.user_session)
        cacher.save(old_user_access_key, profile)

        stub_email_notifier(user)

        params = { password: new_password, current_password: user.password }
        patch :update, update_user_password_form: params

        new_user_access_key = user.unlock_user_access_key(new_password)

        expect(flash[:recovery_code]).to be_present
        expect(profile.decrypt_pii(new_user_access_key)).to be_a Pii::Attributes
        expect(profile.decrypt_pii(new_user_access_key).ssn).to eq '1234'
        expect do
          profile.decrypt_pii(old_user_access_key)
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
          with(Analytics::PASSWORD_CHANGED, success: false, errors: errors)
        expect(response).to render_template(:edit)
      end
    end
  end
end
