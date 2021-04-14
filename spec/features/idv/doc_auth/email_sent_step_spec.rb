require 'rails_helper'

feature 'doc auth email sent step' do
  include IdvStepHelper
  include DocAuthHelper

  let(:ial2_step_indicator_enabled) { true }

  before do
    allow(IdentityConfig.store).to receive(:ial2_step_indicator_enabled).
      and_return(ial2_step_indicator_enabled)
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_email_sent_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_email_sent_step)
    user = User.first
    expect(page).to have_content(t('doc_auth.instructions.email_sent', email: user.email))
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
