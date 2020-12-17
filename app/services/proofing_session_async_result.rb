# frozen_string_literal: true

# This is used by resolution and address proofing
# Idv::Agent#proof_resolution and Idv::Agent#proof_address
# NOTE: remove pii key after next deploy
ProofingSessionAsyncResult = Struct.new(:id, :pii, :result, :status,
                                                  keyword_init: true) do
  self::NONE = 'none'
  self::IN_PROGRESS = 'in_progress'
  self::DONE = 'done'
  self::TIMED_OUT = 'timed_out'

  def self.redis_key_prefix
    'dcs-proofing:result'
  end

  def self.none
    new(status: ProofingSessionAsyncResult::NONE)
  end

  def self.timed_out
    new(status: ProofingSessionAsyncResult::TIMED_OUT)
  end

  def none?
    status == ProofingSessionAsyncResult::NONE
  end

  def timed_out?
    status == ProofingSessionAsyncResult::TIMED_OUT
  end

  def done?
    status == ProofingSessionAsyncResult::DONE || result.present?
  end

  def in_progress?
    status == ProofingSessionAsyncResult::IN_PROGRESS ||
      pii.present?
  end

  def done
    ProofingSessionAsyncResult.new(
      result: result.deep_symbolize_keys,
      status: :done,
    )
  end
end
