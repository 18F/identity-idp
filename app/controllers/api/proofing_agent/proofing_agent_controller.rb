# frozen_string_literal: true

module Api
  module ProofingAgent
    class ProofingAgentController < ApplicationController
      include RenderConditionConcern
      check_or_render_not_found -> { FeatureManagement.idv_proofing_agent_enabled? }

      prepend_before_action :skip_session_load
      prepend_before_action :skip_session_expiration

      skip_before_action :verify_authenticity_token
      before_action :authenticate_client
      before_action :validate_required_headers
      before_action :validate_search_user_payload, only: :search_user
      after_action :add_custom_headers_to_response

      def search_user
        email_account_found = user_account_for_email.present?
        ssn_profile_found = profiles_with_matching_ssn.any?
        response_body = {
          request_id:,
          email_account_found:,
          ssn_profile_found:,
          profiles: build_profiles_results_array,
        }
        track_account_check(
          user_id: user_account_for_email&.id,
          response_body:,
          agent_id:,
          location_id:,
          request_id:,
        )
        render json: response_body
      end

      def proof_user
        pii_validation = Idv::AgentPiiForm.new(pii: proof_params).submit
        render_bad_request(errors: pii_validation.errors) and return if !pii_validation.success?
        render json: {}
      rescue ActionController::ParameterMissing => e
        render_bad_request(errors: { error: "Missing parameter #{e.param}" }) and return
      end

      private

      def validate_required_headers
        if location_id.blank? || agent_id.blank? || request_id.blank?
          track_failure(failure_type: :validation, agent_id:, location_id:, request_id:)

          required_headers = 'X-Proofing-Location-ID, X-Proofing-Agent-ID, X-Correlation-ID'
          render json: {
            error: "Missing required headers: #{required_headers}",
          }, status: :bad_request
        end
      end

      def validate_search_user_payload
        if email.blank? || ssn.blank?
          render json: {
            error: 'Missing required payload: email, ssn',
          }, status: :bad_request
        end
      end

      def authenticate_client
        if request_token.invalid?
          track_failure(failure_type: :authorization)
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end

      def agent_id
        @agent_id ||= request.headers['X-Proofing-Agent-ID']
      end

      def location_id
        @location_id ||= request.headers['X-Proofing-Location-ID']
      end

      def request_id
        @request_id ||= request.headers['X-Correlation-ID']
      end

      def request_token
        @request_token ||= ::ProofingAgent::RequestTokenValidator.new(request.authorization)
      end

      def email
        @email ||= search_params[:email]
      end

      def ssn
        @ssn ||= search_params[:ssn]
      end

      def user_account_for_email
        @user_account_for_email ||= EmailAddress.find_with_email(email)&.user
      end

      def ssn_signature_fingerprint
        Pii::Fingerprinter.fingerprint(SsnFormatter.normalize(ssn))
      end

      def profiles_with_matching_ssn
        @profiles_with_matching_ssn ||= Profile.where(
          ssn_signature: ssn_signature_fingerprint,
        )
      end

      def check_if_user_exists
        return true if user_account_for_email.present? || profiles_with_matching_ssn.any?
      end

      def profiles_with_matching_account
        return [] if user_account_for_email.blank?

        Profile.where(user_id: user_account_for_email.id)
      end

      def build_profiles_results_array
        profiles = profiles_with_matching_ssn | profiles_with_matching_account
        @build_profiles_results_array ||= profiles.map do |profile|
          {
            email_match: profile.user == user_account_for_email,
            ssn_match: profile.ssn_signature == ssn_signature_fingerprint,
            idv_level: Profile::PROOFING_AGENT_IDV_LEVELS[profile.idv_level],
          }
        end
      end

      def track_failure(failure_type:, agent_id: nil, location_id: nil, request_id: nil)
        analytics.idv_proofing_agent_request_failed(
          issuer: request_token&.issuer,
          success: false,
          failure_type:,
          agent_id:,
          location_id:,
          request_id:,
        )
      end

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

      def render_bad_request(errors: nil)
        errors = { error: 'There was a problem with your request.' } if errors.nil?
        if errors[:no_document].present?
          errors = { id_type: "Invalid id_type: #{proof_params[:id_type]}" }
        end
        render json: errors, status: :bad_request
      end

      def track_account_check(
        user_id:,
        response_body:,
        agent_id: nil,
        location_id: nil,
        request_id: nil
      )
        analytics.idv_proofing_agent_account_check_requested(
          user_id:,
          response_body:,
          agent_id:,
          location_id:,
          request_id:,
        )
      end

      def search_params
        params.permit(:email, :ssn)
      end

      def add_custom_headers_to_response
        response.set_header('X-Correlation-ID', request_id) if request_id.present?
      end
    end
  end
end
