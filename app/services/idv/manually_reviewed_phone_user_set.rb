# frozen_string_literal: true

module Idv
  class ManuallyReviewedPhoneUserSet
    attr_reader :redis_pool

    KEY = 'idv:manually_reviewed_phone:users'

    def initialize(redis_pool: REDIS_POOL)
      @redis_pool = redis_pool
    end

    def add_user!(user_uuid:)
      redis_pool.with do |client|
        client.zadd(KEY, Time.zone.now.to_i, user_uuid)
      end
    end

    def remove_user!(user_uuid:)
      redis_pool.with do |client|
        client.zrem(KEY, user_uuid)
      end
    end

    def member?(user_uuid:)
      fetch_member_score(user_uuid:).present?
    end

    def fetch_member_score(user_uuid:)
      redis_pool.with do |client|
        client.zscore(KEY, user_uuid)
      end
    end

    def active_member?(user_uuid:)
      score = fetch_member_score(user_uuid:)
      return false if score.blank?

      Time.zone.at(score.to_i) > (Time.zone.now - time_valid)
    end

    def count
      redis_pool.with do |client|
        client.zcard(KEY)
      end
    end

    private

    def time_valid
      IdentityConfig.store.idv_phone_confirmation_manual_review_validity_hours.hours
    end
  end
end
