require 'rails_helper'
require 'axe/rspec'

feature 'Accessibility on IDV pages', :js do
  describe 'IDV pages' do
    include IdvStepHelper

    scenario 'home page' do
      sign_in_and_2fa_user

      visit idv_path

      expect(page).to be_accessible.according_to :section508, :"best-practice"
    end

    scenario 'cancel idv' do
      sign_in_and_2fa_user

      visit idv_cancel_path

      expect(current_path).to eq idv_cancel_path
      expect(page).to be_accessible.according_to :section508, :"best-practice"
    end

    scenario 'phone info' do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps

      expect(current_path).to eq idv_phone_path
      expect(page).to be_accessible.according_to :section508, :"best-practice"
    end

    scenario 'review page' do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps
      click_continue

      expect(current_path).to eq idv_review_path
      expect(page).to be_accessible.according_to :section508, :"best-practice"
    end

    scenario 'personal key / confirmation page' do
      sign_in_and_2fa_user
      visit idv_path
      complete_all_doc_auth_steps
      click_idv_continue
      click_idv_continue
      fill_in :user_password, with: Features::SessionHelper::VALID_PASSWORD
      click_continue

      expect(current_path).to eq idv_confirmations_path
      expect(page).to be_accessible.according_to :section508, :"best-practice"
    end
  end
end
