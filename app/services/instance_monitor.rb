class InstanceMonitor
  def self.error_rate
     results = REDIS_POOL.with do |client|
      client.pipelined do
        client.get(self.request_error_key)
        client.get(self.request_key)
      end
    end

    errors = results[0].to_f
    requests = results[1].to_i

    if requests > 0
      errors / requests
    else
      0
    end
  end

  def self.increment_request_counter(is_error:)
    REDIS_POOL.with do |client|
      client.pipelined do
        client.incr(self.request_error_key) if is_error
        client.incr(self.request_key)
        client.expire(self.request_error_key, 120)
        client.expire(self.request_key, 120)
      end
    end
  end

  def self.request_key
    "#{IdentityConfig::GIT_SHA}:requests"
  end

  def self.request_error_key
    "#{IdentityConfig::GIT_SHA}:request_errors"
  end
end
