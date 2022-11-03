require 'rails_helper'

feature 'doc capture document capture step', js: true do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper

  let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
  let(:user) { user_with_2fa }
  let(:doc_auth_enable_presigned_s3_urls) { false }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:sp_name) { 'Test SP' }
  before do
    allow(IdentityConfig.store).to receive(:doc_auth_enable_presigned_s3_urls).
      and_return(doc_auth_enable_presigned_s3_urls)
    allow(Identity::Hostdata::EC2).to receive(:load).
      and_return(OpenStruct.new(region: 'us-west-2', account_id: '123456789'))
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(DocumentProofingJob).to receive(:build_analytics).
      and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSessionDecorator).to receive(:sp_name).and_return(sp_name)

    visit_idp_from_oidc_sp_with_ial2

    allow_any_instance_of(Browser).to receive(:mobile?).and_return(true)
  end

  it 'is on the correct page and shows the document upload options' do
    complete_doc_capture_steps_before_first_step(user)

    expect(current_path).to eq(idv_capture_doc_document_capture_step)
    expect(page).to have_content(t('doc_auth.headings.document_capture_front'))
    expect(page).to have_content(t('doc_auth.headings.document_capture_back'))
    expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

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
    complete_doc_capture_steps_before_first_step(user)

    attach_and_submit_images

    expect(page).to have_current_path(next_step)
  end

  it 'offers the user the option to cancel and return to desktop' do
    complete_doc_capture_steps_before_first_step(user)

    click_on t('links.cancel')

    expect(page).to have_text(t('idv.cancel.headings.prompt.hybrid'))
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation visited',
      proofing_components: nil,
      request_came_from: 'idv/capture_doc#show',
      step: 'document_capture',
    )

    click_on t('forms.buttons.cancel')

    expect(page).to have_text(t('idv.cancel.headings.confirmation.hybrid'))
    expect(fake_analytics).to have_logged_event(
      'IdV: cancellation confirmed',
      proofing_components: nil,
      step: 'document_capture',
    )
  end

  it 'advances original session once complete' do
    using_doc_capture_session { attach_and_submit_images }

    click_idv_continue
    expect(page).to have_current_path(idv_doc_auth_ssn_step)
    expect(fake_analytics).to have_logged_event(
      'IdV: doc auth document_capture submitted',
      include(
        step: 'document_capture',
        flow_path: 'hybrid',
      ),
    )
  end

  it 'does not advance original session with errors' do
    using_doc_capture_session do
      mock_general_doc_auth_client_error(:create_document)
      attach_and_submit_images
    end

    click_idv_continue
    expect(page).to have_current_path(idv_doc_auth_link_sent_step)
  end

  context 'with attention with barcode result' do
    before do
      mock_doc_auth_attention_with_barcode
      allow(IdentityConfig.store).to receive(:doc_capture_polling_enabled).and_return(true)
    end

    it 'advances original session only after confirmed', allow_browser_log: true do
      request_uri = doc_capture_request_uri(user)

      Capybara.using_session('mobile') do
        visit request_uri
        attach_and_submit_images
        expect(page).to have_content(t('doc_auth.errors.barcode_attention.confirm_info'))
        click_button t('forms.buttons.continue')
      end

      expect(page).to have_current_path(idv_doc_auth_ssn_step, wait: 10)
    end
  end

  context 'when using async uploads' do
    let(:doc_auth_enable_presigned_s3_urls) { true }

    it 'advances original session once complete' do
      using_doc_capture_session do
        set_up_document_capture_result(
          uuid: DocumentCaptureSession.last.uuid,
          idv_result: {
            success: true,
            errors: {},
            pii_from_doc: {},
          },
        )
        click_submit_default
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
        click_submit_default
      end

      click_idv_continue
      expect(page).to have_current_path(idv_doc_auth_link_sent_step)
    end

    context 'with attention with barcode result' do
      before do
        mock_doc_auth_attention_with_barcode
        allow(IdentityConfig.store).to receive(:doc_capture_polling_enabled).and_return(true)
      end

      it 'advances original session only after confirmed', allow_browser_log: true do
        request_uri = doc_capture_request_uri(user)

        Capybara.using_session('mobile') do
          visit request_uri
          attach_and_submit_images
          expect(page).to have_content(t('doc_auth.errors.barcode_attention.confirm_info'))
          click_button t('forms.buttons.continue')
        end

        expect(page).to have_current_path(idv_doc_auth_ssn_step, wait: 10)
      end
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
        'Doc Auth',
        include(
          success: false,
          user_id: 'anonymous-uuid',
        ),
      )
    end
  end

  context 'valid session' do
    it 'logs events as the inherited user' do
      complete_doc_capture_steps_before_first_step(user)
      expect(fake_analytics).to have_logged_event(
        'IdV: doc auth document_capture visited',
        include(
          step: 'document_capture',
          flow_path: 'hybrid',
        ),
      )
    end

    it 'logs return to sp link click' do
      complete_doc_capture_steps_before_first_step(user)
      new_window = window_opened_by do
        click_on t('idv.troubleshooting.options.get_help_at_sp', sp_name: sp_name)
      end

      within_window new_window do
        expect(fake_analytics).to have_logged_event(
          'Return to SP: Failed to proof',
          include(
            step: 'document_capture',
            location: 'document_capture_troubleshooting_options',
          ),
        )
      end
    end
  end

  it 'logs a warning event when there are unknown errors in the response', :allow_browser_log do
    complete_doc_capture_steps_before_first_step(user)

    Tempfile.create(['ia2_mock', '.yml']) do |yml_file|
      yml_file.rewind
      yml_file.puts <<~YAML
        failed_alerts:
        - name: Some Made Up Error
      YAML
      yml_file.close

      attach_images(yml_file.path)
      click_submit_default
    end

    expect(page).to have_content(t('errors.doc_auth.throttled_heading'), wait: 5)
    expect(fake_analytics).to have_logged_event('Doc Auth Warning')
  end

  def next_step
    idv_capture_doc_capture_complete_step
  end
end
