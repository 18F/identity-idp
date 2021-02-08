require 'rails_helper'
require 'axe/rspec'

feature 'Accessibility on IDV pages', :js do
  describe 'IDV pages' do
    include IdvStepHelper

    scenario 'home page' do
      sign_in_and_2fa_user

      visit idv_path

      expect(page).to be_accessible.according_to :section508, :"best-practice"
      expect(page).to label_required_fields
      expect(page).to be_uniquely_titled
    end

    scenario 'cancel idv' do
      sign_in_and_2fa_user

      visit idv_cancel_path

      expect(current_path).to eq idv_cancel_path
      expect(page).to be_accessible.according_to :section508, :"best-practice"
      expect(page).to label_required_fields
      expect(page).to be_uniquely_titled
    end

    scenario 'phone info' do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps

      expect(current_path).to eq idv_phone_path
      expect(page).to be_accessible.according_to :section508, :"best-practice"
      expect(page).to label_required_fields
      expect(page).to be_uniquely_titled
    end

    scenario 'review page' do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps
      click_continue

      expect(page).to have_current_path(idv_review_path, wait: 5)
      expect(page).to be_accessible.according_to :section508, :"best-practice"
      expect(page).to label_required_fields
      expect(page).to be_uniquely_titled
    end

    scenario 'personal key / confirmation page' do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps
      click_idv_continue
      fill_in :user_password, with: Features::SessionHelper::VALID_PASSWORD
      click_continue

      expect(current_path).to eq idv_confirmations_path
      expect(page).to be_accessible.according_to :section508, :"best-practice"
      expect(page).to label_required_fields
      expect(page).to be_uniquely_titled
    end

    scenario 'doc auth steps accessibility' do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps(expect_accessible: true)
      click_idv_continue
      fill_in :user_password, with: Features::SessionHelper::VALID_PASSWORD
      click_continue

      expect(current_path).to eq idv_confirmations_path
      expect(page).to be_accessible.according_to :section508, :"best-practice"
      expect(page).to label_required_fields
      expect(page).to be_uniquely_titled
    end

    scenario 'doc auth steps accessibility on mobile', driver: :headless_chrome_mobile do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps(expect_accessible: true)
      click_idv_continue
      fill_in :user_password, with: Features::SessionHelper::VALID_PASSWORD
      click_continue

      expect(current_path).to eq idv_confirmations_path
      expect(page).to be_accessible.according_to :section508, :"best-practice"
      expect(page).to label_required_fields
      expect(page).to be_uniquely_titled
    end
  end
end
