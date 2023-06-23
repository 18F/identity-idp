module ArcgisApi::Faraday
  # Log retries from the Faraday retry middleware
  class RetryLogger
    def initialize(analytics:)
      @analytics = analytics || Analytics.new(
        user: AnonymousUser.new,
      )
    end

    # @param [Faraday::Env] env Request environment
    # @param [Faraday::Options] options middleware options
    # @param [Integer] retry_count how many retries have already occured (starts at 0)
    # @param [Exception] exception exception that triggered the retry,
    #        will be the synthetic `Faraday::RetriableResponse` if the
    #        retry was triggered by something other than an exception.
    # @param [Float] will_retry_in retry_block is called *before* the retry
    #        delay, actual retry will happen in will_retry_in number of
    #        seconds.
    def log_retry(env:, options:, retry_count:, exception:, will_retry_in:)
      resp_body = env.body.then do |body|
        if body.is_a?(String)
          JSON.parse(body)
        else
          body
        end
      rescue
        body
      end

      http_status = env.status
      api_status_code = resp_body.is_a?(Hash) ? resp_body.dig('error', 'code') : http_status
      analytics.idv_arcgis_token_failure(
        exception_class: exception.class.name,
        exception_message: exception.message,
        response_body_present: resp_body.present?,
        response_body: resp_body,
        response_status_code: http_status,
        api_status_code: api_status_code,

        # Include retry-specific data
        retry_count:,
        retry_max: options.max,
        will_retry_in:,
      )
    end

    attr_accessor :analytics
  end
end
