# frozen_string_literal: true

class AddressProofingJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :high_address_proofing

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  def perform(issuer:, result_id:, encrypted_arguments:, trace_id:, user_id:,
              hybrid_handoff_phone_used:, new_phone_added:, opted_in_to_in_person_proofing:)
    timer = JobHelpers::Timer.new

    raise_stale_job! if stale_job?(enqueued_at)

    decrypted_args = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    applicant_pii = decrypted_args[:applicant_pii]
    user = User.find(user_id)
    current_sp = ServiceProvider.find_by(issuer:)
    user_email = user.last_sign_in_email_address.email
    proofer_result = timer.time('address') do
      Proofing::AddressProofer.new(
        user_uuid: user.uuid,
        user_email:,
      ).proof(
        applicant_pii:,
        current_sp:,
        opted_in_to_in_person_proofing:,
        hybrid_handoff_phone_used:,
        new_phone_added:,
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
