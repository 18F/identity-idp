require 'json'
require 'retries'
require 'proofer'
require 'lexisnexis'
require 'identity_idp_functions/faraday_helper'
require 'identity_idp_functions/timer'

module IdentityIdpFunctions
  class ProofAddress
    include IdentityIdpFunctions::FaradayHelper

    attr_reader :applicant_pii, :trace_id, :logger, :timer

    def initialize(applicant_pii:, logger: logger, trace_id: nil)
      @applicant_pii = applicant_pii
      @trace_id = trace_id
      @logger = logger
      @timer = IdentityIdpFunctions::Timer.new
    end

    def proof
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

      {
        address_result: result,
      }
    ensure
      logger.info(
        name: 'ProofAddress',
        trace_id: trace_id,
        success: proofer_result&.success?,
        timing: timer.results,
      )
    end

    def lexisnexis_proofer
      @lexisnexis_proofer ||= LexisNexis::PhoneFinder::Proofer.new(
        phone_finder_workflow: AppConfig.env.lexisnexis_phone_finder_workflow,
        account_id: AppConfig.env.lexisnexis_account_id,
        base_url: AppConfig.env.lexisnexis_base_url,
        username: AppConfig.env.lexisnexis_username,
        password: AppConfig.env.lexisnexis_password,
        request_mode: AppConfig.env.lexisnexis_request_mode,
        request_timeout: IdentityConfig.store.lexisnexis_timeout,
      )
    end
  end
end
