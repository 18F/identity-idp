require 'rails_helper'

feature 'doc auth cancel' do
  include IdvStepHelper
  include DocAuthHelper

  before do
    enable_doc_auth
    complete_doc_auth_steps_before_doc_success_step
  end

  it 'correctly restarts doc auth flow upon cancel and revisit' do
    expect(page).to have_current_path(idv_doc_auth_success_step)

    click_link t('links.cancel')

    expect(page).to have_current_path(idv_cancel_path)

    click_button t('forms.buttons.cancel')

    expect(page).to have_content(t('headings.cancellations.confirmation'))
    expect(current_path).to eq(idv_cancel_path)

    visit account_path
    expect(current_path).to eq(account_path)

    visit(idv_doc_auth_success_step)
    expect(current_path).to eq(idv_doc_auth_welcome_step)
  end
end
