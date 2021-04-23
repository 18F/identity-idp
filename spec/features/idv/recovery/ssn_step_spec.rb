require 'rails_helper'

feature 'recovery ssn step' do
  include IdvStepHelper
  include DocAuthHelper
  include RecoveryHelper

  let(:ial2_step_indicator_enabled) { true }
  let(:user) { create(:user) }
  let(:profile) { build(:profile, :active, :verified, user: user, pii: { ssn: '1234' }) }

  before do
    allow(IdentityConfig.store).to receive(:ial2_step_indicator_enabled).
      and_return(ial2_step_indicator_enabled)
    sign_in_before_2fa(user)
    complete_recovery_steps_before_ssn_step(user)
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_recovery_ssn_step)
    expect(page).to have_content(t('doc_auth.headings.ssn'))
  end

  it 'proceeds to the next page with valid info' do
    fill_out_ssn_form_ok
    click_idv_continue

    expect(page).to have_current_path(idv_recovery_verify_step)
  end

  it 'does not proceed to the next page with invalid info' do
    fill_out_ssn_form_fail
    click_idv_continue

    expect(page).to have_current_path(idv_recovery_ssn_step)
  end

  context 'ial2 step indicator enabled' do
    it 'shows the step indicator' do
      expect(page).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.verify_info'),
      )
    end
  end

  context 'ial2 step indicator disabled' do
    let(:ial2_step_indicator_enabled) { false }

    it 'does not show the step indicator' do
      expect(page).not_to have_css('.step-indicator')
    end
  end
end
