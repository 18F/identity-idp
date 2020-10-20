class VendorDocumentVerificationJob
  def self.perform(_document_capture_session_result_id:,
                   _encryption_key:,
                   _front_image_url:,
                   _back_image_url:,
                   _selfie_image_url:,
                   _liveness_checking_enabled:)

    FormResponse.new(success: true, errors: {})
  end
end
