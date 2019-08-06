require 'rails_helper'

feature 'recovery overview step' do
  include IdvStepHelper
  include DocAuthHelper
  include RecoveryHelper

  let(:user) { create(:user, :with_phone) }
  let(:good_ssn) { '666-66-1234' }
  let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: good_ssn }) }

  def expect_doc_auth_upload_step
    expect(page).to have_current_path(idv_recovery_upload_step)
  end

  context 'button is disabled when JS is enabled', :js do
    before do
      sign_in_before_2fa(user)
      enable_doc_auth
      mock_assure_id_ok
      complete_recovery_steps_before_overview_step(user)
    end

    it_behaves_like 'ial2 consent with js'
  end

  context 'button is clickable when JS is disabled' do
    before do
      sign_in_before_2fa(user)
      enable_doc_auth
      mock_assure_id_ok
      complete_recovery_steps_before_overview_step(user)
    end

    def expect_doc_auth_first_step
      expect(page).to have_current_path(idv_recovery_overview_step)
    end

    it_behaves_like 'ial2 consent without js'
  end
end
