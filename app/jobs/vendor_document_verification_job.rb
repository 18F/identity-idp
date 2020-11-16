class VendorDocumentVerificationJob
  # rubocop:disable Lint/UnusedMethodArgument
  def self.perform(document_capture_session_result_id:,
                   encryption_key:,
                   front_image_iv:,
                   back_image_iv:,
                   selfie_image_iv:,
                   front_image_url:,
                   back_image_url:,
                   selfie_image_url:,
                   liveness_checking_enabled:)

    FormResponse.new(success: true, errors: {})
  end
  # rubocop:enable Lint/UnusedMethodArgument
end
