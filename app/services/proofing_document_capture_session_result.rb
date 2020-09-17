# frozen_string_literal: true

ProofingDocumentCaptureSessionResult = Struct.new(:id, :pii, :result, keyword_init: true) do
  def self.redis_key_prefix
   'dcs-proofing:result'
  end
end
