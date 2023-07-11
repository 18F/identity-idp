require 'rails_helper'

RSpec.describe 'Identity verification', :js do
  include IdvStepHelper

  # Needed specs:
  # unsupervised proofing happy path mobile only
  # hybrid mobile end to end (edit hybrid_mobile_spec)
  # verify by mail
  # in person proofing

  scenario 'Unsupervised proofing happy path desktop' do
    try_to_skip_ahead_before_signing_in
    visit_idp_from_sp_with_ial2(:oidc)
    user = sign_up_and_2fa_ial1_user

    validate_welcome_page
    try_to_skip_ahead_from_welcome
    complete_welcome_step

    validate_agreement_page
    try_to_skip_ahead_from_agreement
    complete_agreement_step

    validate_hybrid_handoff_page
    try_to_skip_ahead_from_hybrid_handoff
    complete_hybrid_handoff_step # upload photos

    try_to_go_back_from_document_capture
    validate_document_capture_page
    complete_document_capture_step
    validate_document_capture_submit(user)

    validate_ssn_page
    complete_ssn_step

    try_to_go_back_from_verify_info
    validate_verify_info_page
    complete_verify_step
    validate_verify_info_submit(user)

    validate_phone_page
    try_to_skip_ahead_from_phone
    complete_otp_verification_page(user)

    validate_review_page
    complete_review_step(user)
    validate_review_submit(user)

    validate_personal_key_page
    acknowledge_and_confirm_personal_key

    validate_idv_completed_page
    click_agree_and_continue

    validate_return_to_sp
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

    expect(page).to have_current_path(idv_hybrid_handoff_path)

    # Check for expected content
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
    expect(page).to have_content(t('doc_auth.headings.upload_from_computer'))
    expect(page).to have_content(t('doc_auth.info.upload_from_computer'))
    expect(page).to have_content(t('doc_auth.headings.upload_from_phone'))

    # defaults phone to user's 2fa phone number
    field = page.find_field(t('two_factor_authentication.phone_label'))
    expect(same_phone?(field.value, Features::SessionHelper::IAL1_USER_PHONE)).
      to be true
  end

  def validate_document_capture_page
    expect(page).to have_current_path(idv_document_capture_path)

    # Check for expected content
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
    expect(page).to have_content(t('doc_auth.headings.document_capture').tr(' ', ' '))
  end

  def validate_document_capture_submit(user)
    expect_costing_for_document
    expect(DocAuthLog.find_by(user_id: user.id).state).to eq('MT')
  end

  # copied from document_capture_spec
  def expect_costing_for_document
    %i[acuant_front_image acuant_back_image acuant_result].each do |cost_type|
      expect(costing_for(cost_type)).to be_present
    end
  end

  def costing_for(cost_type)
    SpCost.where(ial: 2, issuer: 'urn:gov:gsa:openidconnect:sp:server', cost_type: cost_type.to_s)
  end

  def validate_ssn_page
    expect(page).to have_current_path(idv_ssn_path)

    # Check for expected content
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))

    expect(page.find_field(t('idv.form.ssn_label'))['aria-invalid']).to eq('false')

    # shows error message on invalid ssn
    fill_out_ssn_form_fail
    click_idv_continue
    expect(page.find_field(t('idv.form.ssn_label'))['aria-invalid']).to eq('true')
  end

  def validate_verify_info_page
    expect(page).to have_current_path(idv_verify_info_path)

    # Check for expected content
    expect(page).to have_content(t('headings.verify'))
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_info'))

    # DOB is in full month format (October)
    expect(page).to have_text(t('date.month_names')[10])

    # SSN is masked until revealed
    expect(page).to have_text(DocAuthHelper::GOOD_SSN_MASKED)
    expect(page).not_to have_text(DocAuthHelper::GOOD_SSN)
    check t('forms.ssn.show')
    expect(page).not_to have_text(DocAuthHelper::GOOD_SSN_MASKED)
    expect(page).to have_text(DocAuthHelper::GOOD_SSN)
  end

  def validate_verify_info_submit(user)
    expect(page).to have_content(t('doc_auth.forms.doc_success'))
    expect(user.proofing_component.resolution_check).to eq(Idp::Constants::Vendors::LEXIS_NEXIS)
    expect(user.proofing_component.source_check).to eq(Idp::Constants::Vendors::AAMVA)
    expect(DocAuthLog.find_by(user_id: user.id).aamva).to eq(true)
  end

  def validate_phone_page
    expect(page).to have_current_path(idv_phone_path)

    # selects sms delivery option by default
    expect(page).to have_checked_field(
      t('two_factor_authentication.otp_delivery_preference.sms'), visible: false
    )

    # displays error if invalid phone number is entered
    fill_in :idv_phone_form_phone, with: '578190'
    click_idv_send_security_code
    expect(page).to have_current_path(idv_phone_path)
    expect(page).to have_content(t('errors.messages.invalid_phone_number.us'))

    # displays error if no phone number is entered
    fill_in('idv_phone_form_phone', with: '')
    click_idv_send_security_code
    expect(page).to have_current_path(idv_phone_path)
    expect(page).to have_content(t('errors.messages.phone_required'))
  end

  def complete_otp_verification_page(user)
    fill_in('idv_phone_form_phone', with: '')
    fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
    click_idv_send_security_code

    expect(page).to have_content(t('titles.idv.enter_one_time_code', app_name: APP_NAME))
    expect(page).to have_current_path(idv_otp_verification_path)

    # without a code, stay on page
    click_submit_default
    expect(page).to have_current_path(idv_otp_verification_path)

    fill_in_code_with_last_phone_otp
    click_submit_default
  end

  def validate_review_page
    expect(page).to have_current_path(idv_review_path)
    expect(page).to have_content(t('idv.messages.review.message', app_name: APP_NAME))
    expect(page).to have_content(t('idv.messages.review.phone_verified'))

    # does not move ahead with incorrect password
    fill_in 'Password', with: 'this is not the right password'
    click_idv_continue
    expect(page).to have_content(t('idv.errors.incorrect_password'))
    expect(page).to have_current_path(idv_review_path)
  end

  def validate_review_submit(user)
    expect(user.events.account_verified.size).to be(1)
    expect(user.profiles.count).to eq 1

    profile = user.profiles.first

    expect(profile.active?).to eq true
    expect(GpoConfirmation.count).to eq(0)
  end

  def validate_personal_key_page
    expect(current_path).to eq idv_personal_key_path
    expect(page).to have_content(t('forms.personal_key_partial.acknowledgement.header'))
  end

  def validate_idv_completed_page
    expect(current_path).to eq sign_up_completed_path
    expect(page).to have_content t(
      'titles.sign_up.completion_ial2',
      sp: 'Test SP',
    )
  end

  def validate_return_to_sp
    expect(current_url).to start_with('http://localhost:7654/auth/result')
  end

  def try_to_skip_ahead_before_signing_in
    visit idv_review_path
    expect(current_path).to eq(root_path)
  end

  def try_to_skip_ahead_from_welcome
    visit(idv_hybrid_handoff_url)
    expect(page).to have_current_path(idv_welcome_path)
    visit(idv_document_capture_url)
    expect(page).to have_current_path(idv_welcome_path)
    visit idv_verify_info_path
    expect(page).to have_current_path(idv_welcome_path)
    visit idv_phone_path
    expect(page).to have_current_path(idv_welcome_path)
  end

  def try_to_skip_ahead_from_agreement
    visit(idv_hybrid_handoff_url)
    expect(page).to have_current_path(idv_agreement_path)
    visit(idv_document_capture_url)
    expect(page).to have_current_path(idv_agreement_path)
  end

  def try_to_skip_ahead_from_hybrid_handoff
    visit(idv_document_capture_url)
    expect(page).to have_current_path(idv_hybrid_handoff_path)
  end

  def try_to_skip_ahead_from_phone
    visit idv_review_path
    expect(page).to have_current_path(idv_phone_path)
  end

  def try_to_go_back_from_document_capture
    visit(idv_agreement_path)
    expect(page).to have_current_path(idv_document_capture_path)
    visit(idv_hybrid_handoff_url)
    expect(page).to have_current_path(idv_document_capture_path)
  end

  def try_to_go_back_from_verify_info
    visit(idv_document_capture_url)
    expect(page).to have_current_path(idv_verify_info_path)
  end

  def same_phone?(phone1, phone2)
    PhoneFormatter.format(phone1) == PhoneFormatter.format(phone2)
  end
end
