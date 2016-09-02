require 'rails_helper'

feature 'IdV session' do
  include IdvHelper

  context 'landing page' do
    before do
      sign_in_and_2fa_user
      visit idv_path
    end

    scenario 'decline to verify identity' do
      click_link 'No'

      expect(page).to have_content(t('idv.titles.hardfail'))
    end

    scenario 'proceed to verify identity' do
      click_link 'Yes'

      expect(page).to have_content(t('idv.titles.welcome'))
    end
  end

  context 'KBV off' do
    before do
      allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(false)
    end

    scenario 'skips KBV' do
      user = sign_in_and_2fa_user

      visit idv_session_path

      fill_out_idv_form_ok
      click_button 'Continue'
      expect(page).to have_content(t('idv.form.ccn'))

      fill_out_financial_form_ok
      click_button 'Continue'
      fill_out_phone_form_ok(user.phone)
      click_button 'Continue'
      click_button 'Submit'

      expect(page).to have_content(t('idv.titles.complete'))
      expect(page).to have_content('Some One')
      expect(page).to have_content('123 Main St')
      expect(current_url).to eq(profile_url)
      expect(user.reload.active_profile).to be_a(Profile)
    end

    scenario 'steps are re-entrant and sticky' do
      _user = sign_in_and_2fa_user

      visit idv_session_path

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
      click_button 'Continue'

      expect(page).to_not have_selector("input[value='#{first_ccn_value}']")

      fill_out_financial_form_ok
      click_button 'Continue'

      visit idv_session_path

      expect(page).to have_selector("input[value='#{first_ssn_value}']")

      fill_in 'profile_ssn', with: second_ssn_value
      click_button 'Continue'

      expect(current_url).to eq idv_finance_url
      expect(page).to have_content(t('idv.form.ccn'))
      expect(page).to have_selector("input[value='#{first_ccn_value}']")

      click_button 'Continue'

      visit idv_finance_path
      find('#idv_finance_form_finance_type_mortgage').set(true)
      fill_in :idv_finance_form_finance_account, with: mortgage_value
      click_button 'Continue'

      expect(current_url).to eq idv_phone_url

      visit idv_finance_path

      expect(page).to have_selector("input[value='#{mortgage_value}']")

      fill_in :idv_finance_form_finance_account, with: second_ccn_value
      click_button 'Continue'

      expect(page).to_not have_selector("input[value='#{first_phone_formatted}']")

      fill_out_phone_form_ok(first_phone_value)
      click_button 'Continue'
      visit idv_phone_path

      expect(page).to have_selector("input[value='#{first_phone_formatted}']")

      fill_out_phone_form_ok(second_phone_value)
      click_button 'Continue'

      expect(page).to have_content(t('idv.titles.review'))
      expect(page).to have_content(second_ssn_value)
      expect(page).to_not have_content(first_ssn_value)
      expect(page).to have_content(second_ccn_value)
      expect(page).to_not have_content(mortgage_value)
      expect(page).to_not have_content(first_ccn_value)
      expect(page).to have_content(second_phone_formatted)
      expect(page).to_not have_content(first_phone_formatted)
    end

    context 'Idv phone and user phone are different' do
      it 'redirects to phone confirmation path' do
        sign_in_and_2fa_user
        visit idv_session_path

        fill_out_idv_form_ok
        click_button 'Continue'
        fill_out_financial_form_ok
        click_button 'Continue'
        fill_out_phone_form_ok('416-555-0190')
        click_button 'Continue'
        click_button 'Submit'

        expect(current_path).to eq idv_phone_confirmation_path
      end
    end
  end

  context 'KBV on' do
    before do
      allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(true)
    end

    scenario 'KBV with all answers correct' do
      user = sign_in_and_2fa_user

      visit idv_session_path
      expect(page).to have_content(t('idv.form.first_name'))

      complete_idv_profile(user)
      expect(page).to have_content('Where did you live')

      complete_idv_questions_ok

      expect(page).to have_content(t('idv.titles.complete'))
      expect(current_url).to eq(profile_url)
      expect(user.reload.active_profile).to be_a(Profile)
      expect(user.active_profile.verified?).to eq true
      expect(user.active_profile.ssn).to eq '666661234'
    end

    scenario 'KBV with some incorrect answers' do
      user = sign_in_and_2fa_user

      visit idv_session_path
      expect(page).to have_content(t('idv.form.first_name'))

      complete_idv_profile(user)
      expect(page).to have_content('Where did you live')

      complete_idv_questions_fail
      expect(page).to have_content(t('idv.titles.hardfail'))
    end

    scenario 'un-resolvable PII' do
      sign_in_and_2fa_user

      visit idv_session_path
      expect(page).to have_content(t('idv.form.first_name'))

      fill_out_idv_form_fail
      click_button 'Continue'
      fill_out_financial_form_ok
      click_button 'Continue'
      fill_out_phone_form_ok
      click_button 'Continue'
      click_button 'Submit'

      expect(page).to have_content(t('idv.titles.fail'))
      expect(current_path).to eq idv_session_path
    end
  end

  def complete_idv_profile(user)
    fill_out_idv_form_ok
    click_button 'Continue'
    fill_out_financial_form_ok
    click_button 'Continue'
    fill_out_phone_form_ok(user.phone)
    click_button 'Continue'
    click_button 'Submit'
  end
end
