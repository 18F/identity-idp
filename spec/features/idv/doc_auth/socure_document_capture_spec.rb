require 'rails_helper'

RSpec.feature 'document capture step', :js do
  include IdvStepHelper
  include DocAuthHelper
  include DocCaptureHelper
  include ActionView::Helpers::DateHelper

  let(:max_attempts) { 3 }
  let(:fake_analytics) { FakeAnalytics.new }
  let(:socure_docv_webhook_secret_key) { 'socure_docv_webhook_secret_key' }
  let(:fake_socure_docv_document_request_endpoint) { 'https://fake-socure.test/document-request' }
  let(:fake_socure_document_capture_app_url) { 'https://verify.fake-socure.test/something' }

  before(:each) do
    allow(IdentityConfig.store).to receive(:socure_docv_enabled).and_return(true)
    allow(DocAuthRouter).to receive(:doc_auth_vendor_for_bucket).
      and_return(Idp::Constants::Vendors::SOCURE)
    allow_any_instance_of(ServiceProviderSession).to receive(:sp_name).and_return('Test SP')
    allow(IdentityConfig.store).to receive(:socure_docv_webhook_secret_key).
      and_return(socure_docv_webhook_secret_key)
    allow(IdentityConfig.store).to receive(:socure_docv_document_request_endpoint).
      and_return(fake_socure_docv_document_request_endpoint)
    allow(IdentityConfig.store).to receive(:ruby_workers_idv_enabled).and_return(false)
    allow_any_instance_of(ApplicationController).to receive(:analytics).and_return(fake_analytics)
    @docv_transaction_token = stub_docv_document_request
  end

  before(:all) do
    @user = user_with_2fa
  end

  after(:all) { @user.destroy }

  context 'happy path' do
    before do
      stub_docv_verification_data_pass
    end

    context 'standard desktop flow' do
      before do
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user(@user)
        complete_doc_auth_steps_before_document_capture_step
        click_idv_continue
      end

      context 'rate limits calls to backend docauth vendor', allow_browser_log: true do
        before do
          allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
          (max_attempts - 1).times do
            socure_docv_upload_documents(docv_transaction_token: @docv_transaction_token)
          end
        end

        it 'redirects to the rate limited error page' do
          expect(page).to have_current_path(fake_socure_document_capture_app_url)
          visit idv_socure_document_capture_path
          expect(page).to have_current_path(idv_socure_document_capture_path)
          socure_docv_upload_documents(
            docv_transaction_token: @docv_transaction_token,
          )
          visit idv_socure_document_capture_path
          expect(page).to have_current_path(idv_session_errors_rate_limited_path)
          expect(fake_analytics).to have_logged_event(
            'Rate Limit Reached',
            limiter_type: :idv_doc_auth,
          )
          expect(fake_analytics).to have_logged_event(
            :idv_socure_document_request_submitted,
          )
        end

        context 'successfully processes image on last attempt' do
          before do
            DocAuth::Mock::DocAuthMockClient.reset!
          end

          it 'proceeds to the next page with valid info' do
            expect(page).to have_current_path(fake_socure_document_capture_app_url)
            visit idv_socure_document_capture_path
            expect(page).to have_current_path(idv_socure_document_capture_path)
            socure_docv_upload_documents(
              docv_transaction_token: @docv_transaction_token,
            )

            visit idv_socure_document_capture_update_path
            expect(page).to have_current_path(idv_ssn_url)

            visit idv_socure_document_capture_path

            expect(page).to have_current_path(idv_session_errors_rate_limited_path)
          end
        end
      end

      context 'network connection errors' do
        context 'getting the capture path' do
          before do
            allow_any_instance_of(Faraday::Connection).to receive(:post).
              and_raise(Faraday::ConnectionFailed)
          end

          it 'shows the network error page', js: true do
            visit_idp_from_oidc_sp_with_ial2
            sign_in_and_2fa_user(@user)

            complete_doc_auth_steps_before_document_capture_step

            expect(page).to have_content(t('doc_auth.headers.general.network_error'))
            expect(page).to have_content(t('doc_auth.errors.general.new_network_error'))
          end
        end

        # ToDo post LG-14010. Does this belong here, or on the polling page tests?
        xit 'catches network connection errors on verification data request',
            allow_browser_log: true do
          # expect(page).to have_content(I18n.t('doc_auth.errors.general.network_error'))
        end
      end

      it 'does not track state if state tracking is disabled' do
        allow(IdentityConfig.store).to receive(:state_tracking_enabled).and_return(false)
        socure_docv_upload_documents(
          docv_transaction_token: @docv_transaction_token,
        )

        expect(DocAuthLog.find_by(user_id: @user.id).state).to be_nil
      end

      it 'does track state if state tracking is disabled' do
        allow(IdentityConfig.store).to receive(:state_tracking_enabled).and_return(true)
        socure_docv_upload_documents(
          docv_transaction_token: @docv_transaction_token,
        )

        expect(DocAuthLog.find_by(user_id: @user.id).state).not_to be_nil
      end
    end

    context 'standard mobile flow' do
      it 'proceeds to the next page with valid info' do
        perform_in_browser(:mobile) do
          visit_idp_from_oidc_sp_with_ial2
          sign_in_and_2fa_user(@user)
          complete_doc_auth_steps_before_document_capture_step

          expect(page).to have_current_path(idv_socure_document_capture_url)
          expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))
          click_idv_continue
          socure_docv_upload_documents(
            docv_transaction_token: @docv_transaction_token,
          )
          visit idv_socure_document_capture_update_path
          expect(page).to have_current_path(idv_ssn_url)

          expect(DocAuthLog.find_by(user_id: @user.id).state).to eq('NY')

          fill_out_ssn_form_ok
          click_idv_continue
          complete_verify_step
          expect(page).to have_current_path(idv_phone_url)
        end
      end
    end
  end

  shared_examples 'a properly categorized Socure error' do |socure_error_code, expected_header_key|
    before do
      stub_docv_verification_data_fail_with([socure_error_code])

      visit_idp_from_oidc_sp_with_ial2
      sign_in_and_2fa_user(@user)

      complete_doc_auth_steps_before_document_capture_step

      click_idv_continue
      socure_docv_upload_documents(
        docv_transaction_token: @docv_transaction_token,
      )
      visit idv_socure_document_capture_update_path
    end

    it 'shows the correct error page' do
      expect(page).to have_content(t(expected_header_key))
    end
  end

  context 'a type 1 error (because we do not recognize the code)' do
    it_behaves_like 'a properly categorized Socure error', 'XXXX', 'doc_auth.headers.unreadable_id'
  end

  context 'a type 1 error' do
    it_behaves_like 'a properly categorized Socure error', 'I848', 'doc_auth.headers.unreadable_id'
  end

  context 'a type 2 error' do
    it_behaves_like 'a properly categorized Socure error',
                    'I849',
                    'doc_auth.headers.unaccepted_id_type'
  end

  context 'a type 3 error' do
    it_behaves_like 'a properly categorized Socure error', 'R827', 'doc_auth.headers.expired_id'
  end

  context 'a type 4 error' do
    it_behaves_like 'a properly categorized Socure error', 'I808', 'doc_auth.headers.low_resolution'
  end

  context 'a type 5 error' do
    it_behaves_like 'a properly categorized Socure error', 'R845', 'doc_auth.headers.underage'
  end

  context 'a type 6 error' do
    it_behaves_like 'a properly categorized Socure error', 'I856', 'doc_auth.headers.id_not_found'
  end

  def expect_rate_limited_header(expected_to_be_present)
    review_issues_h1_heading = strip_tags(t('doc_auth.errors.rate_limited_heading'))
    if expected_to_be_present
      expect(page).to have_content(review_issues_h1_heading)
    else
      expect(page).not_to have_content(review_issues_h1_heading)
    end
  end
