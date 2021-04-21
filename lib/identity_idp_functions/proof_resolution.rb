require 'bundler/setup' if !defined?(Bundler)
require 'json'
require 'retries'
require 'proofer'
require 'aamva'
require 'lexisnexis'
require '/opt/ruby/lib/function_helper' if !defined?(IdentityIdpFunctions::FunctionHelper)

module IdentityIdpFunctions
  class ProofResolution
    include IdentityIdpFunctions::FaradayHelper
    include IdentityIdpFunctions::LoggingHelper

    def self.handle(event:, context:, &callback_block) # rubocop:disable Lint/UnusedMethodArgument
      params = JSON.parse(event.to_json, symbolize_names: true)
      new(**params).proof(&callback_block)
    end

    attr_reader :applicant_pii,
                :callback_url,
                :trace_id,
                :aamva_config,
                :lexisnexis_config,
                :timer

    # @param [Hash] aamva_config should only be included when run in-process, this config includes
    # secrets that should should not be sent in the lambda payload
    # @param [Hash] lexisnexis_config should only be included when run in-process, this config
    # includes secrets that should should not be sent in the lambda payload
    def initialize(
      applicant_pii:,
      callback_url:,
      should_proof_state_id:,
      dob_year_only: false,
      trace_id: nil,
      aamva_config: {},
      lexisnexis_config: {}
    )
      @applicant_pii = applicant_pii
      @callback_url = callback_url
      @should_proof_state_id = should_proof_state_id
      @dob_year_only = dob_year_only
      @trace_id = trace_id
      @aamva_config = aamva_config
      @lexisnexis_config = lexisnexis_config
      @timer = IdentityIdpFunctions::Timer.new
    end

    def should_proof_state_id?
      @should_proof_state_id
    end

    def dob_year_only?
      @dob_year_only
    end

    CallbackLogData = Struct.new(
      :result,
      :resolution_success,
      :state_id_success,
      keyword_init: true,
    )

    # rubocop:disable Metrics/PerceivedComplexity
    def proof
      if !block_given?
        if api_auth_token.to_s.empty?
          raise Errors::MisconfiguredLambdaError, 'IDP_API_AUTH_TOKEN is not configured'
        end

        if !aamva_config.empty?
          raise Errors::MisconfiguredLambdaError,
                'aamva config should not be present in lambda payload'
        end

        if !lexisnexis_config.empty?
          raise Errors::MisconfiguredLambdaError,
                'lexisnexis config should not be present in lambda payload'
        end
      end

      callback_log_data = if dob_year_only? && should_proof_state_id?
                            proof_aamva_then_lexisnexis_dob_only
                          else
                            proof_lexisnexis_then_aamva
                          end

      callback_body = {
        resolution_result: callback_log_data.result,
      }

      if block_given?
        yield callback_body
      else
        post_callback(callback_body: callback_body)
      end
    ensure
      log_event(
        name: 'ProofResolution',
        trace_id: trace_id,
        resolution_success: callback_log_data&.resolution_success,
        state_id_success: callback_log_data&.state_id_success,
        timing: timer.results,
      )
    end
    # rubocop:enable Metrics/PerceivedComplexity

    # @return [CallbackLogData]
    def proof_lexisnexis_then_aamva
      proofer_result = timer.time('resolution') do
        with_retries(**faraday_retry_options) do
          lexisnexis_proofer.proof(applicant_pii)
        end
      end

      result = proofer_result.to_h
      resolution_success = proofer_result.success?

      result[:context] = {
        stages: [
          {
            resolution: LexisNexis::InstantVerify::Proofer.vendor_name,
            transaction_id: proofer_result.transaction_id,
          },
        ],
      }
      result[:transaction_id] = proofer_result.transaction_id

      result[:timed_out] = proofer_result.timed_out?
      result[:exception] = proofer_result.exception.inspect if proofer_result.exception

      state_id_success = nil
      if should_proof_state_id? && result[:success]
        timer.time('state_id') do
          proof_state_id(result)
        end
        state_id_success = result[:success]
      end

      CallbackLogData.new(
        result: result,
        resolution_success: resolution_success,
        state_id_success: state_id_success,
      )
    end

    # @return [CallbackLogData]
    def proof_aamva_then_lexisnexis_dob_only
      proofer_result = timer.time('state_id') do
        with_retries(**faraday_retry_options) do
          aamva_proofer.proof(applicant_pii)
        end
      end

      result = proofer_result.to_h
      state_id_success = proofer_result.success?
      resolution_success = nil

      result[:context] = {
        stages: [
          {
            state_id: Aamva::Proofer.vendor_name,
            transaction_id: proofer_result.transaction_id,
          },
        ],
      }

      if state_id_success
        lexisnexis_result = timer.time('resolution') do
          with_retries(**faraday_retry_options) do
            lexisnexis_proofer.proof(applicant_pii.merge(dob_year_only: dob_year_only?))
          end
        end

        resolution_success = lexisnexis_result.success?

        result.merge!(lexisnexis_result.to_h) do |key, orig, current|
          key == :messages ? orig + current : current
        end

        result[:context][:stages].push(
          resolution: LexisNexis::InstantVerify::Proofer.vendor_name,
          transaction_id: lexisnexis_result.transaction_id,
        )
        result[:transaction_id] = lexisnexis_result.transaction_id
        result[:timed_out] = lexisnexis_result.timed_out?
        result[:exception] = lexisnexis_result.exception.inspect if lexisnexis_result.exception
      end

      CallbackLogData.new(
        result: result,
        resolution_success: resolution_success,
        state_id_success: state_id_success,
      )
    end

    def proof_state_id(result)
      proofer_result = with_retries(**faraday_retry_options) do
        aamva_proofer.proof(applicant_pii)
      end

      result[:context][:stages].push(
        state_id: Aamva::Proofer.vendor_name,
        transaction_id: proofer_result.transaction_id,
      )

      result.merge!(proofer_result.to_h) do |key, orig, current|
        key == :messages ? orig + current : current
      end

      result[:timed_out] = proofer_result.timed_out?
      result[:exception] = proofer_result.exception.inspect if proofer_result.exception

      result
    end

    def post_callback(callback_body:)
      with_retries(**faraday_retry_options) do
        build_faraday.post(
          callback_url,
          callback_body.to_json,
          'X-API-AUTH-TOKEN' => api_auth_token,
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
        )
      end
    end

    def lexisnexis_proofer
      @lexisnexis_proofer ||= LexisNexis::InstantVerify::Proofer.new(
        account_id: lexisnexis_config[:account_id] || ssm_helper.load('lexisnexis_account_id'),
        request_mode: lexisnexis_config[:request_mode] ||
          ssm_helper.load('lexisnexis_request_mode'),
        username: lexisnexis_config[:username] || ssm_helper.load('lexisnexis_username'),
        password: lexisnexis_config[:password] || ssm_helper.load('lexisnexis_password'),
        base_url: lexisnexis_config[:base_url] || ssm_helper.load('lexisnexis_base_url'),
        instant_verify_workflow: lexisnexis_config[:instant_verify_workflow] ||
          ssm_helper.load('lexisnexis_instant_verify_workflow'),
        request_timeout: lexisnexis_config[:request_timeout],
      )
    end

    def aamva_proofer
      @aamva_proofer ||= Aamva::Proofer.new(
        auth_request_timeout: aamva_config[:auth_request_timeout],
        auth_url: aamva_config[:auth_url],
        cert_enabled: aamva_config[:cert_enabled],
        private_key: aamva_config[:private_key] || ssm_helper.load('aamva_private_key'),
        public_key: aamva_config[:public_key] || ssm_helper.load('aamva_public_key'),
        verification_request_timeout: aamva_config[:verification_request_timeout],
        verification_url: aamva_config[:verification_url],
      )
    end

    def api_auth_token
      @api_auth_token ||= ENV.fetch('IDP_API_AUTH_TOKEN') do
        ssm_helper.load('resolution_proof_result_token')
      end
    end

    def ssm_helper
      @ssm_helper ||= SsmHelper.new
    end
  end
end
