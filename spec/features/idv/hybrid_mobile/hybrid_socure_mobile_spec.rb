require 'rails_helper'

RSpec.describe 'Hybrid Flow' do
  include IdvHelper
  include IdvStepHelper
  include DocAuthHelper

  let(:phone_number) { '415-555-0199' }
  let(:sp) { :oidc }
  let(:fake_socure_document_capture_app_url) { 'https://verify.fake-socure.test/something' }
  let(:fake_socure_docv_document_request_endpoint) { 'https://fake-socure.test/document-request' }

  before do
    allow(FeatureManagement).to receive(:doc_capture_polling_enabled?).and_return(true)
    allow(IdentityConfig.store).to receive(:socure_docv_enabled).and_return(true)
    allow(DocAuthRouter).to receive(:doc_auth_vendor_for_bucket).
      and_return(Idp::Constants::Vendors::SOCURE)
    allow(IdentityConfig.store).to receive(:use_vot_in_sp_requests).and_return(true)
    allow(IdentityConfig.store).to receive(:ruby_workers_idv_enabled).and_return(false)
    allow(IdentityConfig.store).to receive(:socure_docv_document_request_endpoint).
      and_return(fake_socure_docv_document_request_endpoint)
    allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
      @sms_link = config[:link]
      impl.call(**config)
    end.at_least(1).times
    @docv_transaction_token = stub_docv_document_request
    stub_analytics
  end

  context 'happy path', allow_browser_log: true do
    it 'proofs and hands off to mobile', js: true do
      user = nil

      perform_in_browser(:desktop) do
        visit_idp_from_sp_with_ial2(sp)
        user = sign_up_and_2fa_ial1_user

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

        # Confirm that jumping to LinkSent page does not cause errors
        visit idv_link_sent_url
        expect(page).to have_current_path(root_url)

        # Confirm that we end up on the LN / Mock page even if we try to
        # go to the Socure one.
        visit idv_hybrid_mobile_socure_document_capture_url
        expect(page).to have_current_path(idv_hybrid_mobile_socure_document_capture_url)

        # Confirm that clicking cancel and then coming back doesn't cause errors
        click_link 'Cancel'
        visit idv_hybrid_mobile_socure_document_capture_url

        # Confirm that jumping to Phone page does not cause errors
        visit idv_phone_url
        expect(page).to have_current_path(root_url)
        visit idv_hybrid_mobile_socure_document_capture_url

        # Confirm that jumping to Welcome page does not cause errors
        visit idv_welcome_url
        expect(page).to have_current_path(root_url)
        visit idv_hybrid_mobile_socure_document_capture_url

        expect(page).to have_current_path(idv_hybrid_mobile_socure_document_capture_url)
        stub_docv_verification_data_pass
        click_idv_continue
        expect(page).to have_current_path(fake_socure_document_capture_app_url)
        socure_docv_upload_documents(docv_transaction_token: @docv_transaction_token)
        visit idv_hybrid_mobile_socure_document_capture_update_url

        expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
        expect(page).to have_content(strip_nbsp(t('doc_auth.headings.capture_complete')))
        expect(page).to have_text(t('doc_auth.instructions.switch_back'))
        expect_step_indicator_current_step(t('step_indicator.flows.idv.verify_id'))

        # To be fixed in app:
        # Confirm app disallows jumping back to DocumentCapture page
        # visit idv_hybrid_mobile_socure_document_capture_url
        # expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
      end

      perform_in_browser(:desktop) do
        expect(page).to_not have_content(t('doc_auth.headings.text_message'), wait: 10)
        expect(page).to have_current_path(idv_ssn_path)
        expect(@analytics).to have_logged_event(:idv_socure_document_request_submitted)
        fill_out_ssn_form_ok
        click_idv_continue

        expect(page).to have_content(t('headings.verify'))
        complete_verify_step

        prefilled_phone = page.find(id: 'idv_phone_form_phone').value

        expect(
          PhoneFormatter.format(prefilled_phone),
        ).to eq(
          PhoneFormatter.format(user.default_phone_configuration.phone),
        )

        fill_out_phone_form_ok
        verify_phone_otp

        fill_in t('idv.form.password'), with: Features::SessionHelper::VALID_PASSWORD
        click_idv_continue

        acknowledge_and_confirm_personal_key

        validate_idv_completed_page(user)
        click_agree_and_continue

        validate_return_to_sp
      end
    end

    it 'shows the waiting screen correctly after cancelling from mobile and restarting', js: true do
      user = nil

      perform_in_browser(:desktop) do
        user = sign_in_and_2fa_user
        complete_doc_auth_steps_before_hybrid_handoff_step
        clear_and_fill_in(:doc_auth_phone, phone_number)
        click_send_link

        expect(page).to have_content(t('doc_auth.headings.text_message'))
      end

      expect(@sms_link).to be_present

      perform_in_browser(:mobile) do
        visit @sms_link
        expect(page).to have_current_path(idv_hybrid_mobile_socure_document_capture_url)
        expect(page).not_to have_content(t('doc_auth.headings.document_capture_selfie'))
        click_on t('links.cancel')
        click_on t('forms.buttons.cancel') # Yes, cancel
      end

      perform_in_browser(:desktop) do
        expect(page).to_not have_content(t('doc_auth.headings.text_message'), wait: 10)
        clear_and_fill_in(:doc_auth_phone, phone_number)
        click_send_link

        expect(page).to have_content(t('doc_auth.headings.text_message'))
      end
    end

    context 'user is rate limited on mobile' do
      let(:max_attempts) { IdentityConfig.store.doc_auth_max_attempts }

      before do
        allow(IdentityConfig.store).to receive(:doc_auth_max_attempts).and_return(max_attempts)
        DocAuth::Mock::DocAuthMockClient.mock_response!(
          method: :post_front_image,
          response: DocAuth::Response.new(
            success: false,
            errors: { network: I18n.t('doc_auth.errors.general.network_error') },
          ),
        )
      end

      it 'shows capture complete on mobile and error page on desktop', js: true do
        user = nil

        perform_in_browser(:desktop) do
          user = sign_in_and_2fa_user
          complete_doc_auth_steps_before_hybrid_handoff_step
          clear_and_fill_in(:doc_auth_phone, phone_number)
          click_send_link

          expect(page).to have_content(t('doc_auth.headings.text_message'))
        end

        expect(@sms_link).to be_present

        perform_in_browser(:mobile) do
          visit @sms_link

          click_idv_continue
          expect(page).to have_current_path(fake_socure_document_capture_app_url)
          stub_docv_verification_data_pass
          max_attempts.times do
            socure_docv_upload_documents(docv_transaction_token: @docv_transaction_token)
          end

          visit idv_hybrid_mobile_socure_document_capture_update_url

          expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
          expect(page).to have_text(t('doc_auth.instructions.switch_back'))
        end

        perform_in_browser(:desktop) do
          expect(page).to have_current_path(idv_session_errors_rate_limited_path, wait: 10)
        end
      end
    end

    it 'prefills the phone number used on the phone step if the user has no MFA phone', :js do
      user = create(:user, :with_authentication_app)

      perform_in_browser(:desktop) do
        start_idv_from_sp(facial_match_required: false)
        sign_in_and_2fa_user(user)

        complete_doc_auth_steps_before_hybrid_handoff_step
        clear_and_fill_in(:doc_auth_phone, phone_number)
        click_send_link
      end

      expect(@sms_link).to be_present

      perform_in_browser(:mobile) do
        visit @sms_link

        expect(page).to have_current_path(idv_hybrid_mobile_socure_document_capture_url)
        stub_docv_verification_data_pass
        click_idv_continue
        expect(page).to have_current_path(fake_socure_document_capture_app_url)
        socure_docv_upload_documents(docv_transaction_token: @docv_transaction_token)
        visit idv_hybrid_mobile_socure_document_capture_update_url

        expect(page).to have_current_path(idv_hybrid_mobile_capture_complete_url)
        expect(page).to have_text(t('doc_auth.instructions.switch_back'))
      end

      perform_in_browser(:desktop) do
        expect(page).to have_current_path(idv_ssn_path, wait: 10)

        fill_out_ssn_form_ok
        click_idv_continue

        expect(page).to have_content(t('headings.verify'))
        complete_verify_step

        prefilled_phone = page.find(id: 'idv_phone_form_phone').value

        expect(
          PhoneFormatter.format(prefilled_phone),
        ).to eq(
          PhoneFormatter.format(phone_number),
        )
      end
    end
  end

  shared_examples 'a properly categorized Socure error' do |socure_error_code, expected_header_key|
    it 'shows the correct error page', js: true do
      user = nil

      perform_in_browser(:desktop) do
        visit_idp_from_sp_with_ial2(sp)
        user = sign_up_and_2fa_ial1_user

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

        stub_docv_verification_data_fail_with([socure_error_code])

        click_idv_continue

        socure_docv_upload_documents(docv_transaction_token: @docv_transaction_token)
        visit idv_hybrid_mobile_socure_document_capture_update_url

        expect(page).to have_text(t(expected_header_key))

        click_try_again

        expect(page).to have_current_path(idv_hybrid_mobile_socure_document_capture_path)
      end

      perform_in_browser(:desktop) do
        expect(page).to have_current_path(idv_link_sent_path)
      end
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

  context 'with a network error requesting the capture app url' do
    before do
      allow_any_instance_of(Faraday::Connection).to receive(:post).
        and_raise(Faraday::ConnectionFailed)
    end

    it 'shows the network error page on the phone and the link sent page on the desktop',
       js: true do
      user = nil

      perform_in_browser(:desktop) do
        visit_idp_from_sp_with_ial2(sp)
        user = sign_up_and_2fa_ial1_user

        complete_doc_auth_steps_before_hybrid_handoff_step
        clear_and_fill_in(:doc_auth_phone, phone_number)
        click_send_link
      end

      perform_in_browser(:mobile) do
        visit @sms_link

        expect(page).to have_text(t('doc_auth.headers.general.network_error'))
        expect(page).to have_text(t('doc_auth.errors.general.new_network_error'))
      end

      perform_in_browser(:desktop) do
        expect(page).to have_current_path(idv_link_sent_path)
      end
    end
  end
end
