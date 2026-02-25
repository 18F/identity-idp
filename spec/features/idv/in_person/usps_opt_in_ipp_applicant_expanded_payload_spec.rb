require 'rails_helper'
require 'axe-rspec'

RSpec.describe 'In Person Proofing: opt in ipp applicant expanded payload', js: true do
  include IdvStepHelper
  include SpAuthHelper
  include InPersonHelper
  include UspsIppHelper

  let(:ipp_service_provider) { create(:service_provider, :active, :in_person_proofing_enabled) }
  let(:user) { user_with_2fa }
  let(:usps_expected_document_type) do
    UspsInPersonProofing::USPS_DOCUMENT_TYPE_MAPPINGS[InPersonEnrollment::DOCUMENT_TYPE_STATE_ID]
  end

  before do
    allow(IdentityConfig.store).to receive(:usps_mock_fallback).and_return(false)
    allow(IdentityConfig.store).to receive(:in_person_proofing_enabled).and_return(true)
    allow(IdentityConfig.store).to receive(:in_person_completion_survey_delivery_enabled)
      .and_return(true)
    stub_request_token
    stub_request_facilities
    stub_request_enroll
  end

  context 'When the usps_opt_in_ipp_applicant_with_document_data is true' do
    before do
      allow(IdentityConfig.store).to receive(:usps_opt_in_ipp_applicant_with_document_data)
        .and_return(true)
    end

    it 'Then the user can reach the IPP barcode page', allow_browser_log: true do
      user = user_with_2fa

      visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)

      complete_prepare_step(user)
      complete_location_step
      complete_state_id_controller(user)
      complete_ssn_step(user)
      complete_verify_step(user)
      fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
      click_idv_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default
      complete_enter_password_step(user)
      acknowledge_and_confirm_personal_key
      expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
      expect(
        a_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant}).with do |req|
          expect(JSON.parse(req.body)).to eq(
            {
              'sponsorID' => IdentityConfig.store.usps_ipp_sponsor_id.to_i,
              'uniqueID' => InPersonEnrollment.first.unique_id,
              'firstName' => InPersonHelper::GOOD_FIRST_NAME,
              'lastName' => InPersonHelper::GOOD_LAST_NAME,
              'streetAddress' => InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1,
              'city' => InPersonHelper::GOOD_IDENTITY_DOC_CITY,
              'state' => InPersonHelper::GOOD_STATE_ABBR,
              'zipCode' => InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE,
              'emailAddress' =>
                IdentityConfig.store.usps_ipp_enrollment_status_update_email_address,
              'documentType' => usps_expected_document_type,
              'documentNumber' => InPersonHelper::GOOD_STATE_ID_NUMBER,
              'documentExpirationDate' =>
                Time.zone.parse(InPersonHelper::GOOD_STATE_ID_EXPIRATION).to_i,
              'IPPAssuranceLevel' => '1.5',
            },
          )
        end,
      ).to have_been_made
    end
  end

  context 'When the usps_opt_in_ipp_applicant_with_document_data is false' do
    before do
      allow(IdentityConfig.store).to receive(
        :usps_opt_in_ipp_applicant_with_document_data,
      ).and_return(false)
    end

    it 'Then the user can reach the IPP barcode page', allow_browser_log: true do
      user = user_with_2fa

      visit_idp_from_sp_with_ial2(:oidc, **{ client_id: ipp_service_provider.issuer })
      sign_in_and_2fa_user(user)
      begin_in_person_proofing(user)

      complete_prepare_step(user)
      complete_location_step
      complete_state_id_controller(user)
      complete_ssn_step(user)
      complete_verify_step(user)
      fill_out_phone_form_ok(MfaContext.new(user).phone_configurations.first.phone)
      click_idv_send_security_code
      fill_in_code_with_last_phone_otp
      click_submit_default
      complete_enter_password_step(user)
      acknowledge_and_confirm_personal_key
      expect(page).to have_current_path(idv_in_person_ready_to_verify_path)
      expect(
        a_request(:post, %r{/ivs-ippaas-api/IPPRest/resources/rest/optInIPPApplicant}).with do |req|
          expect(JSON.parse(req.body)).to eq(
            {
              'sponsorID' => IdentityConfig.store.usps_ipp_sponsor_id.to_i,
              'uniqueID' => InPersonEnrollment.first.unique_id,
              'firstName' => InPersonHelper::GOOD_FIRST_NAME,
              'lastName' => InPersonHelper::GOOD_LAST_NAME,
              'streetAddress' => InPersonHelper::GOOD_IDENTITY_DOC_ADDRESS1,
              'city' => InPersonHelper::GOOD_IDENTITY_DOC_CITY,
              'state' => InPersonHelper::GOOD_STATE_ABBR,
              'zipCode' => InPersonHelper::GOOD_IDENTITY_DOC_ZIPCODE,
              'emailAddress' =>
                IdentityConfig.store.usps_ipp_enrollment_status_update_email_address,
              'IPPAssuranceLevel' => '1.5',
            },
          )
        end,
      ).to have_been_made
    end
  end
end
