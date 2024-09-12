require 'rails_helper'

RSpec.describe 'proofing flow with a Puerto Rican document', :js do
  include DocAuthHelper
  include IdvStepHelper

  before do
    sign_in_and_2fa_user
    complete_doc_auth_steps_before_document_capture_step
    complete_document_capture_step_with_yml('spec/fixtures/puerto_rico_resident.yml')
  end

  it 'redirects the user to the address step after the ssn step' do
    complete_ssn_step

    expect(page).to have_content(t('doc_auth.headings.address'))
    expect(current_path).to eq(idv_address_path)

    click_button t('forms.buttons.submit.update')

    expect(page).to have_content(t('headings.verify'))
    expect(current_path).to eq(idv_verify_info_path)
  end

  it 'does not redirect to the user to the address step after they update their SSN' do
    complete_ssn_step
    click_button t('forms.buttons.submit.update')

    expect(page).to have_content(t('headings.verify'))
    expect(current_path).to eq(idv_verify_info_path)

    click_link t('idv.buttons.change_ssn_label')

    expect(page).to have_current_path(idv_ssn_path)

    fill_in t('idv.form.ssn_label'), with: '900456789'
    click_button t('forms.buttons.submit.update')

    expect(page).to have_current_path(idv_verify_info_path)
  end
end
