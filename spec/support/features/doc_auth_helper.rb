require_relative 'document_capture_step_helper'

module DocAuthHelper
  include DocumentCaptureStepHelper

  GOOD_SSN = Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn]
  SSN_THAT_FAILS_RESOLUTION = '123-45-6666'

  def session_from_completed_flow_steps(finished_step)
    session = { doc_auth: {} }
    Idv::Flows::DocAuthFlow::STEPS.each do |step, klass|
      session[:doc_auth][klass.to_s] = true
      return session if step == finished_step
    end
    session
  end

  def fill_out_ssn_form_with_ssn_that_fails_resolution
    fill_in t('idv.form.ssn_label_html'), with: SSN_THAT_FAILS_RESOLUTION
  end

  def fill_out_ssn_form_with_ssn_that_raises_exception
    fill_in t('idv.form.ssn_label_html'), with: '000-00-0000'
  end

  def fill_out_ssn_form_ok
    fill_in t('idv.form.ssn_label_html'), with: GOOD_SSN
  end

  def fill_out_ssn_form_fail
    fill_in t('idv.form.ssn_label_html'), with: ''
  end

  def click_doc_auth_back_link
    click_on '‹ ' + t('forms.buttons.back')
  end

  def idv_doc_auth_welcome_step
    idv_doc_auth_step_path(step: :welcome)
  end

  def idv_doc_auth_agreement_step
    idv_doc_auth_step_path(step: :agreement)
  end

  def idv_doc_auth_upload_step
    idv_doc_auth_step_path(step: :upload)
  end

  def idv_doc_auth_ssn_step
    idv_doc_auth_step_path(step: :ssn)
  end

  def idv_doc_auth_document_capture_step
    idv_doc_auth_step_path(step: :document_capture)
  end

  def idv_doc_auth_verify_step
    if IdentityConfig.store.doc_auth_verify_info_controller_enabled
      idv_verify_info_path
    else
      idv_doc_auth_step_path(step: :verify)
    end
  end

  def idv_doc_auth_send_link_step
    idv_doc_auth_step_path(step: :send_link)
  end

  def idv_doc_auth_link_sent_step
    idv_doc_auth_step_path(step: :link_sent)
  end

  def idv_doc_auth_email_sent_step
    idv_doc_auth_step_path(step: :email_sent)
  end

  def complete_doc_auth_steps_before_welcome_step(expect_accessible: false)
    visit idv_doc_auth_welcome_step unless current_path == idv_doc_auth_welcome_step
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
  end

  def complete_welcome_step
    click_on t('doc_auth.buttons.continue')
  end

  def complete_doc_auth_steps_before_agreement_step(expect_accessible: false)
    complete_doc_auth_steps_before_welcome_step(expect_accessible: expect_accessible)
    complete_welcome_step
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
  end

  def complete_agreement_step
    find('label', text: t('doc_auth.instructions.consent', app_name: APP_NAME)).click
    click_on t('doc_auth.buttons.continue')
  end

  def complete_doc_auth_steps_before_upload_step(expect_accessible: false)
    complete_doc_auth_steps_before_agreement_step(expect_accessible: expect_accessible)
    complete_agreement_step
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
  end

  def complete_upload_step
    click_on t('doc_auth.info.upload_computer_link')
  end

  def complete_doc_auth_steps_before_document_capture_step(expect_accessible: false)
    complete_doc_auth_steps_before_upload_step(expect_accessible: expect_accessible)
    # JavaScript-enabled mobile devices will skip directly to document capture, so stop as complete.
    return if page.current_path == idv_doc_auth_document_capture_step
    complete_upload_step
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
  end

  def complete_document_capture_step
    attach_and_submit_images
  end

  def complete_doc_auth_steps_before_email_sent_step
    allow(BrowserCache).to receive(:parse).and_return(mobile_device)
    complete_doc_auth_steps_before_upload_step
    click_on t('doc_auth.info.upload_computer_link')
  end

  def complete_doc_auth_steps_before_phone_otp_step(expect_accessible: false)
    complete_doc_auth_steps_before_verify_step(expect_accessible: expect_accessible)
    click_idv_continue
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
    click_idv_continue
  end

  def mobile_device
    Browser.new(
      'Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) \
AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1',
    )
  end

  def complete_doc_auth_steps_before_ssn_step(expect_accessible: false)
    complete_doc_auth_steps_before_document_capture_step(expect_accessible: expect_accessible)
    complete_document_capture_step
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
  end

  def complete_ssn_step
    fill_out_ssn_form_ok
    click_idv_continue
  end

  def complete_doc_auth_steps_before_verify_step(expect_accessible: false)
    complete_doc_auth_steps_before_ssn_step(expect_accessible: expect_accessible)
    complete_ssn_step
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
  end

  def complete_verify_step
    click_idv_continue
  end

  def complete_doc_auth_steps_before_address_step(expect_accessible: false)
    complete_doc_auth_steps_before_verify_step
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
    click_button t('idv.buttons.change_address_label')
  end

  def complete_doc_auth_steps_before_send_link_step
    complete_doc_auth_steps_before_upload_step
    click_on t('doc_auth.buttons.use_phone')
  end

  def complete_doc_auth_steps_before_link_sent_step
    complete_doc_auth_steps_before_send_link_step
    fill_out_doc_auth_phone_form_ok
    click_idv_continue
  end

  def complete_all_doc_auth_steps(expect_accessible: false)
    complete_doc_auth_steps_before_verify_step(expect_accessible: expect_accessible)
    complete_verify_step
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
  end

  def complete_all_doc_auth_steps_before_password_step(expect_accessible: false)
    complete_all_doc_auth_steps(expect_accessible: expect_accessible)
    fill_out_phone_form_ok if find('#idv_phone_form_phone').value.blank?
    click_continue
    verify_phone_otp
    expect(page).to have_current_path(idv_review_path, wait: 10)
    expect(page).to be_axe_clean.according_to :section508, :"best-practice" if expect_accessible
  end

  def complete_proofing_steps
    complete_all_doc_auth_steps_before_password_step
    fill_in 'Password', with: RequestHelper::VALID_PASSWORD
    click_continue
    acknowledge_and_confirm_personal_key
    click_agree_and_continue
  end

  def mock_doc_auth_no_name_pii(method)
    pii_with_no_name = Idp::Constants::MOCK_IDV_APPLICANT.dup
    pii_with_no_name[:last_name] = nil
    DocAuth::Mock::DocAuthMockClient.mock_response!(
      method: method,
      response: DocAuth::Response.new(
        pii_from_doc: pii_with_no_name,
        extra: {
          doc_auth_result: 'Passed',
          billed: true,
        },
        success: true,
        errors: {},
      ),
    )
  end

  def mock_general_doc_auth_client_error(method)
    DocAuth::Mock::DocAuthMockClient.mock_response!(
      method: method,
      response: DocAuth::Response.new(
        success: false,
        errors: { error: I18n.t('doc_auth.errors.general.no_liveness') },
      ),
    )
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
        attention_with_barcode_response,
        DocAuth::LexisNexis::Config.new,
      ),
    )
  end

  def mock_doc_auth_acuant_error_unknown
    failed_http_response = instance_double(
      Faraday::Response,
      body: AcuantFixtures.get_results_response_failure,
    )
    DocAuth::Mock::DocAuthMockClient.mock_response!(
      method: :get_results,
      response: DocAuth::Acuant::Responses::GetResultsResponse.new(
        failed_http_response,
        DocAuth::Acuant::Config.new,
      ),
    )
  end

  def set_up_document_capture_result(uuid:, idv_result:)
    dcs = DocumentCaptureSession.where(uuid: uuid).first_or_create
    dcs.create_doc_auth_session
    if idv_result
      dcs.store_doc_auth_result(
        result: idv_result.except(:pii_from_doc),
        pii: idv_result[:pii_from_doc],
      )
    end
  end

  def verify_phone_otp
    choose_idv_otp_delivery_method_sms
    fill_in_code_with_last_phone_otp
    click_submit_default
  end

  def fill_out_address_form_ok
    fill_in 'idv_form_address1', with: '123 Main St'
    fill_in 'idv_form_city', with: 'Nowhere'
    select 'Virginia', from: 'idv_form_state'
    fill_in 'idv_form_zipcode', with: '66044'
  end

  def fill_out_address_form_resolution_fail
    fill_in 'idv_form_address1', with: '123 Main St'
    fill_in 'idv_form_city', with: 'Nowhere'
    select 'Virginia', from: 'idv_form_state'
    fill_in 'idv_form_zipcode', with: '00000'
  end

  def fill_out_address_form_fail
    fill_in 'idv_form_address1', with: '123 Main St'
    fill_in 'idv_form_city', with: 'Nowhere'
    select 'Virginia', from: 'idv_form_state'
    fill_in 'idv_form_zipcode', with: '1'
  end

  def fill_out_doc_auth_phone_form_ok(phone = '415-555-0199')
    fill_in :doc_auth_phone, with: phone
  end
end
