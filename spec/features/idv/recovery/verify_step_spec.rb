require 'rails_helper'

feature 'recovery verify step' do
  include IdvStepHelper
  include DocAuthHelper
  include RecoveryHelper

  let(:user) { create(:user) }
  let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: '1234' }) }
  let(:max_attempts) { Idv::Attempter.idv_max_attempts }
  before do
    sign_in_before_2fa(user)
    enable_doc_auth
    mock_assure_id_ok
  end

  it 'is on the correct page' do
    complete_recovery_steps_before_verify_step
    expect(page).to have_current_path(idv_recovery_verify_step)
    expect(page).to have_content(t('doc_auth.headings.verify'))
  end

  it 'proceeds to the next page upon confirmation' do
    complete_recovery_steps_before_verify_step
    click_idv_continue

    expect(page).to have_current_path(idv_recovery_success_step)
  end

  it 'does not proceed to the next page if resolution fails' do
    complete_recovery_steps_before_ssn_step
    fill_out_ssn_form_with_ssn_that_fails_resolution
    click_idv_continue
    click_idv_continue

    expect(page).to have_current_path(idv_session_failure_path(reason: :warning))
  end

  it 'does not proceed to the next page if ssn is a duplicate' do
    complete_recovery_steps_before_ssn_step
    fill_out_ssn_form_with_duplicate_ssn
    click_idv_continue
    click_idv_continue

    expect(page).to have_current_path(idv_session_failure_path(reason: :warning))
  end

  it 'throttles resolution' do
    complete_recovery_steps_before_ssn_step
    fill_out_ssn_form_with_ssn_that_fails_resolution
    click_idv_continue
    (max_attempts - 1).times do
      click_idv_continue
      expect(page).to have_current_path(idv_session_failure_path(reason: :warning))
      visit idv_recovery_verify_step
    end
    click_idv_continue
    expect(page).to have_current_path(idv_session_failure_path(reason: :fail))
  end

  it 'throttles dup ssn' do
    complete_recovery_steps_before_ssn_step
    fill_out_ssn_form_with_duplicate_ssn
    click_idv_continue
    (max_attempts - 1).times do
      click_idv_continue
      expect(page).to have_current_path(idv_session_failure_path(reason: :warning))
      visit idv_recovery_verify_step
    end
    click_idv_continue
    expect(page).to have_current_path(idv_session_failure_path(reason: :fail))
  end
end
