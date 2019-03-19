require 'rails_helper'

feature 'recovery doc success step' do
  include IdvStepHelper
  include DocAuthHelper
  include RecoveryHelper

  let(:user) { create(:user, :with_phone) }
  let(:good_ssn) { '666-66-1234' }
  let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: good_ssn }) }
  let(:saved_pii) { DocAuthHelper::ACUANT_RESULTS_TO_PII.merge(ssn: good_ssn) }
  let(:bad_pii) { DocAuthHelper::ACUANT_RESULTS_TO_PII.merge(ssn: '123') }

  before do
    sign_in_before_2fa(user)
    enable_doc_auth
    mock_assure_id_ok
    complete_recovery_steps_before_doc_success_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_recovery_success_step)
    expect(page).to have_content(t('doc_auth.forms.doc_success'))
  end

  it 'proceeds to the account page if the document pii matches the saved pii' do
    allow_any_instance_of(Idv::Steps::RecoverDocSuccessStep).to receive(:saved_pii).
      and_return(saved_pii.to_json)

    click_idv_continue

    expect(page).to have_current_path(account_path)
  end

  it 'fails to re-verify if the document pii does not matche the saved pii' do
    allow_any_instance_of(Idv::Steps::RecoverDocSuccessStep).to receive(:saved_pii).
      and_return(bad_pii.to_json)

    click_idv_continue

    expect(page).to have_current_path(idv_recovery_fail_step)
  end
end
