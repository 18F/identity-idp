class VendorValidatorResultStorage
  TTL = Figaro.env.session_timeout_in_minutes.to_i.minutes.seconds.to_i

  def store(result_id:, result:)
    Sidekiq.redis do |redis|
      redis.setex(redis_key(result_id), TTL, result.to_json)
    end
  end

  def load(result_id)
    result_json = Sidekiq.redis do |redis|
      redis.get(redis_key(result_id))
    end

    return unless result_json

    Idv::VendorResult.new_from_json(result_json)
  end

  # @api private
  def redis_key(result_id)
    "vendor-validator-result-#{result_id}"
  end
end
