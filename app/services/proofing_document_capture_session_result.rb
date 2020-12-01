# frozen_string_literal: true

ProofingDocumentCaptureSessionResult = Struct.new(:id, :pii, :result, :status,
                                                  keyword_init: true) do
  def self.redis_key_prefix
    'dcs-proofing:result'
  end

  def self.none
    new(status: :none)
  end

  def self.timed_out
    new(status: :timed_out)
  end

  def self.in_progress
    new(status: :in_progress)
  end

  alias_method :pii_from_doc, :pii

  def done
    ProofingDocumentCaptureSessionResult.new(
      pii: pii.deep_symbolize_keys,
      result: result.deep_symbolize_keys,
      status: :done,
    )
  end
end
