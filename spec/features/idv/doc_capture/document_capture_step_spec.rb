require 'rails_helper'

feature 'doc capture document capture step' do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
  let(:user) { user_with_2fa }
  let(:liveness_enabled) { true }
  let(:sp_requests_ial2_strict) { true }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:sp_name) { 'Test SP' }
  before do
    allow(IdentityConfig.store).to receive(:liveness_checking_enabled).
      and_return(liveness_enabled)
    allow(Identity::Hostdata::EC2).to receive(:load).
      and_return(OpenStruct.new(region: 'us-west-2', account_id: '123456789'))
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSessionDecorator).to receive(:sp_name).and_return(sp_name)
    if sp_requests_ial2_strict
      visit_idp_from_oidc_sp_with_ial2_strict
    else
      visit_idp_from_oidc_sp_with_ial2
    end
    allow_any_instance_of(Browser).to receive(:mobile?).and_return(true)
  end

  it 'offers the user the option to cancel and return to desktop' do
    complete_doc_capture_steps_before_first_step(user)

    click_on t('links.cancel')

    expect(page).to have_text(t('idv.cancel.headings.prompt.hybrid'))
    expect(fake_analytics).to have_logged_event(
      Analytics::IDV_CANCELLATION,
      step: 'document_capture',
    )

    click_on t('forms.buttons.cancel')

    expect(page).to have_text(t('idv.cancel.headings.confirmation.hybrid'))
    expect(fake_analytics).to have_logged_event(
      Analytics::IDV_CANCELLATION_CONFIRMED,
      step: 'document_capture',
    )
  end

  it 'goes back to the right place when clicking "go back" after cancelling' do
    complete_doc_capture_steps_before_first_step(user)

    click_on t('links.cancel')
    click_on t('links.go_back')

    expect(page).to have_current_path(idv_capture_doc_document_capture_step)
    expect(fake_analytics).to have_logged_event(
      Analytics::IDV_CANCELLATION_GO_BACK,
      step: 'document_capture',
    )
  end

  it 'advances original session once complete' do
    using_doc_capture_session { attach_and_submit_images }

    click_idv_continue
    expect(page).to have_current_path(idv_doc_auth_ssn_step)
  end

  it 'does not advance original session with errors' do
    using_doc_capture_session do
      mock_general_doc_auth_client_error(:create_document)
      attach_and_submit_images
    end

    click_idv_continue
    expect(page).to have_current_path(idv_doc_auth_link_sent_step)
  end

  context 'when using async uploads' do
    it 'advances original session once complete' do
      using_doc_capture_session do
        set_up_document_capture_result(
          uuid: DocumentCaptureSession.last.uuid,
          idv_result: {
            success: true,
            errors: {},
            messages: [],
            pii_from_doc: {},
          },
        )
        click_idv_continue
      end

      click_idv_continue
      expect(page).to have_current_path(idv_doc_auth_ssn_step)
    end

    it 'does not advance original session with errors' do
      using_doc_capture_session do
        set_up_document_capture_result(
          uuid: DocumentCaptureSession.last.uuid,
          idv_result: {
            success: false,
            errors: {},
            messages: ['message'],
            pii_from_doc: {},
          },
        )
        click_idv_continue
      end

      click_idv_continue
      expect(page).to have_current_path(idv_doc_auth_link_sent_step)
    end
  end

  context 'invalid session' do
    let!(:request_uri) { doc_capture_request_uri(user) }

    before do
      Capybara.reset_session!
      expired_minutes = (IdentityConfig.store.doc_capture_request_valid_for_minutes + 1).minutes
      document_capture_session = user.document_capture_sessions.last
      document_capture_session.requested_at -= expired_minutes
      document_capture_session.save!
    end

    it 'logs events as an anonymous user' do
      visit request_uri

      expect(fake_analytics).to have_logged_event(
        Analytics::DOC_AUTH,
        success: false,
      )
    end
  end

  context 'valid session' do
    it 'logs events as the inherited user' do
      complete_doc_capture_steps_before_first_step(user)
      expect(fake_analytics).to have_logged_event(
        'IdV: ' + "#{Analytics::DOC_AUTH} document_capture visited".downcase,
        step: 'document_capture',
        flow_path: 'hybrid',
      )
    end

    context 'when javascript is enabled', :js do
      it 'logs return to sp link click' do
        complete_doc_capture_steps_before_first_step(user)
        new_window = window_opened_by do
          click_on t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name)
        end

        within_window new_window do
          expect(fake_analytics).to have_logged_event(
            'Return to SP: Failed to proof',
            step: 'document_capture',
            location: 'document_capture_troubleshooting_options',
          )
        end
      end
    end
  end

  context 'when liveness checking is enabled' do
    let(:liveness_enabled) { true }

    before do
      complete_doc_capture_steps_before_first_step(user)
    end

    it 'shows the step indicator' do
      expect(page).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.verify_id'),
      )
    end

    context 'when the SP does not request strict IAL2' do
      let(:sp_requests_ial2_strict) { false }

      it 'does not require selfie' do
        attach_file 'doc_auth_front_image', 'app/assets/images/logo.png'
        attach_file 'doc_auth_back_image', 'app/assets/images/logo.png'
        click_idv_continue

        expect(page).to have_current_path(next_step)
        expect(DocAuth::Mock::DocAuthMockClient.last_uploaded_selfie_image).to be_nil
      end

      it 'is on the correct_page and shows the document upload options' do
        expect(current_path).to eq(idv_capture_doc_document_capture_step)
        expect(page).to have_content(t('doc_auth.headings.document_capture_front'))
        expect(page).to have_content(t('doc_auth.headings.document_capture_back'))
      end

      it 'does not show the selfie upload option' do
        expect(page).not_to have_content(t('doc_auth.headings.document_capture_selfie'))
      end

      it 'displays doc capture tips' do
        expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_header_text'))
        expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text1'))
        expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text2'))
        expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text3'))
        expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text4'))
        expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_hint'))
      end

      it 'does not display selfie tips' do
        expect(page).not_to have_content(I18n.t('doc_auth.tips.document_capture_selfie_text1'))
        expect(page).not_to have_content(I18n.t('doc_auth.tips.document_capture_selfie_text2'))
        expect(page).not_to have_content(I18n.t('doc_auth.tips.document_capture_selfie_text3'))
      end
    end

    it 'is on the correct_page and shows the document upload options' do
      expect(current_path).to eq(idv_capture_doc_document_capture_step)
      expect(page).to have_content(t('doc_auth.headings.document_capture_front'))
      expect(page).to have_content(t('doc_auth.headings.document_capture_back'))
    end

    it 'shows the selfie upload option' do
      expect(page).to have_content(t('doc_auth.headings.document_capture_selfie'))
    end

    it 'displays doc capture tips' do
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_header_text'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text1'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text2'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text3'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text4'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_hint'))
    end

    it 'displays selfie tips' do
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_selfie_text1'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_selfie_text2'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_selfie_text3'))
    end

    it 'logs a warning event when there are unknown errors in the response' do
      Tempfile.create(['ia2_mock', '.yml']) do |yml_file|
        yml_file.rewind
        yml_file.puts <<~YAML
          failed_alerts:
          - name: Some Made Up Error
        YAML
        yml_file.close

        attach_file 'doc_auth_front_image', yml_file.path
        attach_file 'doc_auth_back_image', yml_file.path
        attach_file 'doc_auth_selfie_image', yml_file.path
        click_idv_continue
      end

      expect(fake_analytics).to have_logged_event('Doc Auth Warning', {})
    end

    it 'proceeds to the next page with valid info and logs analytics info' do
      attach_and_submit_images

      expect(page).to have_current_path(next_step)
      expect(fake_analytics).to have_logged_event(
        'IdV: ' + "#{Analytics::DOC_AUTH} document_capture submitted".downcase,
        step: 'document_capture',
        flow_path: 'hybrid',
        doc_auth_result: 'Passed',
        billed: true,
      )
    end

    it 'does not proceed to the next page with invalid info' do
      mock_general_doc_auth_client_error(:create_document)
      attach_and_submit_images

      expect(page).to have_current_path(idv_capture_doc_document_capture_step)
    end

    it 'throttles calls to acuant and allows retry after the attempt window' do
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_front_image,
        response: DocAuth::Response.new(
          success: false,
          errors: { network: I18n.t('doc_auth.errors.general.network_error') },
        ),
      )

      allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
      max_attempts.times do
        attach_and_submit_images
      end

      attach_and_submit_images

      expect(page).to have_current_path(idv_session_errors_throttled_path)
      expect(fake_analytics).to have_logged_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: :idv_doc_auth,
      )

      DocAuth::Mock::DocAuthMockClient.reset!

      travel_to(IdentityConfig.store.doc_auth_attempt_window_in_minutes.minutes.from_now + 1) do
        complete_doc_capture_steps_before_first_step(user)
        attach_and_submit_images

        expect(page).to have_current_path(next_step)
      end
    end

    it 'catches network connection errors on post_front_image' do
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_front_image,
        response: DocAuth::Response.new(
          success: false,
          errors: { network: I18n.t('doc_auth.errors.general.network_error') },
        ),
      )

      attach_and_submit_images

      expect(page).to have_current_path(idv_capture_doc_document_capture_step)
      expect(page).to have_content(I18n.t('doc_auth.errors.general.network_error'))
    end
  end

  context 'when liveness checking is not enabled' do
    let(:liveness_enabled) { false }

    before do
      complete_doc_capture_steps_before_first_step(user)
    end

    it 'is on the correct_page and shows the document upload options' do
      expect(current_path).to eq(idv_capture_doc_document_capture_step)
      expect(page).to have_content(t('doc_auth.headings.document_capture_front'))
      expect(page).to have_content(t('doc_auth.headings.document_capture_back'))
    end

    it 'does not show the selfie upload option' do
      expect(page).not_to have_content(t('doc_auth.headings.document_capture_selfie'))
    end

    it 'displays document capture tips' do
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_header_text'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text1'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text2'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text3'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text4'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_hint'))
    end

    it 'does not display selfie tips' do
      expect(page).not_to have_content(I18n.t('doc_auth.tips.document_capture_selfie_text1'))
      expect(page).not_to have_content(I18n.t('doc_auth.tips.document_capture_selfie_text2'))
      expect(page).not_to have_content(I18n.t('doc_auth.tips.document_capture_selfie_text3'))
    end

    it 'proceeds to the next page with valid info' do
      attach_and_submit_images

      expect(page).to have_current_path(next_step)
    end

    it 'throttles calls to acuant and allows retry after the attempt window' do
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_front_image,
        response: DocAuth::Response.new(
          success: false,
          errors: { network: I18n.t('doc_auth.errors.general.network_error') },
        ),
      )

      allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
      max_attempts.times do
        attach_and_submit_images
      end

      attach_and_submit_images

      expect(page).to have_current_path(idv_session_errors_throttled_path)
      expect(fake_analytics).to have_logged_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: :idv_doc_auth,
      )

      DocAuth::Mock::DocAuthMockClient.reset!

      travel_to(IdentityConfig.store.doc_auth_attempt_window_in_minutes.minutes.from_now + 1) do
        complete_doc_capture_steps_before_first_step(user)
        attach_and_submit_images

        expect(page).to have_current_path(next_step)
      end
    end

    it 'catches network connection errors on post_front_image' do
      DocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_front_image,
        response: DocAuth::Response.new(
          success: false,
          errors: { network: I18n.t('doc_auth.errors.general.network_error') },
        ),
      )

      attach_and_submit_images

      expect(page).to have_current_path(idv_capture_doc_document_capture_step)
      expect(page).to have_content(I18n.t('doc_auth.errors.general.network_error'))
    end
  end

  context 'when there is a stored result' do
    before do
      complete_doc_capture_steps_before_first_step(user)
    end

    it 'proceeds to the next step if the result was successful' do
      document_capture_session = user.document_capture_sessions.last
      response = DocAuth::Response.new(success: true)
      document_capture_session.store_result_from_response(response)
      document_capture_session.save!

      submit_empty_form

      expect(page).to have_current_path(next_step)
    end

    it 'does not proceed to the next step if the result was not successful' do
      document_capture_session = user.document_capture_sessions.last
      response = DocAuth::Response.new(success: false)
      document_capture_session.store_result_from_response(response)
      document_capture_session.save!

      submit_empty_form

      expect(page).to have_current_path(idv_capture_doc_document_capture_step)
      expect(page).to have_content(I18n.t('doc_auth.errors.general.network_error'))
    end

    it 'does not proceed to the next step if there is no result' do
      submit_empty_form

      expect(page).to have_current_path(idv_capture_doc_document_capture_step)
    end

    it 'uses the form params if form params are present' do
      document_capture_session = user.document_capture_sessions.last
      response = DocAuth::Response.new(success: false)
      document_capture_session.store_result_from_response(response)
      document_capture_session.save!

      attach_and_submit_images

      expect(page).to have_current_path(next_step)
    end
  end

  def next_step
    idv_capture_doc_capture_complete_step
  end

  def submit_empty_form
    page.driver.put(
      current_path,
      doc_auth: { front_image: nil, back_image: nil, selfie_image: nil },
    )
    visit current_path
  end
end
