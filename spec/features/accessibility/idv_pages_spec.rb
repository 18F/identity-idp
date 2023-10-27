require 'rails_helper'
require 'axe-rspec'

RSpec.feature 'Accessibility on IDV pages', :js do
  describe 'IDV pages' do
    include IdvStepHelper

    scenario 'home page' do
      sign_in_and_2fa_user

      visit idv_path

      expect_page_to_have_no_accessibility_violations(page)
    end

    scenario 'cancel idv' do
      sign_in_and_2fa_user

      visit idv_cancel_path

      expect(current_path).to eq idv_cancel_path
      expect_page_to_have_no_accessibility_violations(page)
    end

    scenario 'phone info' do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps

      expect(current_path).to eq idv_phone_path
      expect_page_to_have_no_accessibility_violations(page)
    end

    scenario 'review page' do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps_before_password_step

      expect(page).to have_current_path(idv_enter_password_path)
      expect_page_to_have_no_accessibility_violations(page)
    end

    scenario 'personal key / confirmation page' do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps_before_password_step
      fill_in t('idv.form.password'), with: Features::SessionHelper::VALID_PASSWORD
      click_continue

      expect(current_path).to eq idv_personal_key_path
      expect_page_to_have_no_accessibility_violations(page)
    end

    scenario 'doc auth steps accessibility' do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps_before_password_step(expect_accessible: true)
      fill_in t('idv.form.password'), with: Features::SessionHelper::VALID_PASSWORD
      click_continue

      expect(current_path).to eq idv_personal_key_path
      expect_page_to_have_no_accessibility_violations(page)
    end

    scenario 'doc auth steps accessibility on mobile', driver: :headless_chrome_mobile do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps_before_password_step(expect_accessible: true)
      fill_in t('idv.form.password'), with: Features::SessionHelper::VALID_PASSWORD
      click_continue

      expect(current_path).to eq idv_personal_key_path
      expect_page_to_have_no_accessibility_violations(page)
    end
  end
end
