module DocAuth
  module LexisNexis
    class Request
      def path
        "/restws/identity/v2/#{account_id}/#{workflow}/conversation"
      end

      def body
        raise NotImplementedError
      end

      def handle_http_response(_response)
        raise NotImplementedError
      end

      def method
        :get
      end

      def url
        URI.join(Figaro.env.lexisnexis_base_url, path)
      end

      def headers
        {
          Authorization: "Basic #{encoded_credentials}",
          Accepts: 'application/json',
          'Content-Type': 'application/json',
        }
      end

      def fetch
        http_response = send_http_request

        handle_http_response(http_response)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        handle_connection_error(e)
      end

      protected

      def settings
        {
          Type: 'Initiate',
          Settings: {
            AccountNumber: account_id,
            Workflow: workflow,
            Mode: request_mode,
            Locale: I18n.locale,
            Venue: 'online',
            Reference: uuid
          },
        }
      end

      def account_id
        Figaro.env.lexisnexis_account_id
      end

      def username
        Figaro.env.lexisnexis_username
      end

      def password
        Figaro.env.lexisnexis_password
      end

      def workflow
        raise NotImplementedError
      end

      def request_mode
        Figaro.env.lexisnexis_request_mode
      end

      #AM: Need to account for the uuid-prefix when folding in the lexisnexis gem.
      def uuid
        SecureRandom.uuid
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

      def send_http_get_request
        faraday_connection.get
      end

      def send_http_post_request
        faraday_connection.post do |req|
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
          retry_block: lambda do |_env, _options, retries, exc|
            NewRelic::Agent.notice_error(exc, custom_params: { retry: retries })
          end,
        }

        Faraday.new(request: faraday_request_params, url: url.to_s, headers: headers) do |conn|
          conn.request :retry, retry_options
          conn.adapter :net_http
        end
      end

      def faraday_request_params
        timeout = Figaro.env.lexisnexis_timeout&.to_i || 45
        { open_timeout: timeout, timeout: timeout }
      end

      def handle_connection_error(exception)
        NewRelic::Agent.notice_error(exception)
        DocAuth::Response.new(
          success: false,
          errors: [I18n.t('errors.doc_auth.lexisnexis_network_error')],
          exception: exception,
        )
      end

      def encoded_credentials
        Base64.strict_encode64("#{username}:#{password}")
      end
    end
  end
end
