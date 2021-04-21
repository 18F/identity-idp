require 'json'
require 'retries'
require 'proofer'
require_relative 'resolution_mock_client'
require_relative 'state_id_mock_client'

module IdentityIdpFunctions
  class ProofResolutionMock
    include IdentityIdpFunctions::FaradayHelper

    attr_reader :applicant_pii, :trace_id, :logger, :timer

    def initialize(
      applicant_pii:,
      should_proof_state_id:,
      logger:,
      dob_year_only: false,
      trace_id: nil
    )
      @applicant_pii = applicant_pii
      @should_proof_state_id = should_proof_state_id
      @dob_year_only = dob_year_only
      @logger = logger
      @trace_id = trace_id
      @timer = IdentityIdpFunctions::Timer.new
    end

    def should_proof_state_id?
      @should_proof_state_id
    end

    def dob_year_only?
      @dob_year_only
    end

    def proof
      proofer_result = timer.time('resolution') do
        with_retries(**faraday_retry_options) do
          resolution_mock_proofer.proof(applicant_pii)
        end
      end

      result = proofer_result.to_h
      resolution_success = proofer_result.success?

      result[:context] = {
        stages: [
          {
            resolution: IdentityIdpFunctions::ResolutionMockClient.vendor_name,
            transaction_id: proofer_result.transaction_id,
          },
        ],
      }

      result[:timed_out] = proofer_result.timed_out?
      result[:exception] = proofer_result.exception.inspect if proofer_result.exception
      result[:transaction_id] = proofer_result.transaction_id

      state_id_success = nil
      if should_proof_state_id? && result[:success]
        timer.time('state_id') do
          proof_state_id(result)
        end
        state_id_success = result[:success]
      end

      {
        resolution_result: result,
      }
    ensure
      logger.info(
        name: 'ProofResolutionMock',
        trace_id: trace_id,
        resolution_success: resolution_success,
        state_id_success: state_id_success,
        timing: timer.results,
      )
    end

    def proof_state_id(result)
      proofer_result = with_retries(**faraday_retry_options) do
        state_id_mock_proofer.proof(applicant_pii)
      end

      result[:context][:stages].push(
        state_id: IdentityIdpFunctions::StateIdMockClient.vendor_name,
        transaction_id: proofer_result.transaction_id,
      )

      result.merge!(proofer_result.to_h) do |key, orig, current|
        key == :messages ? orig + current : current
      end

      result[:timed_out] = proofer_result.timed_out?
      result[:exception] = proofer_result.exception.inspect if proofer_result.exception

      result
    end

    def resolution_mock_proofer
      @resolution_mock_proofer ||= IdentityIdpFunctions::ResolutionMockClient.new
    end

    def state_id_mock_proofer
      @state_id_mock_proofer ||= IdentityIdpFunctions::StateIdMockClient.new
    end
  end
end
