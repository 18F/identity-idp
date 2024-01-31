# frozen_string_literal: true

# This is used by hybrid doc auth capture
DocumentCaptureSessionResult = RedactedStruct.new(
  :id,
  :success,
  :pii,
  :attention_with_barcode,
  :failed_front_image_fingerprints,
  :failed_back_image_fingerprints,
  :failed_selfie_image_fingerprints,
  :captured_at,
  :selfie_check_performed,
  :doc_auth_success, :selfie_status, :selfie_success,
  keyword_init: true,
  allowed_members: [:id, :success, :attention_with_barcode, :failed_front_image_fingerprints,
                    :failed_back_image_fingerprints, :failed_selfie_image_fingerprints,
                    :captured_at, :selfie_check_performed, :doc_auth_success, :selfie_status,
                    :selfie_success]
) do
  include DocAuth::SelfieConcern

  def self.redis_key_prefix
    'dcs:result'
  end

  def selfie_status
    self[:selfie_status].to_sym
  end

  def success_status
    # doc_auth_success : including document, attention_with_barcode and id type verification
    (doc_auth_success && selfie_status != :fail) || success
  end

  alias_method :success?, :success_status
  alias_method :attention_with_barcode?, :attention_with_barcode
  alias_method :pii_from_doc, :pii

  %w[front back selfie].each do |side|
    define_method(:"add_failed_#{side}_image!") do |fingerprint|
      member_name = "failed_#{side}_image_fingerprints"
      self[member_name] ||= []
      if fingerprint && !self[member_name].include?(fingerprint)
        self[member_name] << fingerprint
      end
    end

    define_method(:"failed_#{side}_image?") do |fingerprint|
      member_name = "failed_#{side}_image_fingerprints"
      return false unless self[member_name]&.is_a?(Array)
      return self[member_name]&.include?(fingerprint)
    end
  end
end
