require 'rails_helper'

feature 'recovery doc fail step' do
  include IdvStepHelper
  include DocAuthHelper
  include RecoveryHelper

  let(:user) { create(:user, :with_phone) }
  let(:good_ssn) { '666-66-1234' }
  let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: good_ssn }) }
  let(:bad_pii) { DocAuthHelper::ACUANT_RESULTS_TO_PII.merge(ssn: '123') }

  before do
    sign_in_before_2fa(user)
    enable_doc_auth
    mock_assure_id_ok
    complete_recovery_steps_before_doc_success_step
  end

  it 'fails to re-verify if the pii does not match and then it proceeds to start re-verify over' do
    allow_any_instance_of(Idv::Steps::RecoverDocSuccessStep).to receive(:saved_pii).
      and_return(bad_pii.to_json)

    click_idv_continue

    expect(page).to have_current_path(idv_recovery_fail_step)

    click_idv_continue

    expect(page).to have_current_path(idv_recovery_overview_step)
  end
end
