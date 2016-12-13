require 'rails_helper'

feature 'IdV session' do
  include IdvHelper

  let(:user_password) { Features::SessionHelper::VALID_PASSWORD }

  context 'landing page' do
    before do
      sign_in_and_2fa_user
      visit verify_path
    end

    scenario 'decline to verify identity' do
      click_link t('idv.index.cancel_link')

      expect(page).to have_content(t('idv.titles.cancel'))
    end

    scenario 'proceed to verify identity' do
      click_link 'Yes'

      expect(page).to have_content(t('idv.titles.session.basic'))
    end
  end

  context 'KBV off' do
    before do
      allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(false)
    end

    scenario 'skips KBV' do
      user = sign_in_and_2fa_user

      visit verify_session_path

      fill_out_idv_form_ok
      click_button t('forms.buttons.continue')
      expect(page).to have_content(t('idv.form.ccn'))

      fill_out_financial_form_ok
      click_button t('forms.buttons.continue')
      fill_out_phone_form_ok(user.phone)
      click_button t('forms.buttons.continue')
      fill_in :user_password, with: user_password
      click_button t('forms.buttons.submit.default')

      expect(current_url).to eq verify_confirmations_url
      expect(page).to have_content(t('idv.titles.complete'))
      click_acknowledge_recovery_code

      expect(current_url).to eq(profile_url)
      expect(page).to have_content('Some One')
      expect(page).to have_content('123 Main St')
      expect(user.reload.active_profile).to be_a(Profile)
    end

    scenario 'allows 3 attempts in 24 hours' do
      user = sign_in_and_2fa_user

      2.times do
        visit verify_session_path
        complete_idv_profile_fail(user)

        expect(page).to have_content(t('idv.titles.fail'))
      end

      user.reload
      expect(user.idv_attempted_at).to_not be_nil

      visit destroy_user_session_url
      sign_in_and_2fa_user(user)

      visit verify_session_path
      complete_idv_profile_fail(user)

      expect(page).to have_content(t('idv.titles.hardfail'))

      visit verify_session_path

      expect(page).to have_content(t('idv.errors.hardfail'))
      expect(current_url).to eq verify_fail_url

      user.reload
      expect(user.idv_attempted_at).to_not be_nil
    end

    scenario 'steps are re-entrant and sticky' do
      _user = sign_in_and_2fa_user

      visit verify_session_path

      first_ssn_value = '666661234'
      second_ssn_value = '666669876'
      first_ccn_value = '12345678'
      second_ccn_value = '99998888'
      mortgage_value = '99990000'
      first_phone_value = '415-555-0199'
      first_phone_formatted = '+1 (415) 555-0199'
      second_phone_value = '456-789-0000'
      second_phone_formatted = '+1 (456) 789-0000'

      expect(page).to_not have_selector("input[value='#{first_ssn_value}']")

      fill_out_idv_form_ok
      click_button t('forms.buttons.continue')

      expect(page).to_not have_selector("input[value='#{first_ccn_value}']")

      fill_out_financial_form_ok
      click_button t('forms.buttons.continue')

      visit verify_session_path

      expect(page).to have_selector("input[value='#{first_ssn_value}']")

      fill_in 'profile_ssn', with: second_ssn_value
      click_button t('forms.buttons.continue')

      expect(current_url).to eq verify_finance_url
      expect(page).to have_content(t('idv.form.ccn'))
      expect(page).to have_selector("input[value='#{first_ccn_value}']")

      click_button t('forms.buttons.continue')

      visit verify_finance_path
      find('#idv_finance_form_finance_type_mortgage').set(true)
      fill_in :idv_finance_form_mortgage, with: mortgage_value
      click_button t('forms.buttons.continue')

      expect(current_url).to eq verify_phone_url

      visit verify_finance_path

      expect(page).to have_selector("input[value='#{mortgage_value}']")

      find('#idv_finance_form_finance_type_ccn').set(true)
      fill_in :idv_finance_form_ccn, with: second_ccn_value
      click_button t('forms.buttons.continue')

      expect(page).to_not have_selector("input[value='#{first_phone_formatted}']")

      fill_out_phone_form_ok(first_phone_value)
      click_button t('forms.buttons.continue')
      visit verify_phone_path

      expect(page).to have_selector("input[value='#{first_phone_formatted}']")

      fill_out_phone_form_ok(second_phone_value)
      click_button t('forms.buttons.continue')

      expect(page).to have_content(t('idv.titles.review'))
      expect(page).to have_content(second_ssn_value)
      expect(page).to_not have_content(first_ssn_value)
      expect(page).to have_content(second_ccn_value)
      expect(page).to_not have_content(mortgage_value)
      expect(page).to_not have_content(first_ccn_value)
      expect(page).to have_content(second_phone_formatted)
      expect(page).to_not have_content(first_phone_formatted)
    end

    scenario 'clicking finance option changes input label', js: true do
      _user = sign_in_and_2fa_user

      visit verify_session_path

      fill_out_idv_form_ok
      click_button 'Continue'

      expect(page).to have_css('.js-finance-wrapper', text: t('idv.form.mortgage'), visible: false)

      find('#idv_finance_form_finance_type_ccn', visible: false).trigger('click')

      expect(page).to have_css('.js-finance-wrapper', text: t('idv.form.mortgage'), visible: true)
      expect(page).to have_content(t('idv.form.ccn'))
    end

    context 'Idv phone and user phone are different' do
      it 'prompts to confirm phone' do
        user = sign_in_and_2fa_user
        visit verify_session_path

        complete_idv_profile_with_phone('416-555-0190')

        expect(page).to have_link t('forms.two_factor.try_again'), href: verify_phone_path
        expect(page).not_to have_css('.progress-steps')

        enter_correct_otp_code_for_user(user)
        click_acknowledge_recovery_code

        expect(current_path).to eq profile_path
      end
    end

    scenario 'recovery code presented on success' do
      recovery_code = 'a1b2c3d4e5f6g7h8'

      user = sign_in_and_2fa_user
      visit verify_session_path

      allow(SecureRandom).to receive(:hex).with(8).and_return(recovery_code)
      complete_idv_profile_ok(user)

      expect(page).to have_content(t('idv.titles.complete'))
      expect(page).to have_content(t('idv.messages.recovery_code'))
    end
  end

  context 'KBV on' do
    before do
      allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(true)
    end

    scenario 'KBV with all answers correct' do
      user = sign_in_and_2fa_user

      visit verify_session_path
      expect(page).to have_content(t('idv.form.first_name'))

      complete_idv_profile_ok(user)
      expect(page).to have_content('Where did you live')

      complete_idv_questions_ok

      expect(page).to have_content(t('idv.titles.complete'))

      click_acknowledge_recovery_code

      expect(current_url).to eq(profile_url)
      expect(user.reload.active_profile).to be_a(Profile)
      expect(user.active_profile.verified_at.present?).to eq true

      user_access_key = user.unlock_user_access_key(user_password)
      decrypted_pii = user.active_profile.decrypt_pii(user_access_key)
      expect(decrypted_pii.ssn).to eq '666661234'
    end

    scenario 'KBV with some incorrect answers' do
      user = sign_in_and_2fa_user

      visit verify_session_path
      expect(page).to have_content(t('idv.form.first_name'))

      complete_idv_profile_ok(user)
      expect(page).to have_content('Where did you live')

      complete_idv_questions_fail
      expect(current_path).to eq verify_retry_path
      expect(page).to have_content(t('idv.titles.fail'))
      expect(page).to have_content(t('idv.errors.fail'))
    end

    scenario 'un-resolvable PII' do
      sign_in_and_2fa_user

      visit verify_session_path
      expect(page).to have_content(t('idv.form.first_name'))

      fill_out_idv_form_fail
      click_button t('forms.buttons.continue')
      fill_out_financial_form_ok
      click_button t('forms.buttons.continue')
      fill_out_phone_form_ok
      click_button t('forms.buttons.continue')
      fill_in :user_password, with: user_password
      click_button t('forms.buttons.submit.default')

      expect(page).to have_content(t('idv.titles.fail'))
      expect(current_path).to eq verify_retry_path
    end
  end

  def complete_idv_profile_fail(user)
    fill_out_idv_form_fail
    click_button 'Continue'
    fill_out_financial_form_ok
    click_button t('forms.buttons.continue')
    fill_out_phone_form_ok(user.phone)
    click_button 'Continue'
    fill_in :user_password, with: user_password
    click_button 'Submit'
  end

  def complete_idv_profile_with_phone(phone)
    fill_out_idv_form_ok
    click_button t('forms.buttons.continue')
    fill_out_financial_form_ok
    click_button t('forms.buttons.continue')
    fill_out_phone_form_ok(phone)
    click_button t('forms.buttons.continue')
    fill_in :user_password, with: user_password
    click_submit_default
    # choose default SMS delivery method for confirming this new number
    click_submit_default
  end
end
