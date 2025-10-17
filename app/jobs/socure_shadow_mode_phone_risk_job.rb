# frozen_string_literal: true

class SocureShadowModePhoneRiskJob < ApplicationJob
  include JobHelpers::StaleJobHelper

  queue_as :low

  discard_on JobHelpers::StaleJobHelper::StaleJobError

  # @param [String] document_capture_session_result_id
  # @param [String] encrypted_arguments
  # @param [String,nil] service_provider_issuer
  # @param [String] user_email
  # @param [String] user_uuid
  def perform(
    document_capture_session_result_id:,
    encrypted_arguments:,
    service_provider_issuer:,
    user_uuid:
  )
    raise_stale_job! if stale_job?(enqueued_at)

    user = User.find_by(uuid: user_uuid)
    raise "User not found: #{user_uuid}" if !user

    analytics = create_analytics(
      user:,
      service_provider_issuer:,
    )

    proofing_result = load_proofing_result(document_capture_session_result_id:)
    if !proofing_result
      analytics.idv_socure_shadow_mode_phonerisk_result_missing
      return
    end

    user_email = user.last_sign_in_email_address.email
    applicant = build_applicant(encrypted_arguments:, user_email:)

    socure_result = proofer(user:).proof(applicant)

    proofing_result[:timed_out] = proofing_result[:exception].is_a?(Proofing::TimeoutError)

    analytics.idv_socure_shadow_mode_phonerisk_result(
      phone_result: proofing_result,
      socure_result: socure_result,
      phone_source: applicant[:phone_source],
      user_id: user.uuid,
    )
  end

  def create_analytics(
      user:,
      service_provider_issuer:
    )
    Analytics.new(
      user:,
      request: nil,
      sp: service_provider_issuer,
      session: {},
    )
  end

  def load_proofing_result(document_capture_session_result_id:)
    DocumentCaptureSession.new(
      result_id: document_capture_session_result_id,
    ).load_proofing_result&.result
  end

  def build_applicant(
    encrypted_arguments:,
    user_email:
  )
    decrypted_arguments = JSON.parse(
      Encryption::Encryptors::BackgroundProofingArgEncryptor.new.decrypt(encrypted_arguments),
      symbolize_names: true,
    )

    applicant_pii = decrypted_arguments[:applicant_pii]
    if applicant_pii[:phone].nil? && applicant_pii[:best_effort_phone_number_for_socure]
      applicant_pii[:phone] = applicant_pii[:best_effort_phone_number_for_socure][:phone]
      applicant_pii[:phone_source] = applicant_pii[:best_effort_phone_number_for_socure][:source]
    end

    {
      **applicant_pii.slice(
        :first_name,
        :last_name,
        :address1,
        :address2,
        :city,
        :state,
        :zipcode,
        :phone,
        :phone_source,
      ),
      email: user_email,
    }
  end

  def proofer(user:)
    @proofer ||= Proofing::Socure::IdPlus::Proofers::PhoneRiskProofer.new(
      Proofing::Socure::IdPlus::Config.new(
        user_uuid: user.uuid,
        user_email: user.last_sign_in_email_address.email,
        api_key: IdentityConfig.store.socure_idplus_api_key,
        base_url: IdentityConfig.store.socure_idplus_base_url,
        timeout: IdentityConfig.store.socure_idplus_timeout_in_seconds,
      ),
    )
  end
end
