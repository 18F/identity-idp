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
      before_action :validate_transaction_id, only: [:result]
      before_action :mock_system_error
      after_action :add_custom_headers_to_response

      def search_user
        pii_validation = Idv::ProofingAgent::SearchUserForm.new(email:, ssn:).submit
        render_bad_request(errors: pii_validation.errors) and return if !pii_validation.success?

        response_body = {
          email_account_found: user.present?,
          ssn_profile_found: ssn_active_profiles.any?,
          profiles: active_profiles_info,
          email_account_awaiting_binding: !!user&.proofing_agent_user_awaiting_binding?,
          account_email_confirmed: email_confirmed?,
        }

        analytics.idv_proofing_agent_account_check_requested(
          **analytics_arguments, response_body:,
        )

        render json: response_body
      end

      def proof_user
        return render_user_not_found if user.blank?
        return render_user_email_unconfirmed unless email_confirmed?
        return render_already_proofed if already_proofed?
        return render_user_awaiting_binding if user.proofing_agent_user_awaiting_binding?

        if proofing_rate_limiter.limited? || ssn_rate_limiter.limited?
          analytics.rate_limit_reached(limiter_type: :idv_resolution, step_name: 'proof_user')
          analytics.rate_limit_reached(limiter_type: :proof_ssn, step_name: 'proof_user')
          attempts_api_tracker.idv_rate_limited(limiter_type: :idv_resolution)
          ::ProofingAgent::FailureEmailSender.new(user: user, analytics: analytics).call(
            visited_at: Time.zone.now.iso8601,
            reason: 'maximum_attempts_reached',
            proofing_agent_id: agent_id,
            proofing_location_id: location_id,
            correlation_id: correlation_id,
          )
          render json: { status: 'failed', reason: 'maximum_attempts_reached' },
                 status: :too_many_requests
          return
        end

        pii_validation = Idv::ProofingAgent::AgentPiiForm.new(pii: proof_params).submit
        render_bad_request(errors: pii_validation.errors) and return if !pii_validation.success?

        document_capture_session = DocumentCaptureSession.create!(
          user_id: user.id,
          issuer:,
          doc_auth_vendor: Idp::Constants::Vendors::PROOFING_AGENT,
          requested_at: Time.zone.now,
        )

        transaction_id = document_capture_session.uuid

        response_body = {
          status: 'pending',
          transaction_id:,
        }

        analytics.idv_proofing_agent_proof_user_requested(
          **analytics_arguments,
          response_body:,
          transaction_id:,
          remaining_attempts: proofing_rate_limiter.remaining_count,
          final_attempt:,
        )

        track_attempt(success: pii_validation.success?, transaction_id:)

        proofing_rate_limiter&.increment!
        ssn_rate_limiter&.increment!

        response_body = response_body.merge(
          { remaining_attempts: proofing_rate_limiter.remaining_count },
        )

        ::ProofingAgent::ProofUser.new(proof_params).call(
          proofing_agent_id: agent_id,
          proofing_location_id: location_id,
          correlation_id:,
          trace_id: amzn_trace_id,
          transaction_id:,
          final_attempt:,
          submit_attempts: proofing_rate_limiter.attempts,
          remaining_attempts: proofing_rate_limiter.remaining_count,
        )

        render json: response_body, status: :accepted
      rescue ActionController::ParameterMissing => e
        render_bad_request(errors: { e.param => ['cannot be blank'] }) and return
      end

      def result
        proofing_result = Rails.cache.fetch(
          "proofing_agent_result_#{transaction_id}",
          expires_in: IdentityConfig.store.idv_proofing_agent_result_expiration_seconds,
        ) do
          document_capture_session = DocumentCaptureSession.find_by(uuid: transaction_id)
          document_capture_session&.load_agent_proofed_user
        end

        return render_proofing_result_not_found if proofing_result.nil?

        response_body = {
          success: proofing_result.success,
          reason: proofing_result.reason,
          transaction_id: proofing_result.transaction_id,
        }

        analytics.idv_proofing_agent_result_requested(
          **analytics_arguments,
          response_body:,
          transaction_id:,
        )

        render json: response_body
      end

      private

      def render_user_not_found
        response_body = { status: 'failed', reason: 'email_not_found' }

        analytics.idv_proofing_agent_proof_user_requested(
          **analytics_arguments,
          response_body:,
          transaction_id: nil,
        )

        render json: response_body, status: :unprocessable_content
      end

      def render_user_email_unconfirmed
        response_body = { status: 'failed', reason: 'account_email_unconfirmed' }

        analytics.idv_proofing_agent_proof_user_requested(
          **analytics_arguments,
          response_body:,
          transaction_id: nil,
        )

        render json: response_body, status: :unprocessable_content
      end

      def render_already_proofed
        response_body = { status: 'failed', reason: 'already_proofed_enhanced' }

        analytics.idv_proofing_agent_proof_user_requested(
          **analytics_arguments,
          response_body:,
          transaction_id: nil,
        )

        render json: response_body, status: :ok
      end

      def render_user_awaiting_binding
        response_body = {
          status: 'failed',
          reason: 'already_proofed_awaiting_binding',
        }

        analytics.idv_proofing_agent_proof_user_requested(
          **analytics_arguments,
          response_body:,
          transaction_id: nil,
        )

        render json: response_body, status: :ok
      end

      def render_proofing_result_not_found
        response_body = {
          success: false,
          reason: 'result_not_found',
          transaction_id:,
        }

        analytics.idv_proofing_agent_result_requested(
          **analytics_arguments,
          response_body:,
          transaction_id:,
        )

        render json: response_body, status: :not_found
      end

      def validate_required_headers
        missing = []
        missing << 'X-Correlation-ID' if correlation_id.blank?

        return if missing.empty?

        errors = { error: "Missing required headers: #{missing.join(', ')}" }

        render_bad_request(errors:, failure_type: :header_validation)
      end

      def validate_agent_id_and_location_id
        errors = {}
        errors[:proofing_agent_id] = ['cannot be blank'] if agent_id.blank?
        errors[:proofing_location_id] = ['cannot be blank'] if location_id.blank?
        return if errors.empty?
        render_bad_request(errors:, failure_type: :body_validation)
      end

      def validate_transaction_id
        errors = {}
        errors[:transaction_id] = ['cannot be blank'] if transaction_id.blank?
        return if errors.empty?
        render_bad_request(errors:, failure_type: :body_validation)
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

      def transaction_id
        @transaction_id ||= params.permit(:transaction_id)[:transaction_id]
      end

      def user
        @user ||= email_address&.user
      end

      def email_address
        @email_address ||= EmailAddress.find_with_confirmed_or_unconfirmed_email(email)
      end

      def email_confirmed?
        !!email_address&.confirmed_at
      end

      def ssn_active_profiles
        @ssn_active_profiles ||= Idv::DuplicateSsnFinder.new(user:, ssn:)
          .ssn_profiles.select(&:active?)
      end

      def user_active_profile
        @user_active_profile ||= user&.active_profile
      end

      def active_profiles
        @active_profiles ||= ssn_active_profiles | [user_active_profile].compact
      end

      def active_profiles_info
        active_profiles.map do |profile|
          {
            email_match: profile.user_id == user&.id,
            ssn_match: ssn_active_profiles.any? { |ssn_profile| ssn_profile.id == profile.id },
            idv_level: Profile::PROOFING_AGENT_IDV_LEVELS[profile.idv_level],
          }
        end
      end

      def track_failure(failure_type:, errors: nil)
        analytics.idv_proofing_agent_request_failed(
          **analytics_arguments,
          success: false,
          failure_type:,
          errors:,
          pii_like_keypaths: pii_like_keypaths(failure_type),
        )
      end

      def pii_like_keypaths(failure_type)
        return [] unless failure_type == :body_validation

        case action_name
          when 'proof_user'
            Idv::ProofingAgent::AgentPiiForm.pii_like_keypaths(document_type: id_type)
          when 'search_user'
            Idv::ProofingAgent::SearchUserForm.pii_like_keypaths
          else
            []
        end
      end

      def user_has_enhanced_profile?
        active_profiles.any? do |profile|
          profile.enhanced?
        end
      end

      def already_proofed?
        return false if IdentityConfig.store.idv_proofing_agent_proof_user_with_enhanced_profile

        user_has_enhanced_profile?
      end

      def email
        @email ||= params.permit(:email)[:email]
      end

      def ssn
        @ssn ||= params.permit(:ssn)[:ssn]
      end

      def id_type
        @id_type ||= params.permit(:id_type)[:id_type]
      end

      def proof_params
        return @proof_params if defined?(@proof_params)

        result = {}

        required_keys = %i[suspected_fraud email first_name last_name dob phone ssn id_type]
        required_keys.each do |key|
          result[key] = params.permit(key).send(:[], key)
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
              params.permit(key => optional_parameters[key]).send(:[], key).to_h
          end
        end

        @proof_params = result.to_h.with_indifferent_access
      end

      def render_bad_request(errors: nil, failure_type: :body_validation)
        errors = { base: ['There was a problem with your request.'] } if errors.blank?
        track_failure(failure_type:, errors:)
        track_attempt(success: false, failure_reason: errors) if action_name == 'proof_user'

        render json: errors, status: :bad_request
      end

      def mock_system_error
        return if Identity::Hostdata.in_datacenter? && Identity::Hostdata.env == 'prod'

        m = /system_error\+?(\d{3})?@example.com/.match(email)
        return unless m

        render json: {
          success: false,
          reason: 'system_error',
          transaction_id:,
        }, status: system_error_status_code(m[1])
      end

      def system_error_status_code(code)
        status = code&.to_i
        status&.positive? ? status : 503
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
            transaction_id:,
          },
          issuer:,
        }
      end

      def final_attempt
        @final_attempt ||= ActiveModel::Type::Boolean.new.cast(params[:final_attempt]) || false
      end

      def proofing_rate_limiter
        @proofing_rate_limiter ||= RateLimiter.new(user: user, rate_limit_type: :idv_resolution)
      end

      def ssn_rate_limiter
        @ssn_rate_limiter ||= RateLimiter.new(user: user, rate_limit_type: :proof_ssn)
      end

      def track_attempt(success:, transaction_id: nil, failure_reason: nil)
        attempts_api_tracker.idv_proofing_agent_verification_requested(
          success:,
          agent_info: {
            agent_id:,
            location_id:,
            correlation_id:,
          },
          pii: attempts_api_pii,
          transaction_id:,
          failure_reason:,
        )
      end

      def attempts_api_tracker
        AttemptsApi::Tracker.new(
          enabled_for_session: service_provider&.attempts_api_enabled?,
          session_id: nil,
          request:,
          user:,
          sp: service_provider,
          cookie_device_uuid: nil,
          sp_redirect_uri: nil,
        )
      end

      def service_provider
        @service_provider ||= ServiceProvider.find_by(issuer:)
      end

      def attempts_api_pii
        {
          first_name: proof_params[:first_name],
          last_name: proof_params[:last_name],
          date_of_birth: proof_params[:dob],
          phone: proof_params[:phone],
          ssn: SsnFormatter.format(proof_params[:ssn]),
          **attempts_api_residential_address,
          **attempts_api_document_info,
        }
      end

      def attempts_api_residential_address
        address = {}

        if proof_params[:residential_address].present?
          address.merge!(
            {
              address1: proof_params[:residential_address][:address1],
              address2: proof_params[:residential_address][:address2],
              city: proof_params[:residential_address][:city],
              state: proof_params[:residential_address][:state],
              zip: proof_params[:residential_address][:zip_code],
            },
          )
        elsif proof_params[:state_id].present?
          address.merge!(
            {
              address1: proof_params[:state_id][:address1],
              address2: proof_params[:state_id][:address2],
              city: proof_params[:state_id][:city],
              state: proof_params[:state_id][:state],
              zip: proof_params[:state_id][:zip_code],
            },
          )
        end

        address
      end

      def attempts_api_document_info
        info = { document_type: proof_params[:id_type] }

        if proof_params[:state_id].present?
          info.merge!(
            document_state_jurisdiction: proof_params[:state_id][:jurisdiction],
            document_number: proof_params[:state_id][:document_number],
            document_expiration: proof_params[:state_id][:expiration_date],
            document_issued: proof_params[:state_id][:issue_date],
            document_address1: proof_params[:state_id][:address1],
            document_address2: proof_params[:state_id][:address2],
            document_city: proof_params[:state_id][:city],
            document_state: proof_params[:state_id][:state],
            document_zip: proof_params[:state_id][:zip_code],
          )
        elsif proof_params[:passport].present?
          info.merge!(
            document_number: proof_params[:passport][:document_number],
            document_expiration: proof_params[:passport][:expiration_date],
            document_issued: proof_params[:passport][:issue_date],
          )
        end

        info
      end
    end
  end
end
