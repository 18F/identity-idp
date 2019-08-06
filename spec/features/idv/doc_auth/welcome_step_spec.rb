require 'rails_helper'

feature 'doc auth welcome step' do
  include DocAuthHelper

  def expect_doc_auth_upload_step
    expect(page).to have_current_path(idv_doc_auth_upload_step)
  end

  context 'button is disabled when JS is enabled', :js do
    before do
      enable_doc_auth
      complete_doc_auth_steps_before_welcome_step
    end

    it_behaves_like 'ial2 consent with js'
  end

  context 'button is clickable when JS is disabled' do
    before do
      enable_doc_auth
      complete_doc_auth_steps_before_welcome_step
    end

    def expect_doc_auth_first_step
      expect(page).to have_current_path(idv_doc_auth_welcome_step)
    end

    it_behaves_like 'ial2 consent without js'
  end
end
