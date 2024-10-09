# frozen_string_literal: true

module AccountCreation
  module DeviceProfiling
    class Proofer
      attr_reader :request_ip,
                  :threatmetrix_session_id,
                  :user_email,
                  :current_sp,
                  :device_profile_result
      
      VALID_REVIEW_STATUSES = %w[pass review reject].freeze

      attr_reader :config

      def initialize(attrs)
        @config = Config.new(attrs)
      end

      def proof(
        request_ip:,
        threatmetrix_session_id:,
        user_email:,
        current_sp:
      )
        @request_ip = request_ip
        @threatmetrix_session_id = threatmetrix_session_id
        @user_email = user_email
        @current_sp = current_sp

        response = VerificationRequest.new(config: config, applicant: applicant).send_request
        build_result_from_response(response)
      rescue => exception
        NewRelic::Agent.notice_error(exception)
        Proofing::DdpResult.new(success: false, exception: exception)
      end

      private

      def build_result_from_response(verification_response)
        result = Proofing::DdpResult.new
        body = verification_response.response_body

        result.response_body = body
        result.transaction_id = body['request_id']
        request_result = body['request_result']
        review_status = body['review_status']

        validate_review_status!(review_status)

        result.review_status = review_status
        result.add_error(:request_result, request_result) unless request_result == 'success'
        result.add_error(:review_status, review_status) unless review_status == 'pass'
        result.account_lex_id = body['account_lex_id']
        result.session_id = body['session_id']

        result.success = !result.errors?
        result.client = 'lexisnexis'

        result
      end
      
      def device_profile
        return threatmetrix_disabled_result unless FeatureManagement.account_creation_device_profiling_collecting_enabled?
        return threatmetrix_id_missing_result if threatmetrix_session_id.blank?
        ddp_params = {}
        ddp_params[:threatmetrix_session_id] = threatmetrix_session_id
        ddp_params[:email] = user_email
        ddp_params[:request_ip] = request_ip

        lexisnexis_ddp_proofer.proof(ddp_params)
      end

      def threatmetrix_disabled_result
        Proofing::DdpResult.new(
          success: true,
          client: 'tmx_disabled',
          review_status: 'pass',
        )
      end

      def threatmetrix_id_missing_result
        Proofing::DdpResult.new(
          success: false,
          client: 'tmx_session_id_missing',
          review_status: 'reject',
        )
      end

      def lexisnexis_ddp_proofer
        @lexisnexis_ddp_proofer ||=
          if IdentityConfig.store.lexisnexis_threatmetrix_mock_enabled
            Proofing::Mock::DdpMockClient.new
          else
            Proofing::LexisNexis::Ddp::Proofer.new(
              api_key: IdentityConfig.store.lexisnexis_threatmetrix_api_key,
              org_id: IdentityConfig.store.lexisnexis_threatmetrix_org_id,
              base_url: IdentityConfig.store.lexisnexis_threatmetrix_base_url,
            )
          end
      end
    end
  end
end
