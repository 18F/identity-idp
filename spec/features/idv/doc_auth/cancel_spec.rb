require 'rails_helper'

feature 'doc auth cancel' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_verify_step
  end

  it 'correctly restarts doc auth flow upon cancel and revisit' do
    expect(page).to have_current_path(idv_doc_auth_verify_step)

    click_link t('links.cancel')

    expect(page).to have_current_path(idv_cancel_path(step: 'verify'))

    click_button t('forms.buttons.cancel')

    expect(page).to have_content(t('headings.cancellations.confirmation', app_name: APP_NAME))
    expect(current_path).to eq(idv_cancel_path)

    visit account_path
    expect(current_path).to eq(account_path)

    visit(idv_doc_auth_verify_step)
    expect(current_path).to eq(idv_doc_auth_welcome_step)
  end
end
