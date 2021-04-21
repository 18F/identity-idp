require 'json'
require 'retries'
require 'proofer'
require 'aamva'
require 'lexisnexis'
require 'identity_idp_functions/faraday_helper'
require 'identity_idp_functions/timer'

module IdentityIdpFunctions
  class ProofResolution
    include IdentityIdpFunctions::FaradayHelper

    attr_reader :applicant_pii,
                :trace_id,
                :logger,
                :timer

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
      @trace_id = trace_id
      @logger = logger
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

    def proof
      callback_log_data = if dob_year_only? && should_proof_state_id?
                            proof_aamva_then_lexisnexis_dob_only
                          else
                            proof_lexisnexis_then_aamva
                          end

      {
        resolution_result: callback_log_data.result,
      }
    ensure
      logger.info(
        name: 'ProofResolution',
        trace_id: trace_id,
        resolution_success: callback_log_data&.resolution_success,
        state_id_success: callback_log_data&.state_id_success,
        timing: timer.results,
      )
    end

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

    def lexisnexis_proofer
      @lexisnexis_proofer ||= LexisNexis::InstantVerify::Proofer.new(
        instant_verify_workflow: AppConfig.env.lexisnexis_instant_verify_workflow,
        account_id: AppConfig.env.lexisnexis_account_id,
        base_url: AppConfig.env.lexisnexis_base_url,
        username: AppConfig.env.lexisnexis_username,
        password: AppConfig.env.lexisnexis_password,
        request_mode: AppConfig.env.lexisnexis_request_mode,
        request_timeout: IdentityConfig.store.lexisnexis_timeout,
      )
    end

    def aamva_proofer
      @aamva_proofer ||= Aamva::Proofer.new(
        auth_request_timeout: AppConfig.env.aamva_auth_request_timeout,
        auth_url: AppConfig.env.aamva_auth_url,
        cert_enabled: IdentityConfig.store.aamva_cert_enabled,
        private_key: AppConfig.env.aamva_private_key,
        public_key: AppConfig.env.aamva_public_key,
        verification_request_timeout: AppConfig.env.aamva_verification_request_timeout,
        verification_url: IdentityConfig.store.aamva_verification_url,
      )
    end
  end
end
