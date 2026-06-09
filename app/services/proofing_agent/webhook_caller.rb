# frozen_string_literal: true

module ProofingAgent
  class WebhookCaller
    include Config
    attr_reader :success, :reason, :transaction_id, :correlation_id, :analytics_attributes

    def initialize(success:, reason:, transaction_id:, correlation_id:,
                   analytics_attributes:)
      @success = success
      @reason = reason
      @transaction_id = transaction_id
      @correlation_id = correlation_id
      @analytics_attributes = analytics_attributes
    end

    def call
      return if webhook_url.blank?

      response = send_http_post_request
      analytics.idv_proofing_agent_webhook(
        success: response.success?,
        proofing_agent: analytics_attributes[:proofing_agent],
        body_payload: payload,
        issuer: service_provider_issuer,
        response: response.to_hash,
        proofing_components: analytics_attributes[:proofing_components],
      )
    rescue => exception
      NewRelic::Agent.notice_error(
        exception,
        custom_params: {
          event: 'Failed to deliver proofing agent webhook',
          webhook_url:,
          transaction_id:,
        },
      )
      analytics.idv_proofing_agent_webhook(
        success: false,
        proofing_agent: analytics_attributes[:proofing_agent],
        body_payload: payload,
        issuer: service_provider_issuer,
        response: exception&.message,
        proofing_components: analytics_attributes[:proofing_components],
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

      Faraday.new(url: URI.join(webhook_url).to_s) do |conn|
        conn.request :retry, retry_options
        conn.request :instrumentation, name: 'request_metric.faraday'
        conn.adapter :net_http
        conn.options.timeout = timeout
        conn.options.read_timeout = timeout
        conn.options.open_timeout = timeout
        conn.options.write_timeout = timeout
        conn.headers['Authorization'] = "Bearer #{webhook_secret}" if webhook_secret.present?
        conn.headers['X-Correlation-ID'] = correlation_id
        conn.headers['Content-Type'] = 'application/json'
        conn.headers.merge!(webhook_custom_headers)
      end
    end

    def document_capture_session
      @document_capture_session ||= DocumentCaptureSession.find_by(uuid: transaction_id)
    end

    def service_provider_issuer
      document_capture_session&.issuer
    end

    def user
      @user ||= document_capture_session.user
    end

    def analytics
      @analytics ||= Analytics.new(
        user: user,
        request: nil,
        session: {},
        sp: service_provider_issuer,
      )
    end
  end
end
