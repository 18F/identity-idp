class VendorDocumentVerificationJob
  def self.perform(**_args)
    # call lambda with document_capture_session_uuid:, front_image_url:, back_image_url:,
    #                  selfie_image_url:, liveness_checking_enabled:

    FormResponse.new(success: true, errors: {})
  end
end
