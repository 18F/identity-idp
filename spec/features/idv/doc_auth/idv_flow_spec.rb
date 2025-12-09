require 'rails_helper'

RSpec.describe 'Completing all IDV steps', :js, :allow_browser_log do
  include IdvStepHelper
  include InPersonHelper
  include PassportApiHelpers

  let(:user) { user_with_2fa }
  let(:phone_number) { '2028675309' }
  let(:fake_dos_api_endpoint) { 'http://fake_dos_api_endpoint/' }

  before do
    allow(IdentityConfig.store).to receive(:doc_auth_vendor).and_return(doc_auth_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_default).and_return(doc_auth_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_passport_vendor).and_return(doc_auth_vendor)
    allow(IdentityConfig.store).to receive(:doc_auth_passport_vendor_default).and_return(
      doc_auth_vendor,
    )
    allow(IdentityConfig.store).to receive(:doc_auth_vendor_switching_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:dos_passport_mrz_endpoint)
      .and_return(fake_dos_api_endpoint)
    stub_health_check_settings
    stub_health_check_endpoints_success
    stub_request(:post, fake_dos_api_endpoint)
      .to_return_json({ status: 200, body: { response: 'YES' } })
  end

  describe 'when doc auth vendor is "lexis_nexis"' do
    let(:doc_auth_vendor) { 'lexis_nexis' }

    before do
      stub_request(:post, /.*\/restws\/identity\/v3\/accounts\/.*\/workflows\/.*\/conversations/)
        .and_return(status: 200, body: doc_auth_response)
    end

    describe 'IDV State ID flow' do
      let(:doc_auth_response) { LexisNexisFixtures.true_id_response_success }

      scenario 'When the user completes all IDV steps' do
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user(user)
        visit idv_welcome_path
        complete_welcome_step
        complete_agreement_step
        complete_hybrid_handoff_step
        complete_choose_id_type_step
        attach_images(Rails.root.join('spec', 'fixtures', 'doc_auth_images', 'id-front.jpg'))
        submit_images
        complete_ssn_step
        complete_verify_step
        fill_out_phone_form_ok(phone_number)
        verify_phone_otp
        complete_enter_password_step(user)

        expect(page).to have_current_path(idv_personal_key_path)

        profile = user.profiles.last

        expect(profile.active).to be(true)
        expect(profile.decrypt_pii(user.password)).to have_attributes(
          first_name: 'LICENSE',
          middle_name: nil,
          last_name: 'SAMPLE',
          dob: '1966-05-05',
          ssn: Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
          phone: phone_number,
          address1: '123 ABC AVE',
          address2: 'APT 3E',
          city: 'ANYTOWN',
          state: 'NY',
          zipcode: '12345',
          same_address_as_id: nil,
          identity_doc_address1: nil,
          identity_doc_address2: nil,
          identity_doc_city: nil,
          identity_doc_zipcode: nil,
          identity_doc_address_state: nil,
          state_id_jurisdiction: 'NY',
          issuing_country_code: nil,
        )
      end
    end

    describe 'IDV Passport Flow' do
      let(:address1) { '123 Main St' }
      let(:city) { 'Anywhere' }
      let(:state_abbr) { 'VA' }
      let(:state) { 'Virginia' }
      let(:zipcode) { '66044' }
      let(:fake_dos_api_endpoint) { 'http://fake_dos_api_endpoint/' }
      let(:doc_auth_response) { LexisNexisFixtures.true_id_response_passport_without_tamper }

      before do
      end

      scenario 'When the user completes all IDV steps' do
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user(user)
        visit idv_welcome_path
        complete_welcome_step
        complete_agreement_step
        complete_hybrid_handoff_step
        complete_choose_id_type_step(choose_id_type: 'passport')
        attach_passport_image(
          Rails.root.join('spec', 'fixtures', 'doc_auth_images', 'passport.jpg'),
        )
        submit_images
        complete_ssn_step
        fill_in 'idv_form_address1', with: address1
        fill_in 'idv_form_city', with: city
        select state, from: 'idv_form_state'
        fill_in 'idv_form_zipcode', with: zipcode
        click_idv_continue
        complete_verify_step
        fill_out_phone_form_ok(phone_number)
        verify_phone_otp
        complete_enter_password_step(user)

        expect(page).to have_current_path(idv_personal_key_path)

        profile = user.profiles.last

        expect(profile.active).to be(true)
        expect(profile.decrypt_pii(user.password)).to have_attributes(
          first_name: 'DAVID',
          middle_name: 'PASSPORT',
          last_name: 'SAMPLE',
          dob: '1986-07-01',
          ssn: Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
          phone: phone_number,
          address1:,
          address2: '',
          city:,
          state: state_abbr,
          zipcode:,
          same_address_as_id: nil,
          identity_doc_address1: nil,
          identity_doc_address2: nil,
          identity_doc_city: nil,
          identity_doc_zipcode: nil,
          identity_doc_address_state: nil,
          state_id_jurisdiction: nil,
          issuing_country_code: 'USA',
        )
      end
    end
  end

  describe 'when doc auth vendor is "socure"' do
    let(:doc_auth_vendor) { 'socure' }
    let(:socure_docv_webhook_secret_key) { 'socure_docv_webhook_secret_key' }
    let(:fake_socure_docv_document_request_endpoint) { 'https://fake-socure.test/document-request' }

    before do
      allow(IdentityConfig.store).to receive(:socure_docv_enabled).and_return(true)
      allow(IdentityConfig.store).to receive(:socure_docv_webhook_secret_key)
        .and_return(socure_docv_webhook_secret_key)
      allow(IdentityConfig.store).to receive(:socure_docv_document_request_endpoint)
        .and_return(fake_socure_docv_document_request_endpoint)
      allow(IdentityConfig.store).to receive(:ruby_workers_idv_enabled).and_return(false)
      @docv_transaction_token = stub_docv_document_request(user:)
      stub_request(:post, /.*\/api\/3.0\/EmailAuthScore/)
        .and_return(status: 200, body: doc_auth_response)
    end

    describe 'IDV State ID flow' do
      let(:doc_auth_response) { SocureDocvFixtures.pass_json }

      scenario 'When the user completes all IDV steps' do
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user(user)
        visit idv_welcome_path
        complete_welcome_step
        complete_agreement_step
        complete_hybrid_handoff_step
        complete_choose_id_type_step
        visit idv_socure_document_capture_path
        expect(page).to have_current_path(idv_socure_document_capture_path)
        socure_docv_upload_documents(docv_transaction_token: @docv_transaction_token)
        visit idv_socure_document_capture_update_path
        complete_ssn_step
        complete_verify_step
        fill_out_phone_form_ok(phone_number)
        verify_phone_otp
        complete_enter_password_step(user)

        expect(page).to have_current_path(idv_personal_key_path)

        profile = user.profiles.last

        expect(profile.active).to be(true)
        expect(profile.decrypt_pii(user.password)).to have_attributes(
          first_name: 'Dwayne',
          middle_name: nil,
          last_name: 'Denver',
          dob: '2002-01-01',
          ssn: Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
          phone: phone_number,
          address1: '123 Example Street',
          address2: 'Baltimore MD 21201',
          city: 'Baltimore',
          state: 'MD',
          zipcode: '21201',
          same_address_as_id: nil,
          identity_doc_address1: nil,
          identity_doc_address2: nil,
          identity_doc_city: nil,
          identity_doc_zipcode: nil,
          identity_doc_address_state: nil,
          state_id_jurisdiction: 'MD',
          issuing_country_code: 'USA',
        )
      end
    end

    describe 'IDV Passport flow' do
      let(:address1) { '123 Main St' }
      let(:city) { 'Anywhere' }
      let(:state_abbr) { 'VA' }
      let(:state) { 'Virginia' }
      let(:zipcode) { '66044' }
      let(:doc_auth_response) { SocureDocvFixtures.pass_json(document_type: :passport) }

      scenario 'When the user completes all IDV steps' do
        visit_idp_from_oidc_sp_with_ial2
        sign_in_and_2fa_user(user)
        visit idv_welcome_path
        complete_welcome_step
        complete_agreement_step
        complete_hybrid_handoff_step
        complete_choose_id_type_step(choose_id_type: 'passport')
        visit idv_socure_document_capture_path
        expect(page).to have_current_path(idv_socure_document_capture_path)
        socure_docv_upload_documents(docv_transaction_token: @docv_transaction_token)
        visit idv_socure_document_capture_update_path
        complete_ssn_step
        fill_in 'idv_form_address1', with: address1
        fill_in 'idv_form_city', with: city
        select state, from: 'idv_form_state'
        fill_in 'idv_form_zipcode', with: zipcode
        click_idv_continue
        complete_verify_step
        fill_out_phone_form_ok(phone_number)
        verify_phone_otp
        complete_enter_password_step(user)

        expect(page).to have_current_path(idv_personal_key_path)

        profile = user.profiles.last

        expect(profile.active).to be(true)
        expect(profile.decrypt_pii(user.password)).to have_attributes(
          first_name: 'DWAYNE',
          middle_name: nil,
          last_name: 'DENVER',
          dob: '1965-02-05',
          ssn: Idp::Constants::MOCK_IDV_APPLICANT_WITH_SSN[:ssn],
          phone: phone_number,
          address1:,
          address2: '',
          city:,
          state: state_abbr,
          zipcode:,
          same_address_as_id: nil,
          identity_doc_address1: nil,
          identity_doc_address2: nil,
          identity_doc_city: nil,
          identity_doc_zipcode: nil,
          identity_doc_address_state: nil,
          state_id_jurisdiction: nil,
          issuing_country_code: 'USA',
        )
      end
    end
  end
end
