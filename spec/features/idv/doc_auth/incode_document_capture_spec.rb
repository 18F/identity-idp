require 'rails_helper'

RSpec.feature 'incode document capture step', :js, driver: :headless_chrome_mobile do
  include IdvStepHelper
  include DocAuthHelper

  let(:user) { user_with_2fa }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:incode_api_key) { 'test-incode-api-key' }
  let(:incode_api_url) { 'https://demo-api.incodesmile.com/0' }
  let(:incode_flow_id) { '664c851e95c6a50747ab7899' }

  before do
    allow(IdentityConfig.store).to receive_messages(
      incode_enabled: true,
      incode_api_key:,
      incode_api_url:,
      incode_flow_id:,
      incode_sdk_url: '',
      doc_auth_vendor: Idp::Constants::Vendors::INCODE,
      doc_auth_vendor_default: Idp::Constants::Vendors::INCODE,
      doc_auth_vendor_incode_percent: 100,
      doc_auth_vendor_lexis_nexis_percent: 0,
      doc_auth_vendor_switching_enabled: true,
      doc_auth_desktop_test_mode: true,
    )
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    reload_ab_tests
  end

  it 'allows a user to submit a State ID via Incode WebSDK and redirects to update' do
    sign_in_and_2fa_user(user)
    complete_doc_auth_steps_before_hybrid_handoff_step
    complete_choose_id_type_step

    expect(page).to have_current_path(idv_incode_document_capture_path)
    expect(page).to have_css('#incode-document-capture', visible: :all)

    dcs = user.document_capture_sessions.last
    expect(dcs.doc_auth_vendor).to eq(Idp::Constants::Vendors::INCODE)

    stored_result = DocumentCaptureSessionResult.new(
      id: SecureRandom.uuid,
      success: true,
      doc_auth_success: true,
      selfie_status: :none,
      pii: Idp::Constants::MOCK_IDV_APPLICANT,
      attention_with_barcode: false,
      aamva_status: :passed,
    )
    EncryptedRedisStructStorage.store(stored_result)
    dcs.update!(result_id: stored_result.id)

    # Simulate Incode WebSDK completing front + back State ID capture and redirecting to #update
    page.execute_script(<<~JS)
      window.capturedSessionArgs = null;
      window.capturedSides = [];
      window.OnBoarding = {
        create: function(config) {
          window.capturedCreateConfig = config;
          return {
            initialize: function() { return Promise.resolve(); },
            createSession: function(country, token, options) {
              window.capturedSessionArgs = options;
              return Promise.resolve({ token: 'fake-incode-token' });
            },
            renderCamera: function(side, container, options) {
              window.capturedSides.push(side);
              if (side === 'front') {
                options.onSuccess();
              } else {
                window.completeBackCapture = options.onSuccess;
              }
            },
            processId: function() {
              return Promise.resolve({ success: true });
            }
          };
        }
      };
      window.initializeIncodeDocumentCapture();
    JS

    captured_session_args = page.evaluate_script('window.capturedSessionArgs')
    expect(captured_session_args).to eq(
      'configurationId' => incode_flow_id,
      'externalCustomerId' => user.uuid,
      'customFields' => {
        'externalId' => dcs.uuid,
        'externalCustomerId' => user.uuid,
      },
    )
    expect(page.evaluate_script('window.capturedSides')).to eq(['front', 'back'])

    page.execute_script('window.completeBackCapture()')

    expect(page).to have_current_path(idv_ssn_path)
    expect(fake_analytics).to have_logged_event(
      'IdV: doc auth document_capture visited',
      hash_including(step: 'incode_document_capture'),
    )
    expect(fake_analytics).to have_logged_event(
      'IdV: doc auth document_capture submitted',
      hash_including(step: 'incode_document_capture', success: true),
    )
  end
end
