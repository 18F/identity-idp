require 'rails_helper'

RSpec.feature 'ddp document capture step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper
  include PassportApiHelpers
  include AbTestsHelper
  include ActionView::Helpers::DateHelper

  let(:fake_analytics) { FakeAnalytics.new }
  let(:passports_enabled) { true }
  let(:choose_id_type) { nil }
  let(:success_response_body) { LexisNexisFixtures.ddp_true_id_state_id_response_success }
  let(:success_passport_response_body) { LexisNexisFixtures.ddp_true_id_passport_response_success }
  let(:fail_response_body) { LexisNexisFixtures.ddp_true_id_response_fail }
  let(:fail_passport_response_body) { LexisNexisFixtures.ddp_true_id_response_fail_passport }
  let(:lexisnexis_threatmetrix_base_url) { 'https://test-base-url.com' }
  let(:fake_dos_api_endpoint) { 'http://fake_dos_api_endpoint/' }
  let(:test_request_url) do
    'https://test-base-url.com/authentication/v1/trueid/'
  end
  let(:response_body) { nil }

  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return(@sp_name)
    allow(IdentityConfig.store).to receive_messages(
      doc_auth_passports_enabled: passports_enabled,
      doc_auth_vendor_default: Idp::Constants::Vendors::LEXIS_NEXIS_DDP,
      doc_auth_passport_vendor_default: Idp::Constants::Vendors::LEXIS_NEXIS_DDP,
      lexisnexis_threatmetrix_api_key: 'test_api_key',
      lexisnexis_threatmetrix_org_id: 'org_id_str',
      lexisnexis_threatmetrix_api_secret: 'test_api_secret',
      lexisnexis_threatmetrix_base_url: lexisnexis_threatmetrix_base_url,
      lexisnexis_threatmetrix_timeout: 10,
      lexisnexis_trueid_account_id: 'test_account_id',
      lexisnexis_trueid_username: 'test_username',
      lexisnexis_trueid_password: 'test_password',
      lexisnexis_trueid_ddp_noliveness_policy: 'default_auth_policy_pm',
      dos_passport_mrz_endpoint: fake_dos_api_endpoint,
    )
    stub_health_check_settings
    stub_health_check_endpoints_success
    stub_request(:post, fake_dos_api_endpoint)
      .to_return_json({ status: 200, body: { response: 'YES' } })
    stub_request(:post, test_request_url)
      .to_return(status: 200, body: response_body.to_s, headers: {})
    visit_idp_from_oidc_sp_with_ial2
    sign_in_and_2fa_user(@user)
    complete_doc_auth_steps_before_document_capture_step(choose_id_type: choose_id_type)
  end

  before(:all) do
    @sp_name = 'Test SP'
    @user = user_with_2fa
  end

  after(:all) { @user.destroy }

  context 'standard desktop flow happy path' do
    context 'successful drivers license response' do
      let(:response_body) { success_response_body }

      it 'lands on the ssn page and logs event' do
        expect(page).to have_current_path(idv_document_capture_path)
        attach_and_submit_images
        expect(page).to have_current_path(idv_ssn_url)
        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth image upload vendor submitted',
          hash_including(
            vendor: 'TrueID DDP',
            success: true,
            document_type_received: Idp::Constants::DocumentTypes::DRIVERS_LICENSE,
          ),
        )
      end
    end

    context 'successful passport response', allow_browser_log: true do
      let(:response_body) { success_passport_response_body }
      let(:choose_id_type) { Idp::Constants::DocumentTypes::PASSPORT }

      it 'lands on the ssn page and logs event' do
        expect(page).to have_current_path(idv_document_capture_path)
        attach_passport_image
        submit_images
        expect(page).to have_current_path(idv_ssn_url)
        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth image upload vendor submitted',
          hash_including(
            vendor: 'TrueID DDP',
            success: true,
            document_type_received: Idp::Constants::DocumentTypes::PASSPORT,
          ),
        )
      end
    end
  end

  context 'standard desktop flow error path', allow_browser_log: true do
    let(:max_attempts) { 2 }
    before do
      allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
    end

    context 'failed drivers license response' do
      let(:response_body) { fail_response_body }

      it 'lands on the document capture page with rate limit' do
        expect(page).to have_current_path(idv_document_capture_path)
        attach_and_submit_images
        expect(page).to have_current_path(idv_document_capture_path)
        expect_rate_limit_warning(max_attempts - 1)
        click_on t('idv.failure.button.warning')
        attach_images(Rails.root.join('app', 'assets', 'images', 'sp-logos', 'gsa.png'))
        submit_images
        expect(page).to have_current_path(idv_session_errors_rate_limited_path)
        expect(fake_analytics).to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :idv_doc_auth,
          user_id: @user.uuid,
        )
      end
    end

    context 'failed passport response' do
      let(:response_body) { fail_passport_response_body }
      let(:choose_id_type) { Idp::Constants::DocumentTypes::PASSPORT }

      it 'lands on the document capture page with rate limit' do
        expect(page).to have_current_path(idv_document_capture_path)

        attach_passport_image
        submit_images
        expect(page).to have_current_path(idv_document_capture_path)
        expect_rate_limit_warning(max_attempts - 1)
        click_on t('idv.failure.button.warning')
        attach_passport_image(Rails.root.join('app', 'assets', 'images', 'sp-logos', 'gsa.png'))
        submit_images
        expect(page).to have_current_path(idv_session_errors_rate_limited_path)
        expect(fake_analytics).to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :idv_doc_auth,
          user_id: @user.uuid,
        )
      end
    end
  end
end
