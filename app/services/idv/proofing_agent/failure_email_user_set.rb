# frozen_string_literal: true

class Idv::ProofingAgent::FailureEmailUserSet
  KEY = 'idv:proofing_agent_failure_email:users'

  def initialize
    @redis_pool = REDIS_POOL
  end

  # Add uuid to the "idv:proofing_agent_failure_email:users" set with a current time (unix
  # timestamp) as the zscore. Will update the current time when the uuid already exists.
  # @param user_uuid [String] The user's uuid.
  # @return [Boolean] Whether the item has been added to the set. False if member already exists
  def add(user_uuid)
    redis_pool.with { |client| client.zadd(KEY, Time.zone.now.to_i, user_uuid) }
  end

  # Finds all uuids in the "idv:proofing_agent_failure_email:users" with zscores between the
  # specified value.
  # @param min_time [String] The minimum value the unix timestamp can be.
  # @param max_time [String] The maximum value the unix timestamp can be.
  # @return [Array<String>] The uuids found between the specified unix time range.
  def find_by_time_range(min_time, max_time)
    redis_pool.with { |client| client.zrange(KEY, min_time, max_time, by_score: true) }
  end

  # Remove uuid from the "idv:proofing_agent_failure_email:users" set.
  # @param user_uuid [String] The user's uuid.
  # @return [Boolean] whether the item has been removed from the set.
  def remove(user_uuid)
    return false unless exist?(user_uuid)

    redis_pool.with { |client| client.zrem(KEY, user_uuid) }
  end

  # Removes uuids from the "idv:proofing_agent_failure_email:users" set.
  # @param user_uuids [Array<String>] List of user uuids.
  # @return [Boolean] whether the item has been removed from the set.
  def remove_uuids(user_uuids)
    redis_pool.with { |client| client.zrem(KEY, user_uuids) }
  end

  private

  attr_reader :redis_pool

  def exist?(user_uuid)
    redis_pool.with { |client| client.zscore(KEY, user_uuid) }.present?
  end
end
