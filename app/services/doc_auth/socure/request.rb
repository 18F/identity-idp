# frozen_string_literal: true

module DocAuth
  module Socure
    class Request
      def fetch
        # return DocAuth::Response with DocAuth::Error if workflow is invalid
        http_response = send_http_request
        if http_response.nil? || !http_response.body.present?
          return handle_invalid_response(http_response)
        end
        return handle_invalid_response(http_response) unless http_response.success?

        handle_http_response(http_response)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError => e
        handle_connection_error(exception: e)
      end

      def metric_name
        raise NotImplementedError
      end

      private

      def send_http_request
        case method.downcase.to_sym
        when :post
          send_http_post_request
        when :get
          send_http_get_request
        end
      end

      def handle_http_response(_response)
        raise NotImplementedError
      end

      def handle_invalid_response(http_response)
        begin
          if http_response.body.present?
            warn(http_response.body)
            JSON.parse(http_response.body)
          else
            {}
          end
        rescue JSON::JSONError
          {}
        end
      end

      def handle_connection_error
        raise NotImplementedError
      end

      def send_http_get_request
        faraday_connection.get do |req|
          req.options.context = { service_name: metric_name }
          req.params = params if params&.any?
        end
      end

      def send_http_post_request
        faraday_connection.post do |req|
          req.options.context = { service_name: metric_name }
          req.body = body
        end
      end

      def faraday_connection
        retry_options = {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2,
          retry_statuses: [404, 500],
          retry_block: lambda do |env:, options:, retry_count:, exception:, will_retry_in:|
            NewRelic::Agent.notice_error(exception, custom_params: { retry: retry_count })
          end,
        }

        Faraday.new(url: url.to_s, headers: request_headers) do |conn|
          conn.request :retry, retry_options
          conn.request :instrumentation, name: 'request_metric.faraday'
          conn.adapter :net_http
          conn.options.timeout = timeout
          conn.options.read_timeout = timeout
          conn.options.open_timeout = timeout
          conn.options.write_timeout = timeout
        end
      end

      def endpoint
        raise NotImplementedError
      end

      def method
        :get
      end

      def url
        URI.join(endpoint)
      end

      def request_headers(extras = {})
        {
          'Content-Type': 'application/json',
          Authorization: "SocureApiKey #{IdentityConfig.store.socure_idplus_api_key}",
        }.merge(extras)
      end

      def timeout
        60
      end

      def params
        {}
      end
    end
  end
end
