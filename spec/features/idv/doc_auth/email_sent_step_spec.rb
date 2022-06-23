require 'rails_helper'

feature 'doc auth email sent step' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_email_sent_step
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_email_sent_step)
    user = User.first
    expect(page).to have_content(
      t('doc_auth.instructions.email_sent', email: user.confirmed_email_addresses.first.email),
    )
    expect(page).to have_css(
      '.step-indicator__step--current',
      text: t('step_indicator.flows.idv.verify_id'),
    )
  end
end
