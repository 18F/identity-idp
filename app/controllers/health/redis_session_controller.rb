module Health
  class RedisSessionController < AbstractHealthController
    private

    def health_checker
      RedisSessionHealthChecker
    end
  end
end
