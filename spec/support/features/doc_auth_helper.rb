require_relative 'document_capture_step_helper'
require_relative 'interaction_helper'
require_relative '../user_agent_helper'

module DocAuthHelper
  include InteractionHelper
  include DocumentCaptureStepHelper
  include UserAgentHelper

  GOOD_SSN = Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn].freeze
  GOOD_SSN_MASKED = '9**-**-***4'.freeze
  GOOD_SSN_FORMATTED = SsnFormatter.format(GOOD_SSN).freeze
  SSN_THAT_FAILS_RESOLUTION = '123-45-6666'.freeze
  SSN_THAT_RAISES_EXCEPTION = '000-00-0000'.freeze

  def clear_and_fill_in(field_name, text)
    fill_in field_name, with: ''
    fill_in field_name, with: text
  end

  def fill_out_ssn_form_with_ssn_that_fails_resolution
    fill_in t('idv.form.ssn_label'), with: SSN_THAT_FAILS_RESOLUTION
  end

  def fill_out_ssn_form_with_ssn_that_raises_exception
    fill_in t('idv.form.ssn_label'), with: SSN_THAT_RAISES_EXCEPTION
  end

  def fill_out_ssn_form_ok
    fill_in t('idv.form.ssn_label'), with: GOOD_SSN
  end

  def fill_out_ssn_form_fail
    fill_in t('idv.form.ssn_label'), with: ''
  end

  def click_doc_auth_back_link
    click_on '‹ ' + t('forms.buttons.back')
  end

  def click_send_link
    click_on t('forms.buttons.send_link')
  end

  def complete_doc_auth_steps_before_welcome_step(expect_accessible: false)
    # rubocop:disable IdentityIdp/CapybaraCurrentPathEqualityLinter
    # This should be refactored at some point to not require the path conditional
    visit idv_welcome_path unless current_path == idv_welcome_path
    # rubocop:enable IdentityIdp/CapybaraCurrentPathEqualityLinter

    expect_page_to_have_no_accessibility_violations(page) if expect_accessible
  end

  def complete_welcome_step
    click_on t('doc_auth.buttons.continue')
  end

  def complete_doc_auth_steps_before_agreement_step(expect_accessible: false)
    complete_doc_auth_steps_before_welcome_step(expect_accessible: expect_accessible)
    complete_welcome_step
    expect_page_to_have_no_accessibility_violations(page) if expect_accessible
  end

  def complete_agreement_step
    check t('doc_auth.instructions.consent', app_name: APP_NAME)
    click_on t('doc_auth.buttons.continue')
  end

  def complete_doc_auth_steps_before_hybrid_handoff_step(expect_accessible: false)
    complete_doc_auth_steps_before_agreement_step(expect_accessible: expect_accessible)
    complete_agreement_step
    expect_page_to_have_no_accessibility_violations(page) if expect_accessible
  end

  def complete_hybrid_handoff_step
    # If there is a phone outage, the hybrid_handoff step is
    # skipped and the user is taken straight to document capture.
    return if OutageStatus.new.any_phone_vendor_outage?
    expect(page).to have_content(t('doc_auth.headings.upload_from_computer'))
    click_on t('forms.buttons.upload_photos')
  end

  def complete_choose_id_type_step(
    expect_accessible: false, choose_id_type: nil
  )
    expect(page).to have_content(t('doc_auth.headings.choose_id_type'))

    if choose_id_type == Idp::Constants::DocumentTypes::PASSPORT
      choose(t('doc_auth.forms.id_type_preference.passport'))
    else
      choose(t('doc_auth.forms.id_type_preference.drivers_license'))
    end

    click_on t('forms.buttons.continue')
    expect_page_to_have_no_accessibility_violations(page) if expect_accessible
  end

  def complete_doc_auth_steps_before_document_capture_step(
    expect_accessible: false,
    choose_id_type: nil
  )
    complete_doc_auth_steps_before_hybrid_handoff_step(expect_accessible: expect_accessible)
    # JavaScript-enabled mobile devices will skip directly to document capture, so stop as complete.
    unless page.mode == :headless_chrome_mobile
      expect_page_to_have_no_accessibility_violations(page) if expect_accessible
      complete_hybrid_handoff_step
    end

    complete_choose_id_type_step(expect_accessible:, choose_id_type:)
    expect_page_to_have_no_accessibility_violations(page) if expect_accessible
  end

  def complete_up_to_how_to_verify_step_for_opt_in_ipp(remote: true)
    complete_doc_auth_steps_before_welcome_step
    complete_welcome_step
    complete_agreement_step
    return if page.mode != :headless_chrome_mobile && remote
    if remote
      click_on t('forms.buttons.continue_online')
    else
      click_on t('forms.buttons.continue_ipp')
    end
  end

  def complete_document_capture_step(with_selfie: false)
    if with_selfie
      attach_liveness_images
    else
      expect(page).to have_current_path(idv_document_capture_path)
      attach_images
    end

    submit_images
  end

  # yml_file example: 'spec/fixtures/puerto_rico_resident.yml'
  def complete_document_capture_step_with_yml(proofing_yml, expected_path: idv_ssn_url)
    attach_file I18n.t('doc_auth.headings.document_capture_front'), File.expand_path(proofing_yml)
    attach_file I18n.t('doc_auth.headings.document_capture_back'), File.expand_path(proofing_yml)
    click_on I18n.t('forms.buttons.submit.default')
    expect(page).to have_current_path(expected_path, wait: 10)
  end

  def mobile_device
    Browser.new(mobile_user_agent)
  end

  def complete_doc_auth_steps_before_ssn_step(expect_accessible: false, with_selfie: false)
    complete_doc_auth_steps_before_document_capture_step(expect_accessible: expect_accessible)
    expect(page).to have_content(t('doc_auth.headings.document_capture'))
    complete_document_capture_step(with_selfie: with_selfie)
    expect_page_to_have_no_accessibility_violations(page) if expect_accessible
  end

  def complete_ssn_step
    fill_out_ssn_form_ok
    click_idv_continue
  end

  def complete_doc_auth_steps_before_verify_step(expect_accessible: false, with_selfie: false)
    complete_doc_auth_steps_before_ssn_step(
      expect_accessible: expect_accessible,
      with_selfie: with_selfie,
    )
    complete_ssn_step
    expect_page_to_have_no_accessibility_violations(page) if expect_accessible
  end

  def complete_verify_step
    click_idv_submit_default
  end

  def complete_doc_auth_steps_before_address_step(expect_accessible: false, with_selfie: false)
    complete_doc_auth_steps_before_verify_step(with_selfie: with_selfie)
    expect_page_to_have_no_accessibility_violations(page) if expect_accessible
    click_link t('idv.buttons.change_address_label')
  end

  def complete_doc_auth_steps_before_link_sent_step
    complete_doc_auth_steps_before_hybrid_handoff_step
    click_send_link
  end

  def complete_gpo_verification(user)
    otp = 'ABC123'
    create(
      :gpo_confirmation_code,
      profile: User.find(user.id).pending_profile,
      otp_fingerprint: Pii::Fingerprinter.fingerprint(otp),
    )
    fill_in t('idv.gpo.form.otp_label'), with: otp
    click_button t('idv.gpo.form.submit')
  end

  def complete_letter_enqueued
    # Exit Login.gov and return to SP
    click_on t('idv.cancel.actions.exit', app_name: APP_NAME)
  end

  def complete_all_doc_auth_steps(expect_accessible: false, with_selfie: false)
    complete_doc_auth_steps_before_verify_step(
      expect_accessible: expect_accessible,
      with_selfie: with_selfie,
    )
    complete_verify_step
    expect_page_to_have_no_accessibility_violations(page) if expect_accessible
  end

  def complete_all_doc_auth_steps_before_password_step(expect_accessible: false, with_selfie: false)
    complete_all_doc_auth_steps(expect_accessible: expect_accessible, with_selfie: with_selfie)
    fill_out_phone_form_ok if find('#idv_phone_form_phone').value.blank?
    click_continue
    verify_phone_otp
    expect(page).to have_current_path(idv_enter_password_path, wait: 10)
    expect_page_to_have_no_accessibility_violations(page) if expect_accessible
  end

  def complete_proofing_steps(with_selfie: false)
    complete_all_doc_auth_steps_before_password_step(with_selfie: with_selfie)
    fill_in 'Password', with: RequestHelper::VALID_PASSWORD
    click_continue
    acknowledge_and_confirm_personal_key
    click_agree_and_continue
  end

  def mock_doc_auth_attention_with_barcode
    attention_with_barcode_response = instance_double(
      Faraday::Response,
      status: 200,
      body: LexisNexisFixtures.true_id_barcode_read_attention,
    )
    DocAuth::Mock::DocAuthMockClient.mock_response!(
      method: :get_results,
      response: DocAuth::LexisNexis::Responses::TrueIdResponse.new(
        http_response: attention_with_barcode_response,
        config: DocAuth::LexisNexis::Config.new,
      ),
    )
  end

  def expect_to_try_again(is_hybrid: false)
    click_try_again
    if is_hybrid
      expect(page).to have_current_path(idv_hybrid_mobile_document_capture_url)
    else
      expect(page).to have_current_path(idv_document_capture_path)
    end
  end

  def verify_phone_otp
    choose_idv_otp_delivery_method_sms
    fill_in_code_with_last_phone_otp
    click_submit_default
  end

  def fill_out_address_form_fail
    fill_in 'idv_form_address1', with: '123 Main St'
    fill_in 'idv_form_city', with: 'Nowhere'
    select 'Virginia', from: 'idv_form_state'
    fill_in 'idv_form_zipcode', with: '1'
  end

  def complete_all_idv_steps_with(threatmetrix:)
    allow(IdentityConfig.store).to receive(:otp_delivery_blocklist_maxretry).and_return(300)
    user = create(:user, :fully_registered)
    visit_idp_from_ial1_oidc_sp(
      client_id: service_provider.issuer,
    )
    visit root_path
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_ssn_step
    select threatmetrix, from: :mock_profiling_result
    complete_ssn_step
    complete_verify_step
    complete_phone_step(user)
    complete_enter_password_step(user)
    acknowledge_and_confirm_personal_key
  end

  def expect_rate_limit_warning(expected_remaining_attempts)
    review_issues_rate_limit_warning = strip_tags(
      t(
        'idv.failure.attempts_html',
        count: expected_remaining_attempts,
      ),
    )
    expect(page).to have_content(review_issues_rate_limit_warning)
  end
end
