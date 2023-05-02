module Proofing
  module LexisNexis
    class RequestError < StandardError; end

    class Request
      attr_reader :config, :applicant, :url, :headers, :body

      def initialize(config:, applicant:)
        @config = config
        @applicant = applicant
        @body = build_request_body
        @headers = build_request_headers
        @url = build_request_url
      end

      def send
        conn = Faraday.new do |f|
          f.request :instrumentation, name: 'request_metric.faraday'
          unless hmac_auth_enabled?
            f.request :authorization, :basic, config.username, config.password
          end
          f.options.timeout = timeout
          f.options.read_timeout = timeout
          f.options.open_timeout = timeout
          f.options.write_timeout = timeout
        end

        Response.new(
          conn.post(url, body, headers) do |req|
            req.options.context = { service_name: metric_name }
          end,
        )
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        # NOTE: This is only for when Faraday is using NET::HTTP if the adapter is changed
        # this will have to change to handle timeouts
        if e.message == 'execution expired'
          raise ::Proofing::TimeoutError,
                'LexisNexis timed out waiting for verification response'
        else
          message = "Lexis Nexis request raised #{e.class} with the message: #{e.message}"
          raise LexisNexis::RequestError, message
        end
      end

      private

      def account_number
        config.account_id
      end

      def base_url
        config.base_url
      end

      def build_request_headers
        headers = {
          'Content-Type' => 'application/json',
        }
        headers['Authorization'] = hmac_authorization if hmac_auth_enabled?
        headers
      end

      def hmac_auth_enabled?
        IdentityConfig.store.lexisnexis_hmac_auth_enabled
      end

      # Example HMAC auth header from RDP_REST_V3_DecisioningGuide_March22.pdf, page 21
      def hmac_authorization
        hmac = OpenSSL::HMAC.base64digest('SHA256', config.hmac_secret_key, body)
        ts = Time.zone.now.strftime('%s%L')
        nonce = SecureRandom.uuid
        host = base_url.gsub('https://', '')
        signature = build_signature(ts, nonce, host, url_request_path, hmac)
        %W[
          HMAC-SHA256
          keyid=#{config.hmac_key_id},
          ts=#{ts},
          nonce=#{nonce},
          bodyHash=#{hmac},
          signature=#{signature}
        ].join(' ')
      end

      # Signature definition from RDP_REST_V3_DecisioningGuide_March22.pdf, page 20
      def build_signature(ts, nonce, host, path, body_hash)
        message = [
          ts,
          nonce,
          host,
          path,
          body_hash,
        ].join("\n")
        OpenSSL::HMAC.base64digest('SHA256', config.hmac_secret_key, message)
      end

      def build_request_body
        raise NotImplementedError, "#{__method__} should be defined by a subclass"
      end

      def build_request_url
        URI.join(
          base_url,
          url_request_path,
        ).to_s
      end

      def mode
        config.request_mode
      end

      def url_request_path
        "/restws/identity/v2/#{account_number}/#{workflow_name}/conversation"
      end

      def uuid
        uuid = applicant.fetch(:uuid, SecureRandom.uuid)
        uuid_prefix = applicant[:uuid_prefix]

        if uuid_prefix.present?
          "#{uuid_prefix}:#{uuid}"
        else
          uuid
        end
      end

      def timeout
        raise NotImplementedError
      end

      def metric_name
        raise NotImplementedError
      end
    end
  end
end
