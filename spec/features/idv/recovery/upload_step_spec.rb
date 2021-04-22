require 'rails_helper'

feature 'recovery upload step' do
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
    complete_recovery_steps_before_upload_step(user)
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_recovery_upload_step)
    expect(page).to have_content(t('doc_auth.headings.upload'))
  end

  it 'proceeds to the next page' do
    click_on t('doc_auth.info.upload_computer_link')
    expect(page).to have_current_path(idv_recovery_document_capture_step)
  end

  context 'ial2 step indicator enabled' do
    it 'shows the step indicator' do
      expect(page).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.verify_id'),
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
