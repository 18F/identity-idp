require 'rails_helper'

RSpec.describe 'Identity verification', :js do
  include IdvStepHelper

  # Needed specs:
  # unsupervised proofing happy path mobile only
  # hybrid mobile end to end (edit hybrid_mobile_spec)
  # verify by mail
  # in person proofing

  scenario 'Unsupervised proofing happy path desktop' do
    visit_idp_from_sp_with_ial2(:oidc)
    sign_up_and_2fa_ial1_user

    validate_welcome_page
    try_to_skip_ahead_from_welcome
    complete_welcome_step

    validate_agreement_page
    try_to_skip_ahead_from_agreement
    complete_agreement_step

    validate_hybrid_handoff_page
    complete_hybrid_handoff_step # upload photos

    try_to_go_back_from_document_capture
  end

  def validate_welcome_page
    expect(page).to have_current_path(idv_welcome_path)

    # Check for expected content
    expect_step_indicator_current_step(t('step_indicator.flows.idv.getting_started'))
  end

  def validate_agreement_page
    expect(page).to have_current_path(idv_agreement_path)

    # Check for expected content
    expect_step_indicator_current_step(t('step_indicator.flows.idv.getting_started'))

    # Check for actions that shouldn't advance the user
    # Try to continue with unchecked checkbox
    click_continue
    expect(page).to have_current_path(idv_agreement_path)
    expect(page).to have_content(t('forms.validation.required_checkbox'))
  end

  def validate_hybrid_handoff_page
    allow_any_instance_of(Idv::HybridHandoffController).to receive(:mobile_device?).
      and_return(false)

    # Check for expected content
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
    expect(page).to have_content(t('doc_auth.headings.upload_from_computer'))
    expect(page).to have_content(t('doc_auth.info.upload_from_computer'))
    expect(page).to have_content(t('doc_auth.headings.upload_from_phone'))

    # defaults phone to user's 2fa phone number
    field = page.find_field(t('two_factor_authentication.phone_label'))
    expect(field.value).to eq('(202) 555-1212')
  end

  def try_to_skip_ahead_from_welcome
    visit(idv_hybrid_handoff_url)
    expect(page).to have_current_path(idv_welcome_path)
  end

  def try_to_skip_ahead_from_agreement
    visit(idv_hybrid_handoff_url)
    expect(page).to have_current_path(idv_agreement_path)
  end

  def try_to_go_back_from_document_capture
    visit(idv_hybrid_handoff_url)
    expect(page).to have_current_path(idv_document_capture_path)
  end
end
