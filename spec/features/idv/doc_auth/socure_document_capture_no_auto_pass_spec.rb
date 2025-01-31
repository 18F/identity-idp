require 'rails_helper'

RSpec.feature 'document capture step', :js, :allow_browser_log do
  include IdvStepHelper

  before(:each) do
    allow(IdentityConfig.store).to receive(:socure_docv_enabled).and_return(true)
    allow(DocAuthRouter).to receive(:doc_auth_vendor_for_bucket).and_return(Idp::Constants::Vendors::SOCURE)

    stub_request(
      :post,
      IdentityConfig.store.socure_docv_document_request_endpoint,
    ).to_return(
      status: 200,
      headers: {},
      body: {
        referenceId: 'socure-reference-id',
        data: {
          eventId: 'socure-event-id',
          docvTransactionToken: 'docv-transaction-token',
          qrCode: 'qr-code',
          url: 'fake-socure-capture-app',
        },
      }.to_json,
    )

    stub_request(
      :post,
      "#{IdentityConfig.store.socure_idplus_base_url}/api/3.0/EmailAuthScore",
    ).to_return(
      status: 200,
      headers: {},
      body: SocureDocvFixtures.pass_json,
    )
  end

  # ToDo: Remove before merge; sample spec only
  describe 'normal flow', driver: :headless_chrome_mobile do
    it 'succeeds' do
      visit_idp_from_oidc_sp_with_ial2
      user = sign_in_and_2fa_user
      complete_doc_auth_steps_before_hybrid_handoff_step

      click_idv_continue

      socure_docv_upload_documents(
        docv_transaction_token: 'docv-transaction-token',
      )

      visit idv_socure_document_capture_update_path

      document_capture_session_uuid = DocumentCaptureSession.find_by(user_id: user.id).uuid
      SocureDocvResultsJob.new.perform(document_capture_session_uuid:)

      expect(page).to have_current_path(idv_ssn_url)

      complete_ssn_step

      click_submit_default

      fill_in('idv_phone_form_phone', with: '', wait: 10)

      fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
      click_idv_send_security_code

      fill_in_code_with_last_phone_otp
      click_submit_default

      complete_enter_password_step(user)

      acknowledge_and_confirm_personal_key

      validate_idv_completed_page(user)

      click_agree_and_continue
    end
  end

  # ToDo: Remove before merge; sample spec only
  describe 'hybrid handoff' do
    attr_accessor :sms_link

    before do
      allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
        self.sms_link = config[:link]
        impl.call(**config)
      end
    end

    it 'succeeds' do
      user = nil

      perform_in_browser(:desktop, driver: :headless_chrome) do
        visit_idp_from_oidc_sp_with_ial2
        user = sign_in_and_2fa_user
        complete_doc_auth_steps_before_hybrid_handoff_step
        click_send_link
      end

      perform_in_browser(:mobile, driver: :headless_chrome_mobile) do
        visit sms_link
        click_idv_continue
        socure_docv_upload_documents(docv_transaction_token: 'docv_transaction_token')
        visit idv_hybrid_mobile_socure_document_capture_update_url
      end

      document_capture_session_uuid = DocumentCaptureSession.find_by(user_id: user.id).uuid
      SocureDocvResultsJob.new.perform(document_capture_session_uuid:)

      perform_in_browser(:desktop, driver: :headless_chrome) do
        click_continue

        expect(page).to have_current_path(idv_ssn_url)

        complete_ssn_step

        click_submit_default

        fill_in('idv_phone_form_phone', with: '', wait: 10)

        fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
        click_idv_send_security_code

        fill_in_code_with_last_phone_otp
        click_submit_default

        complete_enter_password_step(user)

        acknowledge_and_confirm_personal_key

        validate_idv_completed_page(user)

        click_agree_and_continue
      end
    end
  end

  describe 'hybrid handoff retry' do
    attr_accessor :sms_link

    before do
      allow(Telephony).to receive(:send_doc_auth_link).and_wrap_original do |impl, config|
        self.sms_link = config[:link]
        impl.call(**config)
      end
    end

    it 'succeeds' do
      user = nil

      perform_in_browser(:desktop, driver: :headless_chrome) do
        visit_idp_from_oidc_sp_with_ial2
        user = sign_in_and_2fa_user
        complete_doc_auth_steps_before_hybrid_handoff_step
        click_send_link
      end

      perform_in_browser(:mobile, driver: :headless_chrome_mobile) do
        visit sms_link
        click_idv_continue
        socure_docv_upload_documents(docv_transaction_token: 'docv_transaction_token')
        visit idv_hybrid_mobile_socure_document_capture_update_url
      end

      document_capture_session_uuid = DocumentCaptureSession.find_by(user_id: user.id).uuid
      SocureDocvResultsJob.new.perform(document_capture_session_uuid:)

      perform_in_browser(:desktop, driver: :headless_chrome) do
        click_continue

        expect(page).to have_current_path(idv_ssn_url)

        click_link 'Cancel'

        click_button 'Start over'

        click_continue

        complete_agreement_step

        visit idv_hybrid_mobile_socure_document_capture_update_url

        expect(page).to have_current_path(idv_hybrid_mobile_socure_document_capture_update_url)

        visit idv_ssn_url

        expect(page).to have_current_path(idv_hybrid_handoff_url)
      end
    end
  end
end
