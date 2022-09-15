class AddressProofingJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :default

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  def perform(user_id:, issuer:, result_id:, encrypted_arguments:, trace_id:)
    timer = JobHelpers::Timer.new

    raise_stale_job! if stale_job?(enqueued_at)

    decrypted_args = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    applicant_pii = decrypted_args[:applicant_pii]

    proofer_result = timer.time('address') do
      address_proofer.proof(applicant_pii)
    end

    service_provider = ServiceProvider.find_by(issuer: issuer)
    Db::SpCost::AddSpCost.call(
      service_provider, 2, :lexis_nexis_address, transaction_id: proofer_result.transaction_id
    )
    Db::ProofingCost::AddUserProofingCost.call(user_id, :lexis_nexis_address)

    document_capture_session = DocumentCaptureSession.new(result_id: result_id)
    document_capture_session.store_proofing_result(proofer_result.to_h)
  ensure
    logger.info(
      {
        name: 'ProofAddress',
        trace_id: trace_id,
        success: proofer_result&.success?,
        timing: timer.results,
      }.to_json,
    )
  end

  private

  def address_proofer
    @address_proofer ||=
      if IdentityConfig.store.proofer_mock_fallback
        Proofing::Mock::AddressMockClient.new
      else
        Proofing::LexisNexis::PhoneFinder::Proofer.new(
          phone_finder_workflow: IdentityConfig.store.lexisnexis_phone_finder_workflow,
          account_id: IdentityConfig.store.lexisnexis_account_id,
          base_url: IdentityConfig.store.lexisnexis_base_url,
          username: IdentityConfig.store.lexisnexis_username,
          password: IdentityConfig.store.lexisnexis_password,
          request_mode: IdentityConfig.store.lexisnexis_request_mode,
        )
      end
  end
end
