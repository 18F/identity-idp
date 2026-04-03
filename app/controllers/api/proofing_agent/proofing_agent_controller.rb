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
        response_body = {
          email_account_found: user.present?,
          ssn_profile_found: ssn_active_profiles.any?,
          profiles: active_profiles,
        }

        analytics.idv_proofing_agent_account_check_requested(
          **analytics_arguments, response_body:,
        )

        render json: response_body
      end

      def proof_user
        return render_user_not_found unless user.present?
        return render_already_proofed if user_has_ial2_profile?

        pii_validation = Idv::AgentPiiForm.new(pii: proof_params).submit
        render_bad_request(errors: pii_validation.errors) and return if !pii_validation.success?

        user_id = user&.id

        document_capture_session = DocumentCaptureSession.create!(
          user_id:,
          issuer: request_token.issuer,
          doc_auth_vendor: 'proofing_agent',
          requested_at: Time.zone.now,
        )

        transaction_id = document_capture_session.uuid

        response_body = {
          status: 'pending',
          transaction_id:,
        }

        analytics.idv_proofing_agent_request_received(
          response_body:,
          user_id:,
          agent_id:,
          location_id:,
          correlation_id:,
          transaction_id:,
        )

        render json: response_body, status: :accepted
      rescue ActionController::ParameterMissing => e
        render_bad_request(errors: { error: "Missing parameter #{e.param}" }) and return
      end

      private

      def render_user_not_found
        render json: { status: 'failed', reason: 'email_not_found' }, status: :unprocessable_content
      end

      def render_already_proofed
        render json: { status: 'failed', reason: 'already_proofed_enhanced' }, status: :ok
      end

      def validate_required_headers
        if location_id.blank? || agent_id.blank? || correlation_id.blank?
          track_failure(failure_type: :validation)

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

      def correlation_id
        @correlation_id ||= request.headers['X-Correlation-ID']
      end

      def request_token
        @request_token ||= ::ProofingAgent::RequestTokenValidator.new(request.authorization)
      end

      def email
        @email ||= action_name == 'proof_user' ? proof_params[:email] : search_user_params[:email]
      end

      def ssn
        @ssn ||= action_name == 'proof_user' ? proof_params[:ssn] : search_user_params[:ssn]
      end

      def user
        @user ||= User.find_with_email(email)
      end

      def ssn_active_profiles
        @ssn_active_profiles ||= Idv::DuplicateSsnFinder.new(user:, ssn:)
          .ssn_profiles.select(&:active?)
      end

      def user_active_profile
        @user_active_profile ||= user&.active_profile
      end

      def active_profiles
        @active_profiles ||= begin
          profiles = ssn_active_profiles | [user_active_profile].compact
          profiles.map do |profile|
            {
              email_match: profile.user_id == user&.id,
              ssn_match: ssn_active_profiles.any? { |ssn_profile| ssn_profile.id == profile.id },
              idv_level: Profile::PROOFING_AGENT_IDV_LEVELS[profile.idv_level],
            }
          end
        end
      end

      def track_failure(failure_type:)
        analytics.idv_proofing_agent_request_failed(
          **analytics_arguments,
          success: false,
          failure_type:,
        )
      end

      def user_account_exists?
        user.present? || ssn_active_profiles.any?
      end

      def user_has_ial2_profile?
        enhanced_levels = Profile::PROOFING_AGENT_IDV_LEVELS.select { |_, v| v == 'enhanced' }.keys
        ssn_active_profiles.exists?(idv_level: enhanced_levels)
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

      def search_user_params
        @search_user_params = params.permit(:email, :ssn)
      end

      def add_custom_headers_to_response
        response.set_header('X-Correlation-ID', correlation_id) if correlation_id.present?
      end

      def issuer
        request_token&.issuer
      end

      def analytics_user
        user || AnonymousUser.new
      end

      def analytics_arguments
        {
          proofing_agent: {
            agent_id:,
            location_id:,
            correlation_id:,
          },
          issuer:,
        }
      end
    end
  end
end
