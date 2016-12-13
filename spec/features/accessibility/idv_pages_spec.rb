require 'rails_helper'
require 'axe/rspec'

feature 'Accessibility on IDV pages', :js do
  describe 'IDV pages' do
    include IdvHelper

    scenario 'home page' do
      sign_in_and_2fa_user

      visit verify_path

      expect(page).to be_accessible
    end

    scenario 'basic info' do
      sign_in_and_2fa_user

      visit verify_session_path

      expect(current_path).to eq verify_session_path
      expect(page).to be_accessible
    end

    scenario 'cancel idv' do
      sign_in_and_2fa_user

      visit verify_cancel_path

      expect(current_path).to eq verify_cancel_path
      expect(page).to be_accessible
    end

    scenario 'finance info' do
      sign_in_and_2fa_user
      visit verify_session_path
      fill_out_idv_form_ok
      click_button t('forms.buttons.continue')

      visit verify_finance_path

      expect(current_path).to eq verify_finance_path
      expect(page).to be_accessible
    end

    scenario 'phone info' do
      sign_in_and_2fa_user
      visit verify_session_path
      fill_out_idv_form_ok
      click_button t('forms.buttons.continue')
      fill_out_and_submit_finance_form

      expect(current_path).to eq verify_phone_path
      expect(page).to be_accessible
    end

    scenario 'review page' do
      sign_in_and_2fa_user
      visit verify_session_path
      fill_out_idv_form_ok
      click_button t('forms.buttons.continue')
      fill_out_and_submit_finance_form
      fill_out_phone_form_ok
      click_button t('forms.buttons.continue')

      expect(current_path).to eq verify_review_path
      expect(page).to be_accessible
    end

    scenario 'recovery code / confirmation page' do
      user = sign_in_and_2fa_user
      visit verify_session_path
      fill_out_idv_form_ok
      click_button t('forms.buttons.continue')
      fill_out_and_submit_finance_form
      fill_out_phone_form_ok(user.phone)
      click_button t('forms.buttons.continue')
      fill_in :user_password, with: Features::SessionHelper::VALID_PASSWORD
      click_submit_default

      expect(current_path).to eq verify_confirmations_path
      expect(page).to be_accessible
    end

    def fill_out_and_submit_finance_form
      find('#idv_finance_form_finance_type_ccn', visible: false).trigger('click')
      fill_in :idv_finance_form_ccn, with: '12345678'
      click_button t('forms.buttons.continue')
    end
  end
end
