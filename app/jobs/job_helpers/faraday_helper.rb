require 'faraday'

module JobHelpers
  module FaradayHelper
    def faraday_retry_options
      {
        max_tries: 3,
        rescue: [Faraday::TimeoutError, Faraday::ConnectionFailed],
      }
    end
  end
end
