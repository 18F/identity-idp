# frozen_string_literal: true

# This is used by resolution and address proofing
# Idv::Agent#proof_resolution and Idv::Agent#proof_address
ProofingSessionAsyncResult = Struct.new(:id, :result, :status, keyword_init: true) do
  self::NONE = 'none'
  self::IN_PROGRESS = 'in_progress'
  self::DONE = 'done'
  self::MISSING = 'missing'

  def self.redis_key_prefix
    'dcs-proofing:result'
  end

  def self.none
    new(status: ProofingSessionAsyncResult::NONE)
  end

  def self.missing
    new(status: ProofingSessionAsyncResult::MISSING)
  end

  def none?
    status == ProofingSessionAsyncResult::NONE
  end

  def missing?
    status == ProofingSessionAsyncResult::MISSING
  end

  def done?
    status == ProofingSessionAsyncResult::DONE
  end

  def in_progress?
    status == ProofingSessionAsyncResult::IN_PROGRESS
  end
end
