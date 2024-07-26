# frozen_string_literal: true

module DocAuth
  module Socure
    class Request

      def fetch
        http_response = send_http_request
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
          status_code: response_body.dig('status'),
          status_message: response_body.dig('msg'),
          reference_id: response_body.dig('referenceId'),
        )
      end

      def handle_connection_error(exception:, status_code: nil, status_message: nil, reference_id: nil)
        NewRelic::Agent.notice_error(exception)
        DocAuth::Response.new(
          success: false,
          errors: { network: true },
          exception: exception,
          extra: {
            vendor: 'Socure',
            vendor_status_code: status_code,
            vendor_status_message: status_message,
            reference_id: reference_id,
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
          Authorization: "SocureApiKey #{IdentityConfig.store.socure_id_key}",
        }.merge(extras)
      end

      def timeout
        60
      end
    end
  end
end
