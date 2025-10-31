# frozen_string_literal: true

class AddressProofingJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :high_address_proofing

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  def perform(issuer:, result_id:, encrypted_arguments:, trace_id:, user_id: nil)
    timer = JobHelpers::Timer.new

    raise_stale_job! if stale_job?(enqueued_at)

    decrypted_args = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    applicant_pii = decrypted_args[:applicant_pii]
    user = User.find(user_id)
    proofer_result = timer.time('address') do
      Proofing::AddressProofer.new(
        user_uuid: user.uuid,
        user_email: user.last_sign_in_email_address.email,
      ).proof(
        applicant_pii:,
        request_ip: decrypted_args[:request_ip],
        timer:,
        current_sp: ServiceProvider.find_by(issuer: issuer),
      )
    end

    document_capture_session = DocumentCaptureSession.new(result_id:)
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

    if IdentityConfig.store.idv_socure_phonerisk_shadow_mode
      SocureShadowModePhoneRiskJob.perform_later(
        document_capture_session_result_id: result_id,
        encrypted_arguments:,
        service_provider_issuer: issuer,
        user_uuid: user.uuid,
      )
    end
  end
end
