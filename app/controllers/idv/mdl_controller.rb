# frozen_string_literal: true

module Idv
  class MdlController < ApplicationController
    include Idv::AvailabilityConcern
    include IdvStepConcern

    before_action :confirm_step_allowed
    before_action :confirm_mdl_enabled

    def show
      analytics.idv_mdl_visited
    end

    # POST /verify/mdl/request
    def request_credentials
      render json: {
        signedRequest: mock_signed_request,
        nonce: SecureRandom.hex(16),
      }
    end

    # POST /verify/mdl/verify
    def verify
      pii = mock_pii_from_mdl
      idv_session.pii_from_doc = Pii::StateId.new(**pii)
      idv_session.had_barcode_read_failure = false
      idv_session.had_barcode_attention_error = false
      idv_session.selfie_check_performed = false

      analytics.idv_mdl_verified(success: true)

      render json: {
        success: true,
        redirect: idv_ssn_url,
      }
    rescue StandardError => e
      analytics.idv_mdl_verified(success: false, error: e.message)
      render json: {
        success: false,
        error: 'Verification failed',
      }, status: :unprocessable_entity
    end

    def self.step_info
      Idv::StepInfo.new(
        key: :mdl,
        controller: self,
        next_steps: [:ssn],
        preconditions: ->(idv_session:, user:) do
          IdentityConfig.store.mdl_verification_enabled &&
            idv_session.idv_consent_given?
        end,
        undo_step: ->(idv_session:, user:) do
          idv_session.pii_from_doc = nil
        end,
      )
    end

    private

    def confirm_mdl_enabled
      return if IdentityConfig.store.mdl_verification_enabled

      redirect_to idv_how_to_verify_url
    end

    def mock_signed_request
      Base64.strict_encode64({
        docType: 'org.iso.18013.5.1.mDL',
        nameSpaces: {
          'org.iso.18013.5.1' => {
            given_name: true,
            family_name: true,
            birth_date: true,
            resident_address: true,
            document_number: true,
          },
        },
      }.to_json)
    end

    def mock_pii_from_mdl
      {
        first_name: 'APPLE',
        last_name: 'WALLET',
        middle_name: nil,
        name_suffix: nil,
        dob: '1985-01-15',
        address1: '123 MAIN STREET',
        address2: nil,
        city: 'SACRAMENTO',
        state: 'CA',
        zipcode: '95814',
        state_id_number: 'D1234567',
        state_id_jurisdiction: 'CA',
        state_id_expiration: '2029-12-31',
        state_id_issued: '2024-01-15',
        issuing_country_code: 'US',
        sex: 'male',
        height: 72,
        weight: 180,
        eye_color: 'brown',
        document_type_received: 'drivers_license',
      }
    end
  end
end
