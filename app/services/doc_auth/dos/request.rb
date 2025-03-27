# frozen_string_literal: true

module DocAuth
  module Dos
    class Request
      attr_accessor :correlation_id

      def fetch
        # return DocAuth::Respose with DocAuth:Error if workflow invalid
        http_response = send_http_request
        # log
        return handle_invalid_response(http_response) unless http_response.success?

        handle_http_response(http_response)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError => e
        handle_connection_error(exception: e)
      end

      private

      def event_name
        raise NotImplementedError
      end

      def metric_name
        raise NotImplementedError
      end

      def handle_http_response(response)
        raise NotImplementedError
      end

      def endpoint
        raise NotImplementedError
      end

      def request_headers
        raise NotImplementedError
      end

      def body
        raise NotImplementedError
      end

      def send_http_request
        case http_method.downcase.to_sym
        when :post
          send_http_post_request
        when :get
          send_http_get_request
        else
          raise NotImplementedError.new("HTTP method #{http_method} not implemented")
        end
      end

      def handle_invalid_response(http_response)
        message = [
          self.class.name,
          'Unexpected HTTP response',
          http_response.status,
        ].join(' ')
        exception = DocAuth::RequestError.new(message, http_response.status)

        response_body = begin
          http_response.body.present? ? JSON.parse(http_response.body) : {}
        rescue JSON::JSONError
          {}
        end

        handle_connection_error(
          exception: exception,
          # TODO: update for DoS
          error_code: response_body.dig('error', 'code'),
          error_message: response_body.dig('error', 'message'),
          error_reason: response_body.dig('error', 'reason'),
          correlation_id_received: http_response.headers['X-Correlation-ID'],
        )
      end

      def handle_connection_error(
        exception:,
        error_code: nil,
        error_message: nil,
        error_reason: nil,
        correlation_id_received: nil
      )
        DocAuth::Response.new(
          success: false,
          errors: { network: true },
          exception: exception,
          extra: {
            vendor: 'DoS',
            error_code: error_code,
            error_message: error_message,
            error_reason: error_reason,
            correlation_id_sent: correlation_id,
            correlation_id_received:,
          }.compact,
        )
      end

      def send_http_get_request
        faraday_connection.get do |req|
          req.options.context = { service_name: metric_name }
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
          max: IdentityConfig.store.dos_passport_mrz_maxretry,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2,
          retry_statuses: [404, 500],
          retry_block: lambda do |env:, options:, retry_count:, exception:, will_retry_in:|
            NewRelic::Agent.notice_error(exception, custom_params: { retry: retry_count })
          end,
        }
        Faraday.new(url: endpoint, headers: request_headers) do |conn|
          conn.request :retry, retry_options
          conn.request :instrumentation, name: 'request_metric.faraday'
          conn.adapter :net_http
          conn.options.timeout = timeout
        end
      end

      def http_method
        :get
      end

      def timeout
        IdentityConfig.store.dos_passport_mrz_timeout_seconds
      end
    end
  end
end
