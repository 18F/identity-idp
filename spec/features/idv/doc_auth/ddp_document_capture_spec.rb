require 'rails_helper'

RSpec.feature 'document capture step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper
  include PassportApiHelpers
  include AbTestsHelper
  include ActionView::Helpers::DateHelper

  let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:attempts_api_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:fraud_ops_tracker) { AttemptsApiTrackingHelper::FakeAttemptsTracker.new }
  let(:passports_enabled) { true }
  let(:success_response_body) { LexisNexisFixtures.ddp_true_id_state_id_response_success }
  let(:fail_response_body) { LexisNexisFixtures.ddp_true_id_response_fail }
  let(:lexisnexis_threatmetrix_base_url) { 'https://test-base-url.com' }
  let(:test_request_url) do
    'https://test-base-url.com/restws/identity/v3/accounts/test_account_id/workflows/customers.gsa2.trueid.workflow/conversations'
  end

  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ApplicationController).to receive(:attempts_api_tracker).and_return(
      attempts_api_tracker,
    )
    allow_any_instance_of(ApplicationController).to receive(:fraud_ops_tracker).and_return(
      fraud_ops_tracker,
    )
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return(@sp_name)
    allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled)
      .and_return(passports_enabled)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(
      Idp::Constants::Vendors::LEXIS_NEXIS_DDP,
    )
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_api_key).and_return(
      'test_api_key',
    )
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return(
      'test_org_id',
    )
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_api_secret).and_return(
      'test_api_secret',
    )
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_base_url).and_return(
      lexisnexis_threatmetrix_base_url,
    )
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_timeout).and_return(10)
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_account_id).and_return(
      'test_account_id',
    )
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_username).and_return(
      'test_username',
    )
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_password).and_return(
      'test_password',
    )
  end

  before(:all) do
    @sp_name = 'Test SP'
    @user = user_with_2fa
  end

  after(:all) { @user.destroy }

  context 'standard desktop flow happy path' do
    before do
      stub_request(:post, test_request_url)
        .to_return(status: 200, body: success_response_body, headers: {})
      visit_idp_from_oidc_sp_with_ial2
      sign_in_and_2fa_user(@user)
      complete_doc_auth_steps_before_document_capture_step
    end
    it 'lands on the document capture page' do
      binding.pry
      expect(page).to have_current_path(idv_document_capture_path)
      attach_and_submit_images
      binding.pry
      expect(page).to have_current_path(idv_document_capture_path)
    end
  end

  context 'standard desktop flow error path' do
    before do
      stub_request(:post, test_request_url)
        .to_return(status: 200, body: fail_response_body, headers: {})
      visit_idp_from_oidc_sp_with_ial2
      sign_in_and_2fa_user(@user)
      complete_doc_auth_steps_before_document_capture_step
    end
    it 'lands on the document capture page' do
      binding.pry
      expect(page).to have_current_path(idv_document_capture_path)
      attach_and_submit_images
      binding.pry
      expect(page).to have_current_path(idv_document_capture_path)
    end
  end
end
