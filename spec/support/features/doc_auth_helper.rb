require_relative 'document_capture_step_helper'

module DocAuthHelper
  include DocumentCaptureStepHelper

  def session_from_completed_flow_steps(finished_step)
    session = { doc_auth: {} }
    Idv::Flows::DocAuthFlow::STEPS.each do |step, klass|
      session[:doc_auth][klass.to_s] = true
      return session if step == finished_step
    end
    session
  end

  def fill_out_ssn_form_with_duplicate_ssn
    diff_user = create(:user)
    create(:profile, pii: { ssn: '123-45-6666' }, user: diff_user)
    fill_in 'doc_auth_ssn', with: '123-45-6666'
  end

  def fill_out_ssn_form_with_ssn_that_fails_resolution
    fill_in 'doc_auth_ssn', with: '123-45-6666'
  end

  def fill_out_ssn_form_with_ssn_that_raises_exception
    fill_in 'doc_auth_ssn', with: '000-00-0000'
  end

  def fill_out_ssn_form_ok
    fill_in 'doc_auth_ssn', with: '666-66-1234'
  end

  def fill_out_ssn_form_fail
    fill_in 'doc_auth_ssn', with: ''
  end

  def idv_doc_auth_welcome_step
    idv_doc_auth_step_path(step: :welcome)
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
    idv_doc_auth_step_path(step: :verify)
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
    expect(page).to be_accessible.according_to :section508, :"best-practice" if expect_accessible
  end

  def complete_doc_auth_steps_before_upload_step(expect_accessible: false)
    complete_doc_auth_steps_before_welcome_step(expect_accessible: expect_accessible)
    find('label', text: t('doc_auth.instructions.consent')).click
    click_on t('doc_auth.buttons.continue')
  end

  def complete_doc_auth_steps_before_document_capture_step(expect_accessible: false)
    complete_doc_auth_steps_before_upload_step(expect_accessible: expect_accessible)
    expect(page).to be_accessible.according_to :section508, :"best-practice" if expect_accessible
    click_on t('doc_auth.info.upload_computer_link')
  end

  def complete_doc_auth_steps_before_email_sent_step
    allow(DeviceDetector).to receive(:new).and_return(mobile_device)
    complete_doc_auth_steps_before_upload_step
    click_on t('doc_auth.info.upload_computer_link')
  end


  def mobile_device
    DeviceDetector.new('Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) \
AppleWebKit/604.1.38 (KHTML, like Gecko) Version/11.0 Mobile/15A372 Safari/604.1')
  end

  def complete_doc_auth_steps_before_ssn_step(expect_accessible: false)
    complete_doc_auth_steps_before_document_capture_step(expect_accessible: expect_accessible)
    expect(page).to be_accessible.according_to :section508, :"best-practice" if expect_accessible
    attach_and_submit_images
  end

  def complete_doc_auth_steps_before_verify_step(expect_accessible: false)
    complete_doc_auth_steps_before_ssn_step(expect_accessible: expect_accessible)
    expect(page).to be_accessible.according_to :section508, :"best-practice" if expect_accessible
    fill_out_ssn_form_ok
    click_idv_continue
  end

  def complete_doc_auth_steps_before_address_step(expect_accessible: false)
    complete_doc_auth_steps_before_verify_step
    expect(page).to be_accessible.according_to :section508, :"best-practice" if expect_accessible
    click_link t('doc_auth.buttons.change_address')
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
    expect(page).to be_accessible.according_to :section508, :"best-practice" if expect_accessible
    click_idv_continue
  end

  def mock_doc_auth_no_name_pii(method)
    pii_with_no_name = IdentityDocAuth::Mock::ResultResponseBuilder::DEFAULT_PII_FROM_DOC.dup
    pii_with_no_name[:last_name] = nil
    IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
      method: method,
      response: IdentityDocAuth::Response.new(
        pii_from_doc: pii_with_no_name,
        extra: {
          result: 'Passed',
          billed: true,
        },
        success: true,
        errors: {},
      ),
    )
  end

  def mock_general_doc_auth_client_error(method)
    IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
      method: method,
      response: IdentityDocAuth::Response.new(
        success: false,
        errors: { error: I18n.t('errors.doc_auth.general_error') },
      ),
    )
  end

  def mock_doc_auth_acuant_error_unknown
    failed_http_response = instance_double(
      Faraday::Response,
      body: AcuantFixtures.get_results_response_failure,
    )
    IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
      method: :get_results,
      response: IdentityDocAuth::Acuant::Responses::GetResultsResponse.new(
        failed_http_response,
        IdentityDocAuth::Acuant::Config.new,
      ),
    )
  end

  def set_up_document_capture_result(uuid:, idv_result:)
    dcs = DocumentCaptureSession.where(uuid: uuid).first_or_create
    dcs.create_doc_auth_session
    if idv_result
      dcs.store_doc_auth_result(result: idv_result.except(:pii_from_doc),
                                pii: idv_result[:pii_from_doc])
    end
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
