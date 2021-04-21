require 'identity_idp_functions/faraday_helper'
require 'identity_idp_functions/timer'

class AddressProofingJob < ApplicationJob
  include IdentityIdpFunctions::FaradayHelper

  queue_as :default

  def perform(result_id:, encrypted_arguments:, trace_id:)
    timer = IdentityIdpFunctions::Timer.new

    decrypted_args = JSON.parse(
      Encryption::Encryptors::SessionEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    applicant_pii = decrypted_args[:applicant_pii]

    proofer_result = timer.time('address') do
      with_retries(**faraday_retry_options) do
        address_proofer.proof(applicant_pii)
      end
    end

    result = proofer_result.to_h
    result[:context] = { stages: [address: address_proofer.class.vendor_name] }
    result[:transaction_id] = proofer_result.transaction_id

    result[:timed_out] = proofer_result.timed_out?
    result[:exception] = proofer_result.exception.inspect if proofer_result.exception

    document_capture_session = DocumentCaptureSession.new(result_id: result_id)
    document_capture_session.store_proofing_result(result)
  ensure
    logger.info(
      name: 'ProofAddress',
      trace_id: trace_id,
      success: proofer_result&.success?,
      timing: timer.results,
    )
  end

  private

  def address_proofer
    @address_proofer ||= if IdentityConfig.store.proofer_mock_fallback
      require 'proofing/address_mock_client'
      Proofing::AddressMockClient.new
    else
      LexisNexis::PhoneFinder::Proofer.new(
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
