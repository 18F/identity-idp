require 'rails_helper'
require 'axe-rspec'

RSpec.feature 'Accessibility on IDV pages', :js do
  describe 'IDV pages' do
    include IdvStepHelper

    scenario 'cancel idv' do
      sign_in_and_2fa_user

      visit idv_cancel_path

      expect(current_path).to eq idv_cancel_path
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
