module Proofing
  module Mock
    class DeviceProfilingBackend
      RESULTS = %w[
        no_result
        pass
        reject
        review
      ].to_set.freeze

      RESULT_TIMEOUT = 3600

      def record_profiling_result(session_id:, result:)
        raise ArgumentError, "unknown result=#{result}" if !RESULTS.include?(result)

        REDIS_POOL.with do |redis|
          redis.setex("tmx_mock:#{session_id}", RESULT_TIMEOUT, result)
        end
      end

      def profiling_result(session_id)
        REDIS_POOL.with do |redis|
          redis.get("tmx_mock:#{session_id}")
        end
      end
    end
  end
end
