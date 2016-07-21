require 'rails_helper'

feature 'IdV session' do
  include IdvHelper

  context 'KBV off' do
    before do
      allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(false)
    end

    scenario 'skips KBV' do
      user = sign_in_and_2fa_user

      visit '/idv/sessions'

      expect(page).to have_content(t('idv.form.first_name'))

      fill_out_idv_form_ok
      click_button 'Continue'
      expect(page).to have_content(t('idv.titles.complete'))
      expect(user.active_profile).to be_a(Profile)
    end
  end

  context 'KBV on' do
    before do
      allow(FeatureManagement).to receive(:proofing_requires_kbv?).and_return(true)
    end

    scenario 'KBV with all answers correct' do
      user = sign_in_and_2fa_user

      visit '/idv/sessions'

      expect(page).to have_content(t('idv.form.first_name'))

      fill_out_idv_form_ok
      click_button 'Continue'
      expect(page).to have_content('Where did you live')

      complete_idv_questions_ok
      expect(page).to have_content(t('idv.titles.complete'))

      expect(user.active_profile).to be_a(Profile)
      expect(user.active_profile.verified?).to eq true
      expect(user.active_profile.ssn).to eq '666661234'
    end

    scenario 'KBV with some incorrect answers' do
      sign_in_and_2fa_user

      visit '/idv/sessions'

      expect(page).to have_content(t('idv.form.first_name'))

      fill_out_idv_form_ok
      click_button 'Continue'

      expect(page).to have_content('Where did you live')

      complete_idv_questions_fail
      expect(page).to have_content(t('idv.titles.hardfail'))
    end

    scenario 'un-resolvable PII' do
      sign_in_and_2fa_user

      visit '/idv/sessions'

      expect(page).to have_content(t('idv.form.first_name'))

      fill_out_idv_form_fail
      click_button 'Continue'

      expect(page).to have_content(t('idv.titles.fail'))
    end
  end
end
