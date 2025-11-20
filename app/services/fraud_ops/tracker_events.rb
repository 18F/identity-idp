# frozen_string_literal: true

module FraudOps
  module TrackerEvents
    # @param [Boolean] success
    # @param [String] document_state
    # @param [String] document_number
    # @param [String] document_issued
    # @param [String] document_expiration
    # @param [String] document_back_image_encryption_key Base64-encoded AES key used for back
    # @param [String] document_back_image_file_id Filename in S3 w/encrypted data for back image
    # @param [String] document_front_image_encryption_key Base64-encoded AES key used for front
    # @param [String] document_passport_image_file_id Filename in S3 w/encry data for passport image
    # @param [String] document_passport_image_encryption_key Base64-encoded AES key for passport
    # @param [String] document_front_image_file_id Filename in S3 w/encrypted data for front image
    # @param [String] document_selfie_image_encryption_key Base64-encoded AES key used for selfie
    # @param [String] document_selfie_image_file_id Filename in S3 w/encrypted data for selfie image
    # @param [String] first_name
    # @param [String] last_name
    # @param [String] date_of_birth
    # @param [String] address1
    # @param [String] address2
    # @param [String] city
    # @param [String] state
    # @param [String] zip
    # @param [Hash<Symbol,Array<Symbol>>] failure_reason
    # The document was uploaded during the IDV process
    def fraud_ops_idv_document_upload_submitted(
      success:,
      document_state: nil,
      document_number: nil,
      document_issued: nil,
      document_expiration: nil,
      document_back_image_encryption_key: nil,
      document_back_image_file_id: nil,
      document_front_image_encryption_key: nil,
      document_front_image_file_id: nil,
      document_passport_image_file_id: nil,
      document_passport_image_encryption_key: nil,
      document_selfie_image_encryption_key: nil,
      document_selfie_image_file_id: nil,
      first_name: nil,
      last_name: nil,
      date_of_birth: nil,
      address1: nil,
      address2: nil,
      city: nil,
      state: nil,
      zip: nil,
      failure_reason: nil,
      vendor: nil,
      conversation_id: nil,
      reference_id: nil
    )
      track_event(
        :idv_document_upload_submitted,
        success:,
        document_state:,
        document_number:,
        document_issued:,
        document_expiration:,
        document_back_image_encryption_key:,
        document_back_image_file_id:,
        document_front_image_encryption_key:,
        document_front_image_file_id:,
        document_passport_image_file_id:,
        document_passport_image_encryption_key:,
        document_selfie_image_encryption_key:,
        document_selfie_image_file_id:,
        first_name:,
        last_name:,
        date_of_birth:,
        address1:,
        address2:,
        city:,
        state:,
        zip:,
        failure_reason:,
        vendor:,
        conversation_id:,
        reference_id:,
      )
    end
  end
end
