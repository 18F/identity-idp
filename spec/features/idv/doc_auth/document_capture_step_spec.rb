require 'rails_helper'

feature 'doc auth document capture step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include ActionView::Helpers::DateHelper

  let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
  let(:user) { user_with_2fa }
  let(:liveness_enabled) { false }
  let(:doc_auth_enable_presigned_s3_urls) { false }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:sp_name) { 'Test SP' }
  before do
    allow(IdentityConfig.store).to receive(:liveness_checking_enabled).
      and_return(liveness_enabled)
    allow(IdentityConfig.store).to receive(:doc_auth_enable_presigned_s3_urls).
      and_return(doc_auth_enable_presigned_s3_urls)
    allow(Identity::Hostdata::EC2).to receive(:load).
      and_return(OpenStruct.new(region: 'us-west-2', account_id: '123456789'))
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSessionDecorator).to receive(:sp_name).and_return(sp_name)
    if liveness_enabled
      visit_idp_from_oidc_sp_with_ial2_strict
    else
      visit_idp_from_oidc_sp_with_ial2
    end
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_document_capture_step
  end

  it 'logs return to sp link click' do
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

  it 'throttles calls to acuant', allow_browser_log: true do
    allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
    DocAuth::Mock::DocAuthMockClient.mock_response!(
      method: :post_front_image,
      response: DocAuth::Response.new(
        success: false,
        errors: { network: I18n.t('doc_auth.errors.general.network_error') },
      ),
    )

    allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
    (max_attempts - 1).times do
      attach_and_submit_images
      click_on t('idv.failure.button.warning')
    end

    freeze_time do
      attach_and_submit_images
      timeout = distance_of_time_in_words(
        Throttle.attempt_window_in_minutes(:idv_doc_auth).minutes,
      )
      message = strip_tags(t('errors.doc_auth.throttled_text_html', timeout: timeout))
      expect(page).to have_content(message)
    end

    expect(page).to have_current_path(idv_session_errors_throttled_path)
    # Bug: Rate limit event is not always logged (LG-6543)
    # expect(fake_analytics).to have_logged_event(
    #   Analytics::THROTTLER_RATE_LIMIT_TRIGGERED,
    #   throttle_type: :idv_doc_auth,
    # )
  end

  it 'catches network connection errors on post_front_image', allow_browser_log: true do
    DocAuth::Mock::DocAuthMockClient.mock_response!(
      method: :post_front_image,
      response: DocAuth::Response.new(
        success: false,
        errors: { network: I18n.t('doc_auth.errors.general.network_error') },
      ),
    )

    attach_and_submit_images

    expect(page).to have_current_path(idv_doc_auth_document_capture_step)
    expect(page).to have_content(I18n.t('doc_auth.errors.general.network_error'))
  end

  context 'when liveness checking is enabled' do
    let(:liveness_enabled) { true }

    it 'is on the correct page and shows the document upload options' do
      expect(current_path).to eq(idv_doc_auth_document_capture_step)
      expect(page).to have_content(t('doc_auth.headings.document_capture_front'))
      expect(page).to have_content(t('doc_auth.headings.document_capture_back'))
      expect(page).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.verify_id'),
      )

      # Document capture tips
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_header_text'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text1'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text2'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text3'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text4'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_hint'))

      # Selfie option, evidenced by "Continue" button instead of "Submit"
      expect(page).to have_content(t('forms.buttons.continue'))
    end

    it 'proceeds to the next page with valid info and logs analytics info' do
      expect_any_instance_of(DocAuth::Mock::DocAuthMockClient).
        to receive(:post_images).
        with(hash_including(image_source: DocAuth::ImageSources::UNKNOWN)).
        and_call_original

      attach_and_submit_images

      expect(page).to have_current_path(next_step)
      expect(fake_analytics).to have_logged_event(
        'IdV: ' + "#{Analytics::DOC_AUTH} document_capture submitted".downcase,
        step: 'document_capture',
        flow_path: 'standard',
      )
      expect_costing_for_document
    end

    it 'does not proceed to the next page with invalid info', allow_browser_log: true do
      mock_general_doc_auth_client_error(:create_document)

      attach_and_submit_images

      expect(page).to have_current_path(idv_doc_auth_document_capture_step)
    end

    it 'allows users to retake photos with attention with barcode', allow_browser_log: true do
      mock_doc_auth_attention_with_barcode
      attach_and_submit_images

      expect(page).to have_content(t('doc_auth.errors.barcode_attention.confirm_info'))
      expect(page).to have_content('DAVID')
      expect(page).to have_content('SAMPLE')
      expect(page).to have_content('1986-10-13')

      click_button t('doc_auth.buttons.add_new_photos')
      submit_images

      expect(page).to have_content(t('doc_auth.errors.barcode_attention.confirm_info'))
      click_button t('forms.buttons.continue')

      expect(page).to have_current_path(next_step, wait: 10)
    end

    it 'does not proceed if doc auth is success but missing information', allow_browser_log: true do
      mock_doc_auth_no_name_pii(:post_images)
      attach_and_submit_images

      expect(page).to have_current_path(idv_doc_auth_document_capture_step)

      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth image upload vendor pii validation',
        flow_path: 'standard',
        success: false,
      )
    end

    context 'when javascript is enabled', js: true do
      it 'proceeds to the next step' do
        attach_and_submit_images

        expect(page).to have_current_path(next_step)
      end
    end
  end

  context 'when liveness checking is not enabled' do
    let(:liveness_enabled) { false }

    it 'is on the correct page and shows the document upload options' do
      expect(current_path).to eq(idv_doc_auth_document_capture_step)
      expect(page).to have_content(t('doc_auth.headings.document_capture_front'))
      expect(page).to have_content(t('doc_auth.headings.document_capture_back'))
      expect(page).to have_css(
        '.step-indicator__step--current',
        text: t('step_indicator.flows.idv.verify_id'),
      )

      # Document capture tips
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_header_text'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text1'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text2'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text3'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_id_text4'))
      expect(page).to have_content(I18n.t('doc_auth.tips.document_capture_hint'))

      # No selfie option, evidenced by "Submit" button instead of "Continue"
      expect(page).to have_content(t('forms.buttons.submit.default'))
    end

    it 'proceeds to the next page with valid info' do
      attach_and_submit_images

      expect(page).to have_current_path(next_step)
      expect_costing_for_document
      expect(DocAuthLog.find_by(user_id: user.id).state).to eq('MT')
    end

    it 'does not track state if state tracking is disabled' do
      allow(IdentityConfig.store).to receive(:state_tracking_enabled).and_return(false)
      attach_and_submit_images

      expect(DocAuthLog.find_by(user_id: user.id).state).to be_nil
    end
  end

  context 'when using async uploads' do
    let(:doc_auth_enable_presigned_s3_urls) { true }

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
          Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
          symbolize_names: true,
        )[:document_arguments]

        original = File.read('app/assets/images/logo.png')

        encryption_helper = JobHelpers::EncryptionHelper.new
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

    it 'allows users to retake photos with attention with barcode', allow_browser_log: true do
      mock_doc_auth_attention_with_barcode
      attach_and_submit_images

      expect(page).to have_content(t('doc_auth.errors.barcode_attention.confirm_info'))
      expect(page).to have_content('DAVID')
      expect(page).to have_content('SAMPLE')
      expect(page).to have_content('1986-10-13')

      click_button t('doc_auth.buttons.add_new_photos')
      submit_images

      expect(page).to have_content(t('doc_auth.errors.barcode_attention.confirm_info'))
      click_button t('forms.buttons.continue')

      expect(page).to have_current_path(next_step, wait: 10)
    end
  end

  def next_step
    idv_doc_auth_ssn_step
  end

  def expect_costing_for_document
    %i[acuant_front_image acuant_back_image acuant_result].each do |cost_type|
      expect(costing_for(cost_type)).to be_present
    end
  end

  def costing_for(cost_type)
    SpCost.where(ial: 2, issuer: 'urn:gov:gsa:openidconnect:sp:server', cost_type: cost_type.to_s)
  end
end
