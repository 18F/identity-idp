require 'faraday'

module IdentityIdpFunctions
  module FaradayHelper
    # @return [Faraday::Connection] builds a Faraday instance with our defaults
    def build_faraday
      Faraday.new do |conn|
        conn.options.timeout = 3
        conn.options.read_timeout = 3
        conn.options.open_timeout = 3
        conn.options.write_timeout = 3

        # raises errors on 4XX or 5XX responses
        conn.response :raise_error
      end
    end

    def faraday_retry_options
      {
        max_tries: 3,
        rescue: [Faraday::TimeoutError, Faraday::ConnectionFailed],
      }
    end
  end
end
