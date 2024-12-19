require 'rails_helper'
require 'axe-rspec'

RSpec.feature 'Accessibility on IDV pages', :js do
  describe 'IDV pages' do
    include IdvStepHelper

    let(:service_provider) do
      create(:service_provider, :active, :in_person_proofing_enabled)
    end

    scenario 'how to verify page' do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(true)
      allow_any_instance_of(Idv::Session).to receive(:service_provider).and_return(service_provider)
      sign_in_and_2fa_user

      visit idv_welcome_url
      complete_welcome_step
      complete_agreement_step

      expect(page).to have_current_path idv_how_to_verify_path
      expect(page).to have_unique_form_landmark_labels
      expect_page_to_have_no_accessibility_violations(page)
    end

    scenario 'doc auth steps accessibility' do
      sign_in_and_2fa_user

      visit idv_cancel_path
      expect(page).to have_current_path idv_cancel_path
      expect_page_to_have_no_accessibility_violations(page)

      visit idv_path
      expect_page_to_have_no_accessibility_violations(page)
      complete_all_doc_auth_steps_before_password_step(expect_accessible: true)
      fill_in t('idv.form.password'), with: Features::SessionHelper::VALID_PASSWORD
      click_continue

      expect(page).to have_current_path idv_personal_key_path
      expect_page_to_have_no_accessibility_violations(page)
    end

    scenario 'doc auth steps accessibility on mobile', driver: :headless_chrome_mobile do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps_before_password_step(expect_accessible: true)
      fill_in t('idv.form.password'), with: Features::SessionHelper::VALID_PASSWORD
      click_continue

      expect(page).to have_current_path idv_personal_key_path
      expect_page_to_have_no_accessibility_violations(page)
    end
  end
end
