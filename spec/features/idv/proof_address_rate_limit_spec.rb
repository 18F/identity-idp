require 'rails_helper'

RSpec.feature 'address proofing rate limit' do
  include IdvStepHelper
  include IdvHelper

  context 'a user is phone rate limited' do
    scenario 'the user does not encounter an error until phone entry and can verify by mail', :js do
      user = user_with_2fa
      RateLimiter.new(user: user, rate_limit_type: :proof_address).increment_to_limited!

      start_idv_from_sp
      complete_idv_steps_before_phone_step(user)

      expect(current_path).to eq(idv_phone_errors_failure_path)

      click_on t('idv.failure.phone.rate_limited.gpo.button')
      click_on t('idv.buttons.mail.send')

      expect(page).to have_content(t('idv.titles.session.review', app_name: APP_NAME))
      expect(current_path).to eq(idv_review_path)
      fill_in 'Password', with: user.password
      click_idv_continue
      expect(page).to have_current_path(idv_letter_enqueued_path)
    end
  end

  context 'a user is mail limited' do
    scenario 'the user can verify by phone but does not have the mail option', :js do
      profile = create(
        :profile,
        :verify_by_mail_pending,
        :with_pii,
        :verification_cancelled,
        :letter_sends_rate_limited,
      )
      user = profile.user

      start_idv_from_sp
      complete_idv_steps_before_phone_step(user)

      # There should be no option to verify by mail on the phone input screen
      expect(page).to_not have_content(t('idv.troubleshooting.options.verify_by_mail'))

      fill_out_phone_form_fail
      click_idv_send_security_code

      # There should be no option to verify by mail on the warning page
      expect(current_path).to eq(idv_phone_errors_warning_path)
      expect(page).to_not have_content(t('idv.failure.phone.warning.gpo.button'))

      # Visiting the letter request URL should redirect to phone
      visit idv_request_letter_path
      expect(current_path).to eq(idv_phone_path)

      fill_out_phone_form_ok
      click_idv_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default

      expect(page).to have_content(t('idv.titles.session.review', app_name: APP_NAME))
      expect(current_path).to eq(idv_review_path)
      fill_in 'Password', with: user.password
      click_idv_continue
      expect(current_path).to eq(idv_personal_key_path)
      expect(user.reload.active_profile.present?).to eq(true)
    end
  end

  context 'a user is phone rate limited and mail rate limited', :js do
    scenario 'the user is not able to start proofing' do
      user = create(
        :profile,
        :verify_by_mail_pending,
        :with_pii,
        :verification_cancelled,
        :letter_sends_rate_limited,
      ).user
      RateLimiter.new(user: user, rate_limit_type: :proof_address).increment_to_limited!

      start_idv_from_sp
      sign_in_live_with_2fa(user)

      expect(current_path).to eq(idv_phone_errors_failure_path)
      expect(page).to_not have_content(t('idv.failure.phone.warning.gpo.button'))

      # Visiting the letter request URL should redirect to phone failure
      visit idv_request_letter_path
      expect(current_path).to eq(idv_phone_errors_failure_path)
    end
  end
end
