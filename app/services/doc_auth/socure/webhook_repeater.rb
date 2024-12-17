# frozen_string_literal: true

module DocAuth
  module Socure
    class WebhookRepeater
      attr_reader :body, :headers, :endpoint

      def initialize(body:, headers:, endpoint:)
        @body = body
        @headers = headers
        @endpoint = endpoint
      end

      def repeat
        send_http_post_request(endpoint)
      rescue => exception
        NewRelic::Agent.notice_error(
          exception,
          custom_params: {
            event: 'Failed to repeat webhook',
            endpoint:,
            body:,
          },
        )
      end

      private

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

      def url(endpoint)
        URI.join(endpoint)
      end

      def request_headers(extras = {})
        headers.merge(extras)
      end

      def timeout
        15
      end
    end
  end
end
