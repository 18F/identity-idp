# frozen_string_literal: true

# This is used by resolution and address proofing
# Idv::Agent#proof_resolution and Idv::Agent#proof_address
ProofingSessionAsyncResult = Struct.new(:id, :result, :status, keyword_init: true) do
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
    status == ProofingSessionAsyncResult::TIMED_OUT || result[:timed_out]
  end

  def done?
    status == ProofingSessionAsyncResult::DONE
  end

  def in_progress?
    status == ProofingSessionAsyncResult::IN_PROGRESS
  end
end
