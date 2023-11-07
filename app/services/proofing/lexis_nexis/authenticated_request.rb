module Proofing
  module LexisNexis
    class AuthenticatedRequest < Request
      def send_request
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

      def build_request_headers
        headers = super
        headers['Authorization'] = hmac_authorization if hmac_auth_enabled?
        headers
      end

      def hmac_auth_enabled?
        IdentityConfig.store.lexisnexis_hmac_auth_enabled
      end

      def hmac_authorization
        Proofing::LexisNexis::RequestSigner.new(
          config:,
          message_body: body,
          path: url_request_path,
        ).hmac_authorization
      end
    end
  end
end
