# frozen_string_literal: true

module DocAuth
  module Socure
    class WebhookRepeater

      attr_reader :body, :headers

      def initialize(body:, headers:)
        @body = body
        @headers = headers
      end

      def broadcast
        endpoints.each { |endpoint| repeat(endpoint) }
      end

      private

      def repeat(endpoint)
        send_http_post_request(endpoint)
      rescue => exception
        handle_connection_error(exception:, endpoint:)
      end

      def handle_connection_error(exception:, endpoint:)
        NewRelic::Agent.notice_error(exception, custom_params: { endpoint: })
      end

      def send_http_post_request(endpoint)
        faraday_connection(endpoint).post do |req|
          req.options.context = { service_name: 'socure_webhook_repeater' }
          req.body = body.to_json
        end
      end

      def faraday_connection(endpoint)
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

        Faraday.new(url: url(endpoint).to_s, headers: request_headers) do |conn|
          conn.request :retry, retry_options
          conn.request :instrumentation, name: 'request_metric.faraday'
          conn.adapter :net_http
          conn.options.timeout = timeout
          conn.options.read_timeout = timeout
          conn.options.open_timeout = timeout
          conn.options.write_timeout = timeout
        end
      end

      def endpoints
        @endpoints ||= IdentityConfig.store.socure_docv_webhook_repeat_endpoints
      end

      def url(endpoint)
        URI.join(endpoint)
      end

      def request_headers(extras = {})
        headers.merge(extras)
      end

      def timeout
        60
      end
    end
  end
end
