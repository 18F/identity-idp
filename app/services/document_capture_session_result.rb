# frozen_string_literal: true

# This is used by hybrid doc auth capture
DocumentCaptureSessionResult = RedactedStruct.new(
  :id,
  :success,
  :pii,
  :attention_with_barcode,
  keyword_init: true,
  allowed_members: [:id, :success, :attention_with_barcode],
) do
  def self.redis_key_prefix
    'dcs:result'
  end

  alias_method :success?, :success
  alias_method :attention_with_barcode?, :attention_with_barcode
  alias_method :pii_from_doc, :pii
end
