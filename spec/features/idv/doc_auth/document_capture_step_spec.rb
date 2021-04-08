require 'rails_helper'

feature 'doc auth document capture step' do
  include IdvStepHelper
  include DocAuthHelper

  let(:max_attempts) { AppConfig.env.acuant_max_attempts.to_i }
  let(:user) { user_with_2fa }
  let(:liveness_enabled) { false }
  let(:fake_analytics) { FakeAnalytics.new }
  before do
    allow(IdentityConfig.store).to receive(:liveness_checking_enabled).
      and_return(liveness_enabled)
    allow(Identity::Hostdata::EC2).to receive(:load).
      and_return(OpenStruct.new(region: 'us-west-2', account_id: '123456789'))
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_document_capture_step
  end

  context 'when liveness checking is enabled' do
    let(:liveness_enabled) { true }

    it 'is on the correct_page and shows the document upload options' do
      expect(current_path).to eq(idv_doc_auth_document_capture_step)
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
      allow_any_instance_of(ApplicationController).
        to receive(:analytics).and_return(fake_analytics)

      attach_and_submit_images

      expect(page).to have_current_path(next_step)
      expect(fake_analytics).to have_logged_event(
        Analytics::DOC_AUTH + ' submitted',
        step: 'document_capture',
        result: 'Passed',
        billed: true,
      )
      expect(fake_analytics).to have_logged_event(
        'IdV: ' + "#{Analytics::DOC_AUTH} document_capture submitted".downcase,
        step: 'document_capture',
        result: 'Passed',
        billed: true,
      )
      expect_costing_for_document
    end

    it 'does not proceed to the next page with invalid info' do
      mock_general_doc_auth_client_error(:create_document)

      attach_and_submit_images

      expect(page).to have_current_path(idv_doc_auth_document_capture_step)
    end

    it 'does not proceed to the next page with a successful doc auth but missing information' do
      allow_any_instance_of(ApplicationController).
        to receive(:analytics).and_return(fake_analytics)

      mock_doc_auth_no_name_pii(:post_images)
      attach_and_submit_images

      expect(page).to have_current_path(idv_doc_auth_document_capture_step)

      expect(fake_analytics).to have_logged_event(
        Analytics::DOC_AUTH + ' submitted',
        step: 'document_capture',
        result: 'Passed',
        billed: true,
        success: false,
      )
      expect(fake_analytics).to have_logged_event(
        'IdV: ' + "#{Analytics::DOC_AUTH} document_capture submitted".downcase,
        step: 'document_capture',
        result: 'Passed',
        billed: true,
        success: false,
      )
    end

    it 'throttles calls to acuant and allows retry after the attempt window' do
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
      allow(AppConfig.env).to receive(:acuant_max_attempts).and_return(max_attempts)
      max_attempts.times do
        attach_and_submit_images

        expect(page).to have_current_path(next_step)
        click_on t('doc_auth.buttons.start_over')
        complete_doc_auth_steps_before_document_capture_step
      end

      attach_and_submit_images

      expect(page).to have_current_path(idv_session_errors_throttled_path)
      expect(fake_analytics).to have_logged_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: :idv_acuant,
      )

      Timecop.travel(AppConfig.env.acuant_attempt_window_in_minutes.to_i.minutes.from_now) do
        sign_in_and_2fa_user(user)
        complete_doc_auth_steps_before_document_capture_step
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

      expect(page).to have_current_path(idv_doc_auth_document_capture_step)
      expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
    end
  end

  context 'when liveness checking is not enabled' do
    let(:liveness_enabled) { false }

    it 'is on the correct_page and shows the document upload options' do
      expect(current_path).to eq(idv_doc_auth_document_capture_step)
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
      expect_costing_for_document
    end

    it 'throttles calls to acuant and allows retry after the attempt window' do
      allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
      allow(AppConfig.env).to receive(:acuant_max_attempts).and_return(max_attempts)
      max_attempts.times do
        attach_and_submit_images

        expect(page).to have_current_path(next_step)
        click_on t('doc_auth.buttons.start_over')
        complete_doc_auth_steps_before_document_capture_step
      end

      attach_and_submit_images

      expect(page).to have_current_path(idv_session_errors_throttled_path)
      expect(fake_analytics).to have_logged_event(
        Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
        throttle_type: :idv_acuant,
      )

      Timecop.travel(AppConfig.env.acuant_attempt_window_in_minutes.to_i.minutes.from_now) do
        sign_in_and_2fa_user(user)
        complete_doc_auth_steps_before_document_capture_step
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

      expect(page).to have_current_path(idv_doc_auth_document_capture_step)
      expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
    end
  end

  context 'when there is a stored result' do
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

      expect(page).to have_current_path(idv_doc_auth_document_capture_step)
      expect(page).to have_content(I18n.t('errors.doc_auth.acuant_network_error'))
    end

    it 'does not proceed to the next step if there is no result' do
      submit_empty_form

      expect(page).to have_current_path(idv_doc_auth_document_capture_step)
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

  context 'when using async uploads', :js do
    before do
      allow(DocumentProofingJob).to receive(:perform_later).
        and_call_original
    end

    it 'proceeds to the next page with valid info' do
      set_up_document_capture_result(
        uuid: DocumentCaptureSession.last.uuid,
        idv_result: {
          success: true,
          errors: {},
          messages: ['message'],
          pii_from_doc: {
          first_name: Faker::Name.first_name,
          last_name: Faker::Name.last_name,
          dob: Time.zone.today.to_s,
          address1: Faker::Address.street_address,
          city: Faker::Address.city,
          state: Faker::Address.state_abbr,
          zipcode: Faker::Address.zip_code,
          state_id_type: 'drivers_license',
          state_id_number: '111',
          state_id_jurisdiction: 'WI',
          },
        },
      )

      attach_file 'Front of your ID', 'app/assets/images/logo.png'
      attach_file 'Back of your ID', 'app/assets/images/logo.png'

      form = page.find('#document-capture-form')
      front_url = form['data-front-image-upload-url']
      back_url = form['data-back-image-upload-url']
      click_on 'Submit'

      expect(page).to have_current_path(next_step, wait: 20)
      expect(DocumentProofingJob).to have_received(:perform_later) do |encrypted_arguments:, **|
        args = JSON.parse(
          Encryption::Encryptors::SessionEncryptor.new.decrypt(encrypted_arguments),
          symbolize_names: true,
        )[:document_arguments]

        original = File.read('app/assets/images/logo.png')

        encryption_helper = IdentityIdpFunctions::EncryptionHelper.new
        encryption_key = Base64.decode64(args[:encryption_key])

        Capybara.current_driver = :rack_test # ChromeDriver doesn't support `page.status_code`

        page.driver.get front_url
        expect(page).to have_http_status(200)
        front_plain = encryption_helper.decrypt(
          data: page.body, iv: Base64.decode64(args[:front_image_iv]), key: encryption_key,
        )
        expect(front_plain.b).to eq(original.b)

        page.driver.get back_url
        expect(page).to have_http_status(200)
        back_plain = encryption_helper.decrypt(
          data: page.body, iv: Base64.decode64(args[:back_image_iv]), key: encryption_key,
        )
        expect(back_plain.b).to eq(original.b)
      end
    end
  end

  def next_step
    idv_doc_auth_ssn_step
  end

  def submit_empty_form
    page.driver.put(
      current_path,
      doc_auth: { front_image: nil, back_image: nil, selfie_image: nil },
    )
    visit current_path
  end

  def expect_costing_for_document
    %i[acuant_front_image acuant_back_image acuant_result].each do |cost_type|
      expect(costing_for(cost_type)).to be_present
    end
  end

  def costing_for(cost_type)
    SpCost.where(ial: 2, issuer: '', agency_id: 0, cost_type: cost_type.to_s).first
  end
end
