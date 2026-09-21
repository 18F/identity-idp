# frozen_string_literal: true

class Idv::ProofingAgent::FailureEmailUserSet
  KEY = 'idv:proofing_agent_failure_email:users'

  def initialize(redis_pool: REDIS_POOL)
    @redis_pool = redis_pool
  end

  # Add uuid to the "idv:proofing_agent_failure_email:users" set with a current time (unix
  # timestamp) as the zscore. Will update the current time when the uuid already exists.
  # @param [String] user_uuid The user's uuid.
  # @return [Boolean] Whether the item has been added to the set. False if member already exists
  def add(user_uuid)
    REDIS_POOL.with { |client| client.zadd(KEY, Time.zone.now.to_i, user_uuid) }
  end

  # Remove uuid from the "idv:proofing_agent_failure_email:users" set.
  # @param [String] user_uuid The user's uuid.
  # @return [Boolean] whether the item has been removed from the set.
  def remove(user_uuid)
    return false unless exist?(user_uuid)

    REDIS_POOL.with { |client| client.zrem(KEY, user_uuid) }
  end

  private

  def exist?(user_uuid)
    REDIS_POOL.with { |client| client.zscore(KEY, user_uuid) }.present?
  end
end
