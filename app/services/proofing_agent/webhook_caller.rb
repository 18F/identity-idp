# frozen_string_literal: true

module ProofingAgent
  class WebhookCaller
    attr_reader :webhook_url, :success, :reason, :transaction_id

    def initialize(webhook_url:, success:, reason:, transaction_id:)
      @webhook_url = webhook_url
      @success = success
      @reason = reason
      @transaction_id = transaction_id
    end

    def call
      send_http_post_request
    rescue => exception
      NewRelic::Agent.notice_error(
        exception,
        custom_params: {
          event: 'Failed to deliver proofing agent webhook',
          webhook_url:,
          transaction_id:,
        },
      )
    end

    private

    def send_http_post_request
      faraday_connection.post do |req|
        req.options.context = { service_name: 'proofing_agent_webhook' }
        req.body = payload.to_json
      end
    end

    def payload
      {
        success:,
        reason:,
        transaction_id:,
      }
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

      timeout = 15

      Faraday.new(url: URI.join(webhook_url).to_s, headers: request_headers) do |conn|
        conn.request :retry, retry_options
        conn.request :instrumentation, name: 'request_metric.faraday'
        conn.adapter :net_http
        conn.options.timeout = timeout
        conn.options.read_timeout = timeout
        conn.options.open_timeout = timeout
        conn.options.write_timeout = timeout
      end
    end

    def request_headers
      { 'Content-Type' => 'application/json' }
    end
  end
end
