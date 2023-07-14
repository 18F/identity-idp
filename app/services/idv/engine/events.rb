# 👋 This file was automatically generated. Please don't edit it by hand.

module Idv::Engine::Events
  ALL = [
    :auth_password_reset,
    :idv_address_submitted_to_instantverify,
    :idv_consented,
    :idv_documents_submitted_to_acuant,
    :idv_documents_submitted_to_trueid,
    :idv_info_submitted_to_aamva,
    :idv_info_submitted_to_lexisnexis_trueid,
    :idv_info_verified_by_user,
    :idv_mailing_address_updated_by_user,
    :idv_residential_address_submitted_to_instantverify,
    :idv_ssn_entered_by_user,
    :idv_started,
    :idv_threatmetrix_check_completed,
    :idv_threatmetrix_check_initiated,
  ].freeze

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

  IdvMailingAddressUpdatedByUserParams = Struct.new(
    :address,
    keyword_init: true,
  )

  IdvSsnEnteredByUserParams = Struct.new(
    :ssn,
    keyword_init: true,
  )

  IdvThreatmetrixCheckCompletedParams = Struct.new(
    :response_status,
    :response_success,
    :threatmetrix_session_id,
    :threatmetrix_result,
    keyword_init: true,
  )

  IdvThreatmetrixCheckInitiatedParams = Struct.new(
    :threatmetrix_session_id,
    keyword_init: true,
  )

  # The user has reset their password and will not be able to access their IDV
  # PII until providing their personal key.
  # @return [nil]
  def auth_password_reset
    handle_event :auth_password_reset
    nil
  end

  # The user's address was submitted to LexisNexis InstantVerify.
  # @return [nil]
  def idv_address_submitted_to_instantverify
    handle_event :idv_address_submitted_to_instantverify
    nil
  end

  # The user has consented to share PII with Login.gov for the purposes of
  # identity verification.
  # @return [nil]
  def idv_consented
    handle_event :idv_consented
    nil
  end

  # The user has uploaded identity documents, and Login.gov has submitted them
  # to Acuant for  processing.
  # @param [Object] params
  # @return [IdvDocumentsSubmittedToAcuantParams]
  def idv_documents_submitted_to_acuant(params)
    handle_event :idv_documents_submitted_to_acuant, params
    params
  end

  # The user has uploaded identity documents, and Login.gov has submitted them
  # to LexisNexis TrueID for processing.
  # @param [Object] params
  # @return [IdvDocumentsSubmittedToTrueidParams]
  def idv_documents_submitted_to_trueid(params)
    handle_event :idv_documents_submitted_to_trueid, params
    params
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

  # The user has reviewed (and possibly updated) the information from their
  # identity documents.
  # @param [Object] params
  # @return [Object]
  def idv_info_verified_by_user(params)
    handle_event :idv_info_verified_by_user, params
    params
  end

  # The user manually updated their mailing address.
  # @param [Object] params
  # @return [IdvMailingAddressUpdatedByUserParams]
  def idv_mailing_address_updated_by_user(params)
    handle_event :idv_mailing_address_updated_by_user, params
    params
  end

  # The user's residential address was submitted to LexisNexis InstantVerify.
  # This is used during the In-Person Proofing flow and may be different than
  # the address on their identification documents.
  # @return [nil]
  def idv_residential_address_submitted_to_instantverify
    handle_event :idv_residential_address_submitted_to_instantverify
    nil
  end

  # The user has entered their Social Security Number (SSN).
  # @param [Object] params
  # @return [IdvSsnEnteredByUserParams]
  def idv_ssn_entered_by_user(params)
    handle_event :idv_ssn_entered_by_user, params
    params
  end

  # The user has confirmed their desire to begin the identity verification
  # process. They have NOT necessarily yet consented to share their PII with
  # Login.gov.
  # @return [nil]
  def idv_started
    handle_event :idv_started
    nil
  end

  # Login.gov requested the result of an automated fraud check. The response
  # details will b
  # @param [Object] params
  # @return [IdvThreatmetrixCheckCompletedParams]
  def idv_threatmetrix_check_completed(params)
    handle_event :idv_threatmetrix_check_completed, params
    params
  end

  # Login.gov has initiated an automated fraud check for the user using
  # LexisNexis ThreatMetrix.
  # @param [Object] params
  # @return [IdvThreatmetrixCheckInitiatedParams]
  def idv_threatmetrix_check_initiated(params)
    handle_event :idv_threatmetrix_check_initiated, params
    params
  end
end
