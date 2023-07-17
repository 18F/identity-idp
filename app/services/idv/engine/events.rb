# 👋 This file was automatically generated.

module Idv::Engine::Events
  ALL = [
    :auth_user_changed_password,
    :auth_user_reset_password,
    :idv_address_submitted_to_instantverify,
    :idv_documents_submitted_to_acuant,
    :idv_documents_submitted_to_trueid,
    :idv_fraud_threatmetrix_check_completed,
    :idv_fraud_threatmetrix_check_initiated,
    :idv_gpo_user_requested_letter,
    :idv_gpo_user_verified_otp,
    :idv_info_submitted_to_aamva,
    :idv_info_submitted_to_lexisnexis_trueid,
    :idv_residential_address_submitted_to_instantverify,
    :idv_user_consented_to_share_pii,
    :idv_user_entered_password,
    :idv_user_entered_ssn,
    :idv_user_started,
    :idv_user_updated_mailing_address,
    :idv_user_verified_their_info,
  ].freeze

  AuthUserChangedPasswordParams = Struct.new(
    :password,
    keyword_init: true,
  )

  IdvDocumentsSubmittedToAcuantParams = Struct.new(
    :response_status,
    :billed,
    :doc_auth_result,
    :processed_alerts,
    :alert_failure_count,
    :address_line2_present,
    keyword_init: true,
  )

  IdvDocumentsSubmittedToTrueidParams = Struct.new(
    :response_status,
    :billed,
    :doc_auth_result,
    :processed_alerts,
    :alert_failure_count,
    :address_line2_present,
    keyword_init: true,
  )

  IdvFraudThreatmetrixCheckCompletedParams = Struct.new(
    :request_success,
    :request_timed_out,
    :response_status,
    :threatmetrix_session_id,
    :threatmetrix_review_status,
    keyword_init: true,
  )

  IdvFraudThreatmetrixCheckInitiatedParams = Struct.new(
    :threatmetrix_session_id,
    keyword_init: true,
  )

  IdvUserEnteredPasswordParams = Struct.new(
    :password,
    keyword_init: true,
  )

  IdvUserEnteredSsnParams = Struct.new(
    :ssn,
    keyword_init: true,
  )

  IdvUserUpdatedMailingAddressParams = Struct.new(
    :address,
    keyword_init: true,
  )

  # The user has changed their password.
  # @param [Object] params
  # @return [AuthUserChangedPasswordParams]
  def auth_user_changed_password(params)
    raise 'params cannot be nil' if params.nil?

    if params.is_a?(Hash)
      params = AuthUserChangedPasswordParams.new(params)
    end

    handle_event :auth_user_changed_password, params
    params
  end

  # The user has reset their password and will not be able to access their IDV
  # PII until providing their personal key.
  # @return [nil]
  def auth_user_reset_password
    handle_event :auth_user_reset_password
    nil
  end

  # The user's address was submitted to LexisNexis InstantVerify.
  # @return [nil]
  def idv_address_submitted_to_instantverify
    handle_event :idv_address_submitted_to_instantverify
    nil
  end

  # The user has uploaded identity documents, and Login.gov has submitted them
  # to Acuant for  processing.
  # @param [Object] params
  # @return [IdvDocumentsSubmittedToAcuantParams]
  def idv_documents_submitted_to_acuant(params)
    raise 'params cannot be nil' if params.nil?

    if params.is_a?(Hash)
      params = IdvDocumentsSubmittedToAcuantParams.new(params)
    end

    handle_event :idv_documents_submitted_to_acuant, params
    params
  end

  # The user has uploaded identity documents, and Login.gov has submitted them
  # to LexisNexis  TrueID for processing.
  # @param [Object] params
  # @return [IdvDocumentsSubmittedToTrueidParams]
  def idv_documents_submitted_to_trueid(params)
    raise 'params cannot be nil' if params.nil?

    if params.is_a?(Hash)
      params = IdvDocumentsSubmittedToTrueidParams.new(params)
    end

    handle_event :idv_documents_submitted_to_trueid, params
    params
  end

  # Login.gov requested the result of an automated fraud check.
  # @param [Object] params
  # @return [IdvFraudThreatmetrixCheckCompletedParams]
  def idv_fraud_threatmetrix_check_completed(params)
    raise 'params cannot be nil' if params.nil?

    if params.is_a?(Hash)
      params = IdvFraudThreatmetrixCheckCompletedParams.new(params)
    end

    handle_event :idv_fraud_threatmetrix_check_completed, params
    params
  end

  # Login.gov has initiated an automated fraud check for the user using
  # LexisNexis ThreatMetrix.
  # @param [Object] params
  # @return [IdvFraudThreatmetrixCheckInitiatedParams]
  def idv_fraud_threatmetrix_check_initiated(params)
    raise 'params cannot be nil' if params.nil?

    if params.is_a?(Hash)
      params = IdvFraudThreatmetrixCheckInitiatedParams.new(params)
    end

    handle_event :idv_fraud_threatmetrix_check_initiated, params
    params
  end

  # The user has requested a letter to verify their address.
  # @return [nil]
  def idv_gpo_user_requested_letter
    handle_event :idv_gpo_user_requested_letter
    nil
  end

  # The user entered the one time password (OTP) they received via US mail.
  # @return [nil]
  def idv_gpo_user_verified_otp
    handle_event :idv_gpo_user_verified_otp
    nil
  end

  # The information from the user's identity documents was submitted to the
  # American Association of Motor Vehicle Administrators (AAMVA) for
  # verification.
  # @return [nil]
  def idv_info_submitted_to_aamva
    handle_event :idv_info_submitted_to_aamva
    nil
  end

  # Login.gov made a request to LexisNexis TrueID to verify the user's identity.
  # @return [nil]
  def idv_info_submitted_to_lexisnexis_trueid
    handle_event :idv_info_submitted_to_lexisnexis_trueid
    nil
  end

  # The user's residential address was submitted to LexisNexis InstantVerify.
  # This is used during the In-Person Proofing flow and may be different than
  # the address on their identification documents.
  # @return [nil]
  def idv_residential_address_submitted_to_instantverify
    handle_event :idv_residential_address_submitted_to_instantverify
    nil
  end

  # The user has consented to share PII with Login.gov for the purposes of
  # identity verification.
  # @return [nil]
  def idv_user_consented_to_share_pii
    handle_event :idv_user_consented_to_share_pii
    nil
  end

  # The user has entered their password to encrypt their PII.
  # @param [Object] params
  # @return [IdvUserEnteredPasswordParams]
  def idv_user_entered_password(params)
    raise 'params cannot be nil' if params.nil?

    if params.is_a?(Hash)
      params = IdvUserEnteredPasswordParams.new(params)
    end

    handle_event :idv_user_entered_password, params
    params
  end

  # The user has entered their Social Security Number (SSN).
  # @param [Object] params
  # @return [IdvUserEnteredSsnParams]
  def idv_user_entered_ssn(params)
    raise 'params cannot be nil' if params.nil?

    if params.is_a?(Hash)
      params = IdvUserEnteredSsnParams.new(params)
    end

    handle_event :idv_user_entered_ssn, params
    params
  end

  # The user has confirmed their desire to begin the identity verification
  # process. They have NOT necessarily yet consented to share their PII with
  # Login.gov.
  # @return [nil]
  def idv_user_started
    handle_event :idv_user_started
    nil
  end

  # The user manually updated their mailing address.
  # @param [Object] params
  # @return [IdvUserUpdatedMailingAddressParams]
  def idv_user_updated_mailing_address(params)
    raise 'params cannot be nil' if params.nil?

    if params.is_a?(Hash)
      params = IdvUserUpdatedMailingAddressParams.new(params)
    end

    handle_event :idv_user_updated_mailing_address, params
    params
  end

  # The user confirmed the accuracy of the PII on file and chose to continue the
  # IDV process.
  # @return [nil]
  def idv_user_verified_their_info
    handle_event :idv_user_verified_their_info
    nil
  end
end