end

RSpec.feature 'direct access to IPP on desktop', :js do
  include IdvStepHelper
  include DocAuthHelper

  context 'before handoff page' do
    let(:sp_ipp_enabled) { true }
    let(:in_person_proofing_opt_in_enabled) { true }
    let(:facial_match_required) { false }
    let(:user) { user_with_2fa }

    before do
      service_provider = create(:service_provider, :active, :in_person_proofing_enabled)
      allow(IdentityConfig.store).to receive(:doc_auth_selfie_desktop_test_mode).and_return(false)
      allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:in_person_proofing_opt_in_enabled).and_return(
        in_person_proofing_opt_in_enabled,
      )
      allow(IdentityConfig.store).to receive(:allowed_biometric_ial_providers).
        and_return([service_provider.issuer])
      allow(IdentityConfig.store).to receive(
        :allowed_valid_authn_contexts_semantic_providers,
      ).and_return([service_provider.issuer])
      allow_any_instance_of(ServiceProvider).to receive(:in_person_proofing_enabled).
        and_return(false)
      allow(IdentityConfig.store).to receive(:socure_docv_enabled).and_return(true)
      allow(DocAuthRouter).to receive(:doc_auth_vendor_for_bucket).
        and_return(Idp::Constants::Vendors::SOCURE)
      visit_idp_from_sp_with_ial2(
        :oidc,
        **{ client_id: service_provider.issuer,
            facial_match_required: facial_match_required },
      )
      sign_in_via_branded_page(user)
      complete_doc_auth_steps_before_agreement_step

      visit idv_socure_document_capture_path(step: 'hybrid_handoff')
    end

    context 'when selfie is enabled' do
      it 'redirects back to agreement page' do
        expect(page).to have_current_path(idv_agreement_path)
      end
    end

    context 'when selfie is disabled' do
      let(:facial_match_required) { false }

      it 'redirects back to agreement page' do
        expect(page).to have_current_path(idv_agreement_path)
      end
    end
  end
end
