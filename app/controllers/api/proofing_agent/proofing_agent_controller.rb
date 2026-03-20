# frozen_string_literal: true

module Api
  module ProofingAgent
    class ProofingAgentController < ApplicationController
      include RenderConditionConcern

      prepend_before_action :skip_session_load
      prepend_before_action :skip_session_expiration
      skip_before_action :verify_authenticity_token

      check_or_render_not_found -> { FeatureManagement.idv_proofing_agent_enabled? }

      def search_user
        render json: { request_id: SecureRandom.uuid }
      end

      def proof_user
        pii_validation = Idv::DocPiiForm.new(pii: pii_from_agent).submit
        render_bad_request and return if !pii_validation.success?

        render json: { request_id: SecureRandom.uuid }
      rescue ActionController::ParameterMissing
        render_bad_request and return
      end

      # private

      def proof_params
        return @proof_params if defined?(@proof_params)

        result = {}

        required_keys = %i[suspected_fraud email first_name last_name dob phone ssn id_type]
        required_keys.each do |key|
          result[key] = params.expect(key)
        end

        optional_keys = %i[residential_address state_id passport]
        optional_parameters = {
          residential_address: %i[address1 address2 city state zip_code],
          state_id: %i[document_number jurisdiction expiration_date issue_date
                       address1 address2 city state zip_code],
          passport: %i[expiration_date issue_date mrz issuing_country_code],
        }
        optional_keys.each do |key|
          if params[key].present?
            result[key] =
              params.expect(key => optional_parameters[key]).to_h.with_indifferent_access
          end
        end

        @proof_params = result.to_h.with_indifferent_access
      end

      def pii_from_agent
        return @pii_from_agent if defined?(@pii_from_agent)

        result = proof_params.deep_dup
        result[:document_type_received] = result.delete(:id_type)

        case result[:document_type_received]
        when *Idp::Constants::DocumentTypes::SUPPORTED_STATE_ID_TYPES
          state_id = result.delete(:state_id)
          raise ActionController::ParameterMissing.new(state_id: {}) if state_id.blank?

          result[:address1] = state_id[:address1]
          result[:address2] = state_id[:address2]
          result[:city] = state_id[:city]
          result[:state] = state_id[:state]
          result[:zipcode] = state_id[:zip_code]
          result[:state_id_jurisdiction] = state_id[:jurisdiction]
          result[:state_id_number] = state_id[:document_number]
          result[:state_id_expiration] = state_id[:expiration_date]

        when *Idp::Constants::DocumentTypes::SUPPORTED_PASSPORT_TYPES
          passport = result.delete(:passport)
          address = result.delete(:residential_address)
          raise ActionController::ParameterMissing.new(passport: {}) if passport.blank?
          raise ActionController::ParameterMissing.new(residential_address: {}) if address.blank?

          result[:passport_expiration] = passport[:expiration_date]
          result[:issuing_country_code] = passport[:issuing_country_code]
          result[:mrz] = passport[:mrz]
          result[:address1] = address[:address1]
          result[:address2] = address[:address2]
          result[:city] = address[:city]
          result[:state] = address[:state]
          result[:zipcode] = address[:zip_code]
        end

        @pii_from_agent = result
      end
    end
  end
end
