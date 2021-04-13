require 'rails_helper'

feature 'doc capture document capture step' do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  let(:ial2_step_indicator_enabled) { true }
  let(:max_attempts) { IdentityConfig.store.acuant_max_attempts }
  let(:user) { user_with_2fa }
  let(:liveness_enabled) { false }
  let(:sp_requests_ial2_strict) { true }
  let(:fake_analytics) { FakeAnalytics.new }
  before do
    allow(IdentityConfig.store).to receive(:ial2_step_indicator_enabled).
      and_return(ial2_step_indicator_enabled)
    allow(IdentityConfig.store).to receive(:liveness_checking_enabled).
      and_return(liveness_enabled)
    allow(Identity::Hostdata::EC2).to receive(:load).
      and_return(OpenStruct.new(region: 'us-west-2', account_id: '123456789'))
    if sp_requests_ial2_strict
      visit_idp_from_oidc_sp_with_ial2_strict
    else
      visit_idp_from_oidc_sp_with_ial2
    end
    allow_any_instance_of(DeviceDetector).to receive(:device_type).and_return('mobile')
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
      allow(Analytics).to receive(:new).and_return(fake_analytics)
      expect(Analytics).to receive(:new).with(hash_including(user: instance_of(AnonymousUser)))
      visit request_uri

      expect(fake_analytics).to have_logged_event(
        Analytics::DOC_AUTH,
        success: false,
      )
    end
  end

  context 'valid session' do
    it 'logs events as the inherited user' do
      allow(Analytics).to receive(:new).and_return(fake_analytics)
      expect(Analytics).to receive(:new).with(hash_including(user: user))
      complete_doc_capture_steps_before_first_step(user)

      expect(fake_analytics).to have_logged_event(
        Analytics::DOC_AUTH + ' visited',
        step: 'document_capture',
        flow_path: 'hybrid',
      )
    end
  end

  context 'when liveness checking is enabled' do
    let(:ial2_step_indicator_enabled) { true }
    let(:liveness_enabled) { true }

    before do
      allow(IdentityConfig.store).to receive(:ial2_step_indicator_enabled).
        and_return(ial2_step_indicator_enabled)
      complete_doc_capture_steps_before_first_step(user)
    end

    context 'ial2 step indicator enabled' do
      it 'shows the step indicator' do
        expect(page).to have_css(
          '.step-indicator__step--current',
          text: t('step_indicator.flows.idv.verify_id'),
        )
      end
    end

    context 'ial2 step indicator disabled' do
      let(:ial2_step_indicator_enabled) { false }

      it 'does not show the step indicator' do
        expect(page).not_to have_css('.step-indicator')
      end
    end

    context 'when the SP does not request strict IAL2' do
      let(:sp_requests_ial2_strict) { false }

      it 'does not require selfie' do
        attach_file 'doc_auth_front_image', 'app/assets/images/logo.png'
        attach_file 'doc_auth_back_image', 'app/assets/images/logo.png'
        click_idv_continue

        expect(page).to have_current_path(next_step)
        expect(IdentityDocAuth::Mock::DocAuthMockClient.last_uploaded_selfie_image).to be_nil
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

    it 'proceeds to the next page with valid info and logs analytics info' do
      allow(Analytics).to receive(:new).and_return(fake_analytics)
      expect(Analytics).to receive(:new).with(hash_including(user: user))

      attach_and_submit_images

      expect(page).to have_current_path(next_step)
      expect(fake_analytics).to have_logged_event(
        Analytics::DOC_AUTH + ' submitted',
        step: 'document_capture',
        flow_path: 'hybrid',
        result: 'Passed',
        billed: true,
      )
      expect(fake_analytics).to have_logged_event(
        'IdV: ' + "#{Analytics::DOC_AUTH} document_capture submitted".downcase,
        step: 'document_capture',
        flow_path: 'hybrid',
        result: 'Passed',
        billed: true,
      )
    end

    it 'does not proceed to the next page with invalid info' do
      mock_general_doc_auth_client_error(:create_document)
      attach_and_submit_images

      expect(page).to have_current_path(idv_capture_doc_document_capture_step)
    end

    it 'throttles calls to acuant and allows retry after the attempt window' do
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
      IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_front_image,
        response: IdentityDocAuth::Response.new(
          success: false,
          errors: { network: I18n.t('errors.doc_auth.acuant_network_error') },
        ),
      )

      allow(IdentityConfig.store).to receive(:acuant_max_attempts).and_return(max_attempts)
      max_attempts.times do
        attach_and_submit_images
      end

      attach_and_submit_images

      expect(page).to have_current_path(idv_session_errors_throttled_path)
      expect(fake_analytics).to have_logged_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: :idv_acuant,
      )

      IdentityDocAuth::Mock::DocAuthMockClient.reset!

      Timecop.travel(IdentityConfig.store.acuant_attempt_window_in_minutes.minutes.from_now) do
        complete_doc_capture_steps_before_first_step(user)
        attach_and_submit_images

        expect(page).to have_current_path(next_step)
      end
    end

    it 'catches network connection errors on post_front_image' do
      IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_front_image,
        response: IdentityDocAuth::Response.new(
          success: false,
          errors: { network: I18n.t('errors.doc_auth.acuant_network_error') },
        ),
      )

      attach_and_submit_images

      expect(page).to have_current_path(idv_capture_doc_document_capture_step)
      expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
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
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
      IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_front_image,
        response: IdentityDocAuth::Response.new(
          success: false,
          errors: { network: I18n.t('errors.doc_auth.acuant_network_error') },
        ),
      )

      allow(IdentityConfig.store).to receive(:acuant_max_attempts).and_return(max_attempts)
      max_attempts.times do
        attach_and_submit_images
      end

      attach_and_submit_images

      expect(page).to have_current_path(idv_session_errors_throttled_path)
      expect(fake_analytics).to have_logged_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: :idv_acuant,
      )

      IdentityDocAuth::Mock::DocAuthMockClient.reset!

      Timecop.travel(IdentityConfig.store.acuant_attempt_window_in_minutes.minutes.from_now) do
        complete_doc_capture_steps_before_first_step(user)
        attach_and_submit_images

        expect(page).to have_current_path(next_step)
      end
    end

    it 'catches network connection errors on post_front_image' do
      IdentityDocAuth::Mock::DocAuthMockClient.mock_response!(
        method: :post_front_image,
        response: IdentityDocAuth::Response.new(
          success: false,
          errors: { network: I18n.t('errors.doc_auth.acuant_network_error') },
        ),
      )

      attach_and_submit_images

      expect(page).to have_current_path(idv_capture_doc_document_capture_step)
      expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
    end
  end

  context 'when there is a stored result' do
    before do
      complete_doc_capture_steps_before_first_step(user)
    end

    it 'proceeds to the next step if the result was successful' do
      document_capture_session = user.document_capture_sessions.last
      response = IdentityDocAuth::Response.new(success: true)
      document_capture_session.store_result_from_response(response)
      document_capture_session.save!

      submit_empty_form

      expect(page).to have_current_path(next_step)
    end

    it 'does not proceed to the next step if the result was not successful' do
      document_capture_session = user.document_capture_sessions.last
      response = IdentityDocAuth::Response.new(success: false)
      document_capture_session.store_result_from_response(response)
      document_capture_session.save!

      submit_empty_form

      expect(page).to have_current_path(idv_capture_doc_document_capture_step)
      expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
    end

    it 'does not proceed to the next step if there is no result' do
      submit_empty_form

      expect(page).to have_current_path(idv_capture_doc_document_capture_step)
    end

    it 'uses the form params if form params are present' do
      document_capture_session = user.document_capture_sessions.last
      response = IdentityDocAuth::Response.new(success: false)
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
