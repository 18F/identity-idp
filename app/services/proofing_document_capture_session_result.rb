# frozen_string_literal: true

# This is used by resolution and address proofing
# Idv::Agent#proof_resolution and Idv::Agent#proof_address
# NOTE: remove pii key after next deploy
ProofingDocumentCaptureSessionResult = Struct.new(:id, :pii, :result, :status,
                                                  keyword_init: true) do
  self::NONE = 'none'
  self::IN_PROGRESS = 'in_progress'
  self::DONE = 'done'
  self::TIMED_OUT = 'timed_out'

  def self.redis_key_prefix
    'dcs-proofing:result'
  end

  def self.none
    new(status: ProofingDocumentCaptureSessionResult::NONE)
  end

  def self.timed_out
    new(status: ProofingDocumentCaptureSessionResult::TIMED_OUT)
  end

  def timed_out?
    status == ProofingDocumentCaptureSessionResult::TIMED_OUT
  end

  def done?
    status == ProofingDocumentCaptureSessionResult::DONE
  end

  def in_progress?
    status == ProofingDocumentCaptureSessionResult::IN_PROGRESS ||
      pii.present?
  end

  def done
    ProofingDocumentCaptureSessionResult.new(
      result: result.deep_symbolize_keys,
      status: :done,
    )
  end
end
