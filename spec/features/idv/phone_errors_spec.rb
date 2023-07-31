require 'rails_helper'
RSpec.feature 'phone errors', :js do
  include IdvStepHelper
  include IdvHelper

  before do
    sign_in_and_2fa_user
    start_idv_from_sp
  end

  it 'user visits phone errors before submitting phone number' do
    visit(idv_phone_errors_warning_url)
    expect(current_path).to eq(idv_welcome_path)

    complete_welcome_step
    visit(idv_phone_errors_warning_url)
    expect(current_path).to eq(idv_agreement_path)

    complete_agreement_step
    visit(idv_phone_errors_warning_url)
    expect(current_path).to eq(idv_hybrid_handoff_path)

    complete_hybrid_handoff_step # upload photos
    visit(idv_phone_errors_warning_url)
    expect(current_path).to eq(idv_document_capture_path)

    complete_document_capture_step
    visit(idv_phone_errors_warning_url)
    expect(current_path).to eq(idv_ssn_path)

    complete_ssn_step
    visit(idv_phone_errors_warning_url)
    expect(current_path).to eq(idv_verify_info_path)

    complete_verify_step
    visit(idv_phone_errors_warning_url)
    expect(current_path).to eq(idv_phone_path)

    fill_out_phone_form_fail
    click_idv_send_security_code
    expect(current_path).to eq(idv_phone_errors_warning_path)

    visit(idv_phone_errors_warning_url)
    expect(current_path).to eq(idv_phone_errors_warning_path)
  end
end