require 'rails_helper'

feature 'doc auth email sent step' do
  include IdvStepHelper
  include DocAuthHelper

  let(:user) { user_with_2fa }

  before do
    enable_doc_auth
    complete_doc_auth_steps_before_email_sent_step(user)
  end

  it 'is on the correct page' do
    expect(page).to have_current_path(idv_doc_auth_email_sent_step)
    expect(page).to have_content(t('doc_auth.instructions.email_sent', email: user.email))
  end
end
