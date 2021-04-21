require 'bundler/setup' if !defined?(Bundler)
require 'json'
require 'retries'
require 'proofer'
require 'lexisnexis'
require '/opt/ruby/lib/function_helper' if !defined?(IdentityIdpFunctions::FunctionHelper)

module IdentityIdpFunctions
  class ProofAddress
    include IdentityIdpFunctions::FaradayHelper
    include IdentityIdpFunctions::LoggingHelper

    def self.handle(event:, context:, &callback_block) # rubocop:disable Lint/UnusedMethodArgument
      params = JSON.parse(event.to_json, symbolize_names: true)
      new(**params).proof(&callback_block)
    end

    attr_reader :applicant_pii, :callback_url, :trace_id, :lexisnexis_config, :timer

    def initialize(applicant_pii:, callback_url:, trace_id: nil, lexisnexis_config: {})
      @applicant_pii = applicant_pii
      @callback_url = callback_url
      @lexisnexis_config = lexisnexis_config
      @trace_id = trace_id
      @timer = IdentityIdpFunctions::Timer.new
    end

    def proof
      if !block_given?
        if api_auth_token.to_s.empty?
          raise Errors::MisconfiguredLambdaError, 'IDP_API_AUTH_TOKEN is not configured'
        end

        if !lexisnexis_config.empty?
          raise Errors::MisconfiguredLambdaError,
                'lexisnexis config should not be present in lambda payload'
        end
      end

      proofer_result = timer.time('address') do
        with_retries(**faraday_retry_options) do
          lexisnexis_proofer.proof(applicant_pii)
        end
      end

      result = proofer_result.to_h
      result[:context] = { stages: [address: LexisNexis::PhoneFinder::Proofer.vendor_name] }
      result[:transaction_id] = proofer_result.transaction_id

      result[:timed_out] = proofer_result.timed_out?
      result[:exception] = proofer_result.exception.inspect if proofer_result.exception

      callback_body = {
        address_result: result,
      }

      if block_given?
        yield callback_body
      else
        timer.time('callback') do
          post_callback(callback_body: callback_body)
        end
      end
    ensure
      log_event(
        name: 'ProofAddress',
        trace_id: trace_id,
        success: proofer_result&.success?,
        timing: timer.results,
      )
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

    def api_auth_token
      @api_auth_token ||= ENV.fetch('IDP_API_AUTH_TOKEN') do
        ssm_helper.load('address_proof_result_token')
      end
    end

    def lexisnexis_proofer
      @lexisnexis_proofer ||= LexisNexis::PhoneFinder::Proofer.new(
        account_id: lexisnexis_config[:account_id] || ssm_helper.load('lexisnexis_account_id'),
        request_mode: lexisnexis_config[:request_mode] ||
          ssm_helper.load('lexisnexis_request_mode'),
        username: lexisnexis_config[:username] || ssm_helper.load('lexisnexis_username'),
        password: lexisnexis_config[:password] || ssm_helper.load('lexisnexis_password'),
        base_url: lexisnexis_config[:base_url] || ssm_helper.load('lexisnexis_base_url'),
        phone_finder_workflow: lexisnexis_config[:phone_finder_workflow] ||
          ssm_helper.load('lexisnexis_phone_finder_workflow'),
        request_timeout: lexisnexis_config[:request_timeout],
      )
    end

    def ssm_helper
      @ssm_helper ||= SsmHelper.new
    end
  end
end
