require 'rails_helper'

feature 'View personal key', js: true do
  include XPathHelper
  include PersonalKeyHelper
  include SamlAuthHelper

  let(:user) { create(:user, :signed_up, :with_personal_key) }

  context 'after sign up' do
    context 'regenerating personal key' do
      scenario 'displays new code and notifies the user' do
        sign_in_and_2fa_user(user)
        old_digest = user.encrypted_recovery_code_digest

        expect(Telephony).to receive(:send_personal_key_regeneration_notice).
          with(to: user.phone_configurations.first.phone, country_code: 'US')

        visit account_two_factor_authentication_path
        click_on(t('account.links.regenerate_personal_key'), match: :prefer_exact)
        click_continue

        expect(user.reload.encrypted_recovery_code_digest).to_not eq old_digest

        expect_delivered_email_count(1)
        expect_delivered_email(
          0, {
            to: [user.email_addresses.first.email],
            subject: t('user_mailer.personal_key_regenerated.subject'),
          }
        )
      end
    end

    context 'regenerating new code after canceling edit password action' do
      scenario 'displays new code' do
        sign_in_and_2fa_user(user)
        old_digest = user.encrypted_recovery_code_digest

        first(:link, t('forms.buttons.edit')).click
        click_on(t('links.cancel'))

        travel(IdentityConfig.store.reauthn_window + 1)

        visit account_two_factor_authentication_path
        click_on(t('account.links.regenerate_personal_key'), match: :prefer_exact)

        # reauthn
        fill_in t('account.index.password'), with: user.password
        click_continue
        fill_in_code_with_last_phone_otp
        click_submit_default

        expect(page).to have_content(t('account.personal_key.get_new'))
        click_continue

        expect(page).to have_content(t('forms.personal_key_partial.acknowledgement.header'))
        acknowledge_and_confirm_personal_key

        expect(user.reload.encrypted_recovery_code_digest).to_not eq old_digest
      end
    end
  end
end
