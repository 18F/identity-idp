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
      before_action :validate_agent_id_and_location_id
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
        return render_user_not_found if user.blank?
        return render_already_proofed if user_has_enhanced_profile?

        pii_validation = Idv::ProofingAgent::AgentPiiForm.new(pii: proof_params).submit
        render_bad_request(errors: pii_validation.errors) and return if !pii_validation.success?

        document_capture_session = DocumentCaptureSession.create!(
          user_id: user.id,
          issuer:,
          doc_auth_vendor: 'proofing_agent',
          requested_at: Time.zone.now,
        )

        transaction_id = document_capture_session.uuid

        response_body = {
          status: 'pending',
          transaction_id:,
        }

        analytics.idv_proofing_agent_request_received(
          **analytics_arguments,
          response_body:,
          transaction_id:,
        )

        render json: response_body, status: :accepted
      rescue ActionController::ParameterMissing => e
        render_bad_request(errors: { e.param => ['cannot be blank'] }) and return
      end

      private

      def render_user_not_found
        response_body = { status: 'failed', reason: 'email_not_found' }

        analytics.idv_proofing_agent_request_received(
          **analytics_arguments,
          response_body:,
          transaction_id: nil,
        )

        render json: response_body, status: :unprocessable_content
      end

      def render_already_proofed
        response_body = { status: 'failed', reason: 'already_proofed_enhanced' }

        analytics.idv_proofing_agent_request_received(
          **analytics_arguments,
          response_body:,
          transaction_id: nil,
        )

        render json: response_body, status: :ok
      end

      def validate_required_headers
        missing = []
        missing << 'X-Correlation-ID' if correlation_id.blank?

        return if missing.empty?

        errors = { error: "Missing required headers: #{missing.join(', ')}" }

        render_bad_request(errors:, failure_type: :header_validation)
      end

      def validate_agent_id_and_location_id
        missing = []
        missing << 'proofing_agent_id' if agent_id.blank?
        missing << 'proofing_location_id' if location_id.blank?

        return if missing.empty?

        errors = { error: "Missing required payload: #{missing.join(', ')}" }
        render_bad_request(errors: errors, failure_type: :body_validation)
      end

      def validate_search_user_payload
        missing = []
        missing << 'email' if email.blank?
        missing << 'ssn' if ssn.blank?

        return if missing.empty?

        error = "Missing required payload: #{missing.join(', ')}"

        analytics.idv_proofing_agent_request_failed(
          **analytics_arguments,
          success: false,
          failure_type: :body_validation,
          errors: { error: },
        )
        render json: {
          error:,
        }, status: :bad_request
      end

      def authenticate_client
        if request_token.invalid?
          track_failure(failure_type: :authorization)
          render json: { error: 'Unauthorized' }, status: :unauthorized
        end
      end

      def agent_id
        @agent_id ||= params.permit(:proofing_agent_id)[:proofing_agent_id]
      end

      def location_id
        @location_id ||= params.permit(:proofing_location_id)[:proofing_location_id]
      end

      def correlation_id
        @correlation_id ||= request.headers['X-Correlation-ID']
      end

      def request_token
        @request_token ||= ::ProofingAgent::RequestTokenValidator.new(request.authorization)
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

      def track_failure(failure_type:, errors: nil)
        pii_like_keypaths = []
        if failure_type == :body_validation
          if action_name == 'proof_user'
            pii_like_keypaths = Idv::ProofingAgent::AgentPiiForm.pii_like_keypaths(document_type: id_type)
          elsif action_name == 'search_user'
            pii_like_keypaths = [:email, :ssn]
          end
        end
        analytics.idv_proofing_agent_request_failed(
          **analytics_arguments,
          success: false,
          failure_type:,
          errors:,
          pii_like_keypaths:,
        )
      end

      def user_has_enhanced_profile?
        [user_active_profile, *ssn_active_profiles].compact.any? do |profile|
          profile.enhanced?
        end
      end

      def email
        @email ||= action_name == 'proof_user' ? params.expect(:email) : search_user_params[:email]
      end

      def ssn
        @ssn ||= action_name == 'proof_user' ? params.expect(:ssn) : search_user_params[:ssn]
      end

      def id_type
        @id_type ||= params.expect(:id_type)
      end

      def search_user_params
        @search_user_params = params.permit(:email, :ssn)
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

      def render_bad_request(errors: nil, failure_type: :body_validation)
        errors = { base: ['There was a problem with your request.'] } if errors.blank?
        track_failure(failure_type:, errors:)

        render json: errors, status: :bad_request
      end

      def add_custom_headers_to_response
        response.set_header('X-Correlation-ID', correlation_id) if correlation_id.present?
      end

      def issuer
        request_token&.sp_issuer
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
