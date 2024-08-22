# frozen_string_literal: true

class SocureShadowModeProofingJob < ApplicationJob
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
    user_email:,
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
      analytics.idv_socure_shadow_mode_proofing_result_missing(
        # NOTE: user_id in Analytics parlance is *actually* the uuid. Passing it
        #       here will make sure that properties.user_id is set correctly on
        #       the logged event
        user_id: user.uuid,
      )
      return
    end

    applicant = build_applicant(encrypted_arguments:, user_email:)

    socure_result = proofer.proof(applicant)

    analytics.idv_socure_shadow_mode_proofing_result(
      resolution_result: proofing_result.to_h,
      socure_result: socure_result.to_h,
      user_id: user.uuid,
      pii_like_keypaths: [
        [:errors, :ssn],
        [:resolution_result, :context, :stages, :resolution, :errors, :ssn],
        [:resolution_result, :context, :stages, :residential_address, :errors, :ssn],
        [:resolution_result, :context, :stages, :threatmetrix, :response_body, :first_name],
        [:resolution_result, :context, :stages, :state_id, :state_id_jurisdiction],
      ],
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
        :dob,
        :ssn,
      ),
      email: user_email,
    }
  end

  def proofer
    @proofer ||= Proofing::Socure::IdPlus::Proofer.new(
      Proofing::Socure::IdPlus::Config.new(
        api_key: IdentityConfig.store.socure_idplus_api_key,
        base_url: IdentityConfig.store.socure_idplus_base_url,
        timeout: IdentityConfig.store.socure_idplus_timeout_in_seconds,
      ),
    )
  end
end
