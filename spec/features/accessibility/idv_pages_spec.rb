require 'rails_helper'
require 'axe-rspec'

RSpec.feature 'Accessibility on IDV pages', :js, allowed_extra_analytics: [:*] do
  describe 'IDV pages' do
    include IdvStepHelper

    let(:service_provider) do
      create(:service_provider, :active, :in_person_proofing_enabled)
    end

    scenario 'home page' do
      sign_in_and_2fa_user

      visit idv_path

      expect_page_to_have_no_accessibility_violations(page)
    end

    scenario 'how to verify page' do
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(true)
      allow_any_instance_of(Idv::Session).to receive(:service_provider).and_return(service_provider)
      sign_in_and_2fa_user

      visit idv_welcome_url
      complete_welcome_step
      complete_agreement_step

      expect(current_path).to eq idv_how_to_verify_path
      expect(page).to have_unique_form_landmark_labels
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
