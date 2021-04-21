require 'json'
require 'proofer'
require 'retries'
require_relative 'address_mock_client'
require 'identity_idp_functions/faraday_helper'
require 'identity_idp_functions/timer'

module IdentityIdpFunctions
  class ProofAddressMock
    include IdentityIdpFunctions::FaradayHelper

    attr_reader :applicant_pii, :trace_id, :lexisnexis_config, :timer, :logger

    def initialize(applicant_pii:, logger:, trace_id: nil)
      @applicant_pii = applicant_pii
      @trace_id = trace_id
      @logger = logger
      @timer = IdentityIdpFunctions::Timer.new
    end

    def proof
      proofer_result = timer.time('address') do
        with_retries(**faraday_retry_options) do
          mock_proofer.proof(applicant_pii)
        end
      end

      result = proofer_result.to_h
      result[:context] = { stages: [
        address: IdentityIdpFunctions::AddressMockClient.vendor_name,
      ] }
      result[:transaction_id] = proofer_result.transaction_id

      result[:timed_out] = proofer_result.timed_out?
      result[:exception] = proofer_result.exception.inspect if proofer_result.exception

      {
        address_result: result,
      }
    ensure
      logger.info(
        name: 'ProofAddressMock',
        trace_id: trace_id,
        success: proofer_result&.success?,
        timing: timer.results,
      )
    end

    def mock_proofer
      IdentityIdpFunctions::AddressMockClient.new
    end
  end
end
