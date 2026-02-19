require 'rails_helper'

RSpec.describe 'Hybrid Flow DDP', js: true do
  include IdvHelper
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper
  include AbTestsHelper
  include PassportApiHelpers

  let(:phone_number) { '415-555-0199' }
  let(:sp) { :oidc }
  let(:sp_name) { 'Test SP' }
  let(:passports_enabled) { true }
  let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }
  let(:fake_analytics) { FakeAnalytics.new }
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
  let(:document_type_received) { nil }

  before do
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return(sp_name)
    allow(IdentityConfig.store).to receive(:doc_auth_passports_enabled)
      .and_return(passports_enabled)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(
      Idp::Constants::Vendors::LEXIS_NEXIS_DDP,
    )
    allow(IdentityConfig.store).to receive(:doc_auth_passport_vendor_default).and_return(
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
    allow(IdentityConfig.store).to receive(:lexisnexis_threatmetrix_org_id).and_return('org_id_str')
    allow(IdentityConfig.store).to receive(:lexisnexis_trueid_ddp_noliveness_policy)
      .and_return('default_auth_policy_pm')
    stub_health_check_settings
    stub_health_check_endpoints_success
    allow(IdentityConfig.store).to receive(:dos_passport_mrz_endpoint)
      .and_return(fake_dos_api_endpoint)
    stub_request(:post, fake_dos_api_endpoint)
      .to_return_json({ status: 200, body: { response: 'YES' } })
    stub_request(:post, test_request_url)
      .to_return(status: 200, body: response_body.to_s, headers: {})
    allow(FeatureManagement).to receive(:doc_capture_polling_enabled?).and_return(true)
    allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
    allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      @sms_link = config[:link]
      impl.call(**config)
    end.at_least(1).times
  end

  shared_examples 'success ddp flow' do
    it 'ddp routes to capture complete and ssn step', js: true do
      user = nil

      perform_in_browser(:desktop) do
        # visit_idp_from_sp_with_ial2(sp)
        user = user_with_2fa
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user(user)

        complete_doc_auth_steps_before_hybrid_handoff_step
        clear_and_fill_in(:doc_auth_phone, phone_number)
        click_send_link

        expect(page).to have_content(t('doc_auth.headings.text_message'))
        expect(page).to have_content(t('doc_auth.info.you_entered'))
        expect(page).to have_content('+1 415-555-0199')

        # Confirm that Continue button is not shown when polling is enabled
        expect(page).not_to have_content(t('doc_auth.buttons.continue'))
      end

      expect(@sms_link).to be_present

      perform_in_browser(:mobile) do
        visit @sms_link

        complete_choose_id_type_step(choose_id_type: choose_id_type)
        expect(page).to have_current_path(idv_hybrid_mobile_document_capture_url)
        if choose_id_type == Idp::Constants::DocumentTypes::PASSPORT
          attach_passport_image
          submit_images
        else
          attach_and_submit_images
        end
        expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
      end

      perform_in_browser(:desktop) do
        expect(page).to_not have_content(t('doc_auth.headings.text_message'), wait: 10)
        expect(page).to have_current_path(idv_ssn_path)
        expect(fake_analytics).to have_logged_event(
          'IdV: doc auth image upload vendor submitted',
          hash_including(
            vendor: 'TrueID DDP',
            success: true,
            document_type_received: document_type_received,
          ),
        )
      end
    end
  end

  context 'success drivers license ddp' do
    let(:response_body) { success_response_body }
    let(:document_type_received) { Idp::Constants::DocumentTypes::DRIVERS_LICENSE }

    it_behaves_like 'success ddp flow'
  end

  context 'success passport ddp' do
    let(:response_body) { success_passport_response_body }
    let(:choose_id_type) { Idp::Constants::DocumentTypes::PASSPORT }
    let(:document_type_received) { Idp::Constants::DocumentTypes::PASSPORT }

    it_behaves_like 'success ddp flow'
  end

  shared_examples 'failed ddp flow' do
    let(:max_attempts) { 2 }
    it 'ddp fail routes to rate limit page', js: true do
      user = nil

      perform_in_browser(:desktop) do
        # visit_idp_from_sp_with_ial2(sp)
        user = user_with_2fa
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user(user)

        complete_doc_auth_steps_before_hybrid_handoff_step
        clear_and_fill_in(:doc_auth_phone, phone_number)
        click_send_link

        expect(page).to have_content(t('doc_auth.headings.text_message'))
        expect(page).to have_content(t('doc_auth.info.you_entered'))
        expect(page).to have_content('+1 415-555-0199')

        # Confirm that Continue button is not shown when polling is enabled
        expect(page).not_to have_content(t('doc_auth.buttons.continue'))
      end

      expect(@sms_link).to be_present

      perform_in_browser(:mobile) do
        visit @sms_link

        complete_choose_id_type_step(choose_id_type: choose_id_type)
        expect(page).to have_current_path(idv_hybrid_mobile_document_capture_url)
        if choose_id_type == Idp::Constants::DocumentTypes::PASSPORT
          attach_passport_image
          submit_images
        else
          attach_and_submit_images
        end
        expect(page).to have_current_path(idv_hybrid_mobile_document_capture_url)
        expect_rate_limit_warning(max_attempts - 1)
        click_on t('idv.failure.button.warning')
        if choose_id_type == Idp::Constants::DocumentTypes::PASSPORT
          attach_passport_image(Rails.root.join('app', 'assets', 'images', 'sp-logos', 'gsa.png'))
        else
          attach_images(Rails.root.join('app', 'assets', 'images', 'sp-logos', 'gsa.png'))
        end
        submit_images
        expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
      end

      perform_in_browser(:desktop) do
        expect(page).to_not have_content(t('doc_auth.headings.text_message'), wait: 10)
        expect(page).to have_current_path(idv_session_errors_rate_limited_path)
        expect(fake_analytics).to have_logged_event(
          'Rate Limit Reached',
          limiter_type: :idv_doc_auth,
          user_id: user.uuid,
        )
      end
    end
  end

  context 'failed drivers license ddp' do
    let(:response_body) { fail_response_body }
    let(:document_type_received) { Idp::Constants::DocumentTypes::DRIVERS_LICENSE }

    it_behaves_like 'failed ddp flow'
  end

  context 'failed passport ddp' do
    let(:response_body) { fail_passport_response_body }
    let(:choose_id_type) { Idp::Constants::DocumentTypes::PASSPORT }
    let(:document_type_received) { Idp::Constants::DocumentTypes::PASSPORT }

    it_behaves_like 'failed ddp flow'
  end
end
