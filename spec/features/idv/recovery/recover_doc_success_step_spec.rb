require 'rails_helper'

feature 'recovery doc success step' do
  include IdvStepHelper
  include DocAuthHelper
  include RecoveryHelper

  let(:user) { create(:user, :signed_up, :with_phone) }
  let(:good_ssn) { '666-66-1234' }
  let(:profile) { create(:profile, :active, :verified, user: user, pii: saved_pii) }
  let(:saved_pii) { DocAuthHelper::ACUANT_RESULTS_TO_PII.merge(ssn: good_ssn) }
  let(:bad_pii) { DocAuthHelper::ACUANT_RESULTS_TO_PII.merge(ssn: '123') }

  before do
    profile # Create the profile so the record is in the db
    sign_in_user(user)
    enable_doc_auth
    mock_assure_id_ok
    complete_recovery_steps_before_doc_success_step(user)
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_recovery_success_step)
    expect(page).to have_content(t('doc_auth.forms.doc_success'))
  end

  context 'document pii matches saved pii' do
    it 'proceeds to the account page' do
      click_idv_continue

      expect(page).to have_current_path(account_path)
    end
  end

  context 'document pii does not match the saved pii' do
    let(:profile) { create(:profile, :active, :verified, user: user, pii: bad_pii) }

    it 'fails to re-verify' do
      click_idv_continue

      expect(page).to have_current_path(idv_recovery_fail_step)
    end
  end
end
