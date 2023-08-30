# frozen_string_literal: true

# This is used by hybrid doc auth capture
DocumentCaptureSessionResult = RedactedStruct.new(
  :id,
  :success,
  :pii,
  :attention_with_barcode,
  :failed_front_image_fingerprints,
  :failed_back_image_fingerprints,
  keyword_init: true,
  allowed_members: [:id, :success, :attention_with_barcode, :failed_front_image_fingerprints,
                    :failed_back_image_fingerprints],
) do
  def self.redis_key_prefix
    'dcs:result'
  end

  alias_method :success?, :success
  alias_method :attention_with_barcode?, :attention_with_barcode
  alias_method :pii_from_doc, :pii

  def failed_front_image?(front_fingerprint)
    return false unless self.failed_front_image_fingerprints
    self.failed_front_image_fingerprints.is_a?(Array) &&
      self.failed_front_image_fingerprints.include?(front_fingerprint)
  end

  def failed_back_image?(back_fingerprint)
    return false unless self.failed_back_image_fingerprints
    self.failed_back_image_fingerprints.is_a?(Array) &&
      self.failed_back_image_fingerprints.include?(back_fingerprint)
  end

  def add_failed_front_image!(front_fingerprint)
    self.failed_front_image_fingerprints ||= []
    self.failed_front_image_fingerprints << front_fingerprint
  end

  def add_failed_back_image!(back_fingerprint)
    self.failed_back_image_fingerprints ||= []
    self.failed_back_image_fingerprints << back_fingerprint
  end
end
