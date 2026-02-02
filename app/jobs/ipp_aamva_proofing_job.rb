# frozen_string_literal: true

class IppAamvaProofingJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :high_resolution_proofing

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  def perform(
    result_id:,
    encrypted_arguments:,
    trace_id:,
    user_id:,
    service_provider_issuer: nil
  )
    @user = User.find_by(id: user_id)
    raise ArgumentError, 'User not found' if @user.nil?

    @service_provider_issuer = service_provider_issuer
    timer = JobHelpers::Timer.new

    raise_stale_job! if stale_job?(enqueued_at)

    decrypted_args = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    current_sp = ServiceProvider.find_by(issuer: service_provider_issuer)

    applicant_pii = decrypted_args[:applicant_pii]
    applicant_pii[:uuid_prefix] = current_sp&.app_id
    applicant_pii[:uuid] = @user.uuid

    aamva_result = call_aamva(
      applicant_pii: applicant_pii,
      current_sp: current_sp,
      timer:,
    )

    result_hash = build_result_hash(aamva_result)

    document_capture_session = DocumentCaptureSession.new(result_id: result_id)
    document_capture_session.store_proofing_result(result_hash)
  ensure
    logger_info_hash(
      name: 'IppAamvaProofing',
      trace_id: trace_id,
      aamva_success: aamva_result&.success?,
      timing: timer&.results,
      user_id: @user&.uuid,
    )
  end

  private

  def aamva_plugin
    @aamva_plugin ||= Proofing::Resolution::Plugins::AamvaPlugin.new
  end

  def call_aamva(applicant_pii:, current_sp:, timer:)
    aamva_plugin.call(
      applicant_pii: applicant_pii.freeze,
      current_sp: current_sp,
      state_id_address_resolution_result: nil,
      ipp_enrollment_in_progress: true,
      timer:,
      doc_auth_flow: true,
      analytics:,
    )
  end

  def build_result_hash(aamva_result)
    doc_auth_response = aamva_result.to_doc_auth_response

    {
      success: doc_auth_response.success?,
      errors: doc_auth_response.errors,
      vendor_name: doc_auth_response.extra[:vendor_name],
      aamva_status: doc_auth_response.success? ? :passed : :failed,
      checked_at: Time.zone.now.iso8601,
    }
  end

  def analytics
    @analytics ||= Analytics.new(
      user: @user,
      request: nil,
      session: {},
      sp: @service_provider_issuer,
    )
  end

  def logger_info_hash(hash)
    logger.info(hash.to_json)
  end
end
